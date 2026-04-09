import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    // Return environment and release metadata so post-deployment checks can confirm
    // both where the app is running and which build is currently active.
    return {
      app: process.env.APP_NAME ?? 'nest-hello-release-demo',
      status: 'ok',
      environment: process.env.APP_ENV ?? 'local',
      version: process.env.RELEASE_VERSION ?? process.env.BUILD_ID ?? 'local',
      commit: process.env.SOURCE_COMMIT ?? 'local',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('live')
  getLiveness() {
    // Liveness is intentionally simple: it shows the process is running and able to respond.
    return {
      status: 'live',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('ready')
  getReadiness() {
    // Readiness is used by the deployment smoke test after promotion into each environment.
    return {
      status: 'ready',
      environment: process.env.APP_ENV ?? 'local',
      version: process.env.RELEASE_VERSION ?? process.env.BUILD_ID ?? 'local',
      timestamp: new Date().toISOString(),
    };
  }
}
