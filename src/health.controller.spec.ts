import { HealthController } from './health.controller';

describe('HealthController', () => {
  const controller = new HealthController();

  afterEach(() => {
    delete process.env.APP_NAME;
    delete process.env.APP_ENV;
    delete process.env.RELEASE_VERSION;
    delete process.env.BUILD_ID;
    delete process.env.SOURCE_COMMIT;
  });

  it('should return environment-aware health information', () => {
    process.env.APP_NAME = 'demo-app';
    process.env.APP_ENV = 'qa';
    process.env.RELEASE_VERSION = '123';
    process.env.SOURCE_COMMIT = 'abc123';

    const result = controller.getHealth();

    expect(result.app).toBe('demo-app');
    expect(result.status).toBe('ok');
    expect(result.environment).toBe('qa');
    expect(result.version).toBe('123');
    expect(result.commit).toBe('abc123');
    expect(result.timestamp).toBeDefined();
  });

  it('should expose liveness status', () => {
    const result = controller.getLiveness();
    expect(result.status).toBe('live');
    expect(result.timestamp).toBeDefined();
  });

  it('should expose readiness status', () => {
    process.env.APP_ENV = 'prod';
    process.env.BUILD_ID = '999';

    const result = controller.getReadiness();
    expect(result.status).toBe('ready');
    expect(result.environment).toBe('prod');
    expect(result.version).toBe('999');
    expect(result.timestamp).toBeDefined();
  });
});
