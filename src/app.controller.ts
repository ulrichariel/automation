import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello() {
    // Keep the root endpoint intentionally small. The exercise evaluates the delivery
    // workflow more than application complexity.
    return this.appService.getHello();
  }
}
