import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  server: {
    port: 5174,
    strictPort: true,
  },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        skipWaiting: true,
        clientsClaim: true,
      },
      includeAssets: ['favicon.png'],
      manifest: {
        name: 'Personaje RPG',
        short_name: 'Personaje',
        description: 'Tu progreso real convertido en un personaje de RPG',
        theme_color: '#1a1625',
        background_color: '#1a1625',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'favicon.png', sizes: '192x192', type: 'image/png' },
          { src: 'favicon.png', sizes: '512x512', type: 'image/png' },
        ],
      },
    }),
  ],
})
