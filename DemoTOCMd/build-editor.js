import esbuild from 'esbuild'

esbuild.build({
  entryPoints: ['assets/editor.js'],
  bundle: true,
  outfile: 'assets/editor-bundle.js',
  format: 'esm',
  platform: 'browser',
}).catch(() => process.exit(1))
