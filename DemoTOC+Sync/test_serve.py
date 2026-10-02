"""Tests for serve.py: static files and POST /export-pdf.

Run from DemoTOC+Sync/:  python3 -m unittest test_serve
"""

import base64
import http.server
import json
import threading
import unittest
import urllib.error
import urllib.request

import serve


# A 1x1 PNG.
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


class PickyImageHost(http.server.BaseHTTPRequestHandler):
    """Serves /dot.png, but like some real hosts refuses Python's default
    User-Agent with 406."""

    def do_GET(self):
        if self.path == "/page.jpg":
            # A URL that looks like an image but returns a web page.
            body = b"<html><body>Not an image</body></html>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.headers.get("User-Agent", "").startswith("Python-urllib"):
            self.send_response(406)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(PNG)))
        self.end_headers()
        self.wfile.write(PNG)

    def log_message(self, *args):
        pass


class ExportPdfTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = serve.make_server(0)  # port 0: any free port
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.images = http.server.ThreadingHTTPServer(("", 0), PickyImageHost)
        threading.Thread(target=cls.images.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.images.shutdown()

    def post(self, payload):
        request = urllib.request.Request(
            f"http://localhost:{self.port}/export-pdf",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        return urllib.request.urlopen(request, timeout=90)

    def test_valid_latex_returns_a_pdf(self):
        tex = "\\documentclass{article}\n\\begin{document}\nHello $x^2$.\n\\end{document}\n"
        with self.post({"name": "hello.pdf", "tex": tex, "images": []}) as response:
            self.assertEqual(response.headers["Content-Type"], "application/pdf")
            self.assertTrue(response.read().startswith(b"%PDF"))

    def test_broken_latex_returns_422_with_the_log(self):
        tex = "\\documentclass{article}\n\\begin{document}\n\\undefinedcommand\n\\end{document}\n"
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.post({"name": "bad.pdf", "tex": tex, "images": []})
        self.assertEqual(caught.exception.code, 422)
        body = json.loads(caught.exception.read())
        self.assertIn("Undefined control sequence", body["error"])

    def test_an_image_that_cannot_be_downloaded_is_reported_not_fatal(self):
        tex = "\\documentclass{article}\n\\begin{document}\nNo image used.\n\\end{document}\n"
        images = [["http://localhost:1/missing.png", "image/missing-000000.png"]]
        with self.post({"name": "x.pdf", "tex": tex, "images": images}) as response:
            self.assertTrue(response.read().startswith(b"%PDF"))
            self.assertIn("missing", response.headers.get("X-Image-Errors", ""))

    def test_image_paths_cannot_escape_the_build_folder(self):
        tex = "\\documentclass{article}\n\\begin{document}\nx\n\\end{document}\n"
        images = [["http://localhost:1/a.png", "../../evil.png"]]
        with self.post({"name": "x.pdf", "tex": tex, "images": images}) as response:
            self.assertTrue(response.read().startswith(b"%PDF"))
            self.assertIn("evil", response.headers.get("X-Image-Errors", ""))

    def test_images_are_fetched_from_hosts_that_reject_python_user_agents(self):
        url = f"http://localhost:{self.images.server_address[1]}/dot.png"
        tex = (
            "\\documentclass{article}\n\\usepackage{graphicx}\n\\begin{document}\n"
            "\\includegraphics[width=1cm]{image/dot-abc123.png}\n\\end{document}\n"
        )
        with self.post({"name": "x.pdf", "tex": tex, "images": [[url, "image/dot-abc123.png"]]}) as response:
            self.assertTrue(response.read().startswith(b"%PDF"))
            self.assertIsNone(response.headers.get("X-Image-Errors"))

    def test_a_used_image_that_cannot_be_downloaded_becomes_a_placeholder(self):
        tex = (
            "\\documentclass{article}\n\\usepackage{graphicx}\n\\begin{document}\n"
            "\\begin{center}\n\\includegraphics[width=0.5\\textwidth]{image/gone-000000.jpg}\n\\end{center}\n"
            "\\end{document}\n"
        )
        images = [["http://localhost:1/gone.jpg", "image/gone-000000.jpg"]]
        with self.post({"name": "x.pdf", "tex": tex, "images": images}) as response:
            self.assertTrue(response.read().startswith(b"%PDF"))
            self.assertIn("gone", response.headers.get("X-Image-Errors", ""))

    def test_a_url_that_returns_a_web_page_becomes_a_placeholder(self):
        url = f"http://localhost:{self.images.server_address[1]}/page.jpg"
        tex = (
            "\\documentclass{article}\n\\usepackage{graphicx}\n\\begin{document}\n"
            "\\includegraphics[width=1cm]{image/page-abc123.jpg}\n\\end{document}\n"
        )
        with self.post({"name": "x.pdf", "tex": tex, "images": [[url, "image/page-abc123.jpg"]]}) as response:
            self.assertTrue(response.read().startswith(b"%PDF"))
            self.assertIn("text/html", response.headers.get("X-Image-Errors", ""))

    def test_static_files_are_still_served(self):
        with urllib.request.urlopen(f"http://localhost:{self.port}/index.html", timeout=10) as response:
            self.assertIn(b"<html", response.read().lower())
            self.assertEqual(response.headers["Cache-Control"], "no-store")


if __name__ == "__main__":
    unittest.main()
