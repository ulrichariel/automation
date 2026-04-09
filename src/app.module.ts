import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthController } from './health.controller';

@Module({
  imports: [],
  // The health controller is separated so deployment validation can target dedicated
  // liveness/readiness endpoints instead of the main application route.
  controllers: [AppController, HealthController],
  providers: [AppService],
})
export class AppModule {}
