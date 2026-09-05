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
        // 127.0.0.1 y no localhost: en Windows, localhost prueba primero IPv6 y
        // recién después cae a IPv4 — ~200 ms perdidos en CADA petición.
        target: 'http://127.0.0.1:5220',
        changeOrigin: true,
      },
      // ws: true porque SignalR sube la conexión a WebSocket.
      '/hubs': {
        // 127.0.0.1 y no localhost: en Windows, localhost prueba primero IPv6 y
        // recién después cae a IPv4 — ~200 ms perdidos en CADA petición.
        target: 'http://127.0.0.1:5220',
        changeOrigin: true,
        ws: true,
      },
    },
  },
})
