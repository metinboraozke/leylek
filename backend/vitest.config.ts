import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
    // Testler hiçbir zaman gerçek ağa çıkmaz; dış servisler sahte.
    // Gerçek çağrı yalnızca `npm run live` betiğinde.
  },
});
