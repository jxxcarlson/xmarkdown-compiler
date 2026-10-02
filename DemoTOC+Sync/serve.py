"""Local server for the demo (started by run.sh).

- Serves assets/ with caching disabled. (Plain `python3 -m http.server` sends
  no Cache-Control header, so Firefox heuristically caches long-unmodified
  files like katex.js and serves stale copies on reload after they change.)
- POST /export-pdf: File > Export PDF. The body is JSON
  {"name": "doc.pdf", "tex": "...", "images": [[url, localPath], ...]}
  (from LaTeX.Export). The images are downloaded next to the .tex, pdflatex
  runs in a temporary folder, and the PDF comes back. On a LaTeX error the
  reply is 422 with {"error": <tail of the pdflatex log>}. Images that can't
  be fetched are skipped and listed in the X-Image-Errors header.

Usage: python3 serve.py [port]   (default 8200; keep clear of 8000-8010)
"""

import functools
import http.server
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
PDFLATEX_TIMEOUT = 60
# Some image hosts refuse Python's default User-Agent (HTTP 406/403).
FETCH_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh) XMarkdown-demo/1.0",
    "Accept": "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5",
}
LOG_TAIL_LINES = 40


def find_pdflatex():
    return shutil.which("pdflatex") or (
        "/Library/TeX/texbin/pdflatex" if os.path.exists("/Library/TeX/texbin/pdflatex") else None
    )


def fetch_image(url, local_path, build_dir):
    """Download url to build_dir/local_path. Returns an error string or None."""
    target = os.path.realpath(os.path.join(build_dir, local_path))
    if not target.startswith(os.path.realpath(build_dir) + os.sep):
        return f"{local_path}: path outside the build folder"
    try:
        request = urllib.request.Request(url, headers=FETCH_HEADERS)
        with urllib.request.urlopen(request, timeout=20) as response:
            data = response.read()
            content_type = response.headers.get_content_type()
    except Exception as e:  # any network or HTTP failure: skip this image
        return f"{local_path}: {e}"
    # A 200 that isn't an image (a login or error page) would be a fatal
    # "not a JPEG/PNG" error in pdflatex; treat it as a failed download.
    if not (content_type.startswith("image/") or content_type == "application/pdf"):
        return f"{local_path}: got {content_type}, not an image"
    # LaTeX.Export gives extensionless URLs an extensionless path, and
    # \includegraphics then searches .png, .jpg, ...: name the file by its type.
    if not os.path.splitext(target)[1]:
        ext = mimetypes.guess_extension(content_type) or ""
        target += ".jpg" if ext == ".jpe" else ext
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "wb") as f:
        f.write(data)
    return None


def build_pdf(name, tex, images):
    """Returns (pdf_bytes, None, image_errors) or (None, error_text, image_errors)."""
    pdflatex = find_pdflatex()
    if pdflatex is None:
        return None, "pdflatex not found (install TeX Live / MacTeX)", []
    stem = os.path.splitext(os.path.basename(name))[0] or "document"
    with tempfile.TemporaryDirectory() as build_dir:
        image_errors = []
        for url, path in images:
            error = fetch_image(url, path, build_dir)
            if error:
                image_errors.append(error)
                tex = replace_with_placeholder(tex, path)
        with open(os.path.join(build_dir, stem + ".tex"), "w", encoding="utf-8") as f:
            f.write(tex)
        try:
            result = subprocess.run(
                [pdflatex, "-interaction=nonstopmode", "-halt-on-error", stem + ".tex"],
                cwd=build_dir,
                capture_output=True,
                timeout=PDFLATEX_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            return None, f"pdflatex took longer than {PDFLATEX_TIMEOUT}s", image_errors
        pdf_path = os.path.join(build_dir, stem + ".pdf")
        if result.returncode != 0 or not os.path.exists(pdf_path):
            log = result.stdout.decode("utf-8", errors="replace").splitlines()
            return None, "\n".join(log[-LOG_TAIL_LINES:]), image_errors
        with open(pdf_path, "rb") as f:
            return f.read(), None, image_errors


def replace_with_placeholder(tex, local_path):
    """A missing image file is a fatal pdflatex error; put a framed note in
    its place so the rest of the document still comes out."""
    pattern = r"\\includegraphics(\[[^\]]*\])?\{" + re.escape(local_path) + r"\}"
    return re.sub(pattern, lambda _: r"\fbox{\texttt{image not available}}", tex)


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        if self.path != "/export-pdf":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            request = json.loads(self.rfile.read(length))
            name, tex, images = request["name"], request["tex"], request.get("images", [])
        except (ValueError, KeyError, TypeError) as e:
            self.reply_json(400, {"error": f"bad request: {e}"})
            return
        pdf, error, image_errors = build_pdf(name, tex, images)
        if pdf is None:
            self.reply_json(422, {"error": error, "imageErrors": image_errors})
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(pdf)))
        if image_errors:
            # Header values must be latin-1; keep them ASCII.
            self.send_header(
                "X-Image-Errors", "; ".join(image_errors).encode("ascii", "replace").decode()
            )
        self.end_headers()
        self.wfile.write(pdf)

    def reply_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def make_server(port):
    handler = functools.partial(Handler, directory=ASSETS)
    return http.server.ThreadingHTTPServer(("", port), handler)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8200
    make_server(port).serve_forever()
