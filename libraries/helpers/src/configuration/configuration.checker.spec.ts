import { ConfigurationChecker } from './configuration.checker';
import type { DotenvParseOutput } from 'dotenv';

const validConfig: DotenvParseOutput = {
  REDIS_URL: 'redis://localhost:6379',
  DATABASE_URL: 'postgresql://localhost:5432/putduk',
  JWT_SECRET: 'test-only-secret',
  MAIN_URL: 'http://localhost:3000',
  FRONTEND_URL: 'http://localhost:4200',
  NEXT_PUBLIC_BACKEND_URL: 'http://localhost:3000',
  BACKEND_INTERNAL_URL: 'http://localhost:3000',
  STORAGE_PROVIDER: 'local',
};

const createChecker = (
  overrides: Record<string, string> = {}
): ConfigurationChecker => {
  const checker = new ConfigurationChecker();
  checker.cfg = { ...validConfig, ...overrides };
  return checker;
};

describe('ConfigurationChecker', () => {
  it('accepts a complete configuration with valid service URLs', () => {
    const checker = createChecker();

    checker.check();

    expect(checker.hasIssues()).toBe(false);
    expect(checker.getIssues()).toEqual([]);
  });

  it('reports missing required values and malformed URLs', () => {
    const checker = createChecker({
      JWT_SECRET: '',
      DATABASE_URL: 'not-a-url',
      FRONTEND_URL: 'http://localhost:4200/',
    });

    checker.check();

    expect(checker.getIssues()).toEqual([
      'DATABASE_URL is not a valid URL',
      'JWT_SECRET not set. ',
      'FRONTEND_URL should not end with /',
    ]);
    expect(checker.hasIssues()).toBe(true);
  });
});
