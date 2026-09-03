import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // El código siempre pide rutas relativas ("/api"); en dev este proxy las
    // manda al backend local, igual que Nginx lo hace en producción.
    proxy: {
      '/api': {
        target: 'http://localhost:5220',
        changeOrigin: true,
      },
      // ws: true porque SignalR sube la conexión a WebSocket.
      '/hubs': {
        target: 'http://localhost:5220',
        changeOrigin: true,
        ws: true,
      },
    },
  },
})
