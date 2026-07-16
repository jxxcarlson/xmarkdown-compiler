import { defineConfig } from 'vite'
import { resolve } from 'path'
import { fileURLToPath } from 'url'
import { dirname } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

export default defineConfig({
  root: './assets',
  server: {
    port: 8200,
    middlewareMode: false,
    fs: {
      allow: ['.', resolve(__dirname, 'node_modules')]
    }
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true
  }
})
