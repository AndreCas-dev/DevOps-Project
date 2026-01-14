import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    hmr: {
      clientPort: 5173,
      host: 'localhost'
    },
    proxy: {
      '/api': {
        target: 'http://app:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    },
    watch: {
      usePolling: true
    }
  },
  build: {
    outDir: 'dist'
  }
})
