import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { copyFileSync } from 'fs';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'copy-web-config',
      closeBundle() {
        // Copy web.config to dist folder for Azure deployment
        const src = resolve(__dirname, 'dev/web.config');
        const dest = resolve(__dirname, 'dev/dist/web.config');
        try {
          copyFileSync(src, dest);
          console.log('web.config copied to dist');
        } catch (err) {
          console.warn('Failed to copy web.config:', err);
        }
      },
    },
  ],
  root: 'dev',
  server: {
    port: 3000,
  },
});
