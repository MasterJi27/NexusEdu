import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
    globals: false,
    setupFiles: ['./test/setup.ts'],
    coverage: { provider: 'v8', thresholds: { lines: 70, branches: 60 } },
  },
});
