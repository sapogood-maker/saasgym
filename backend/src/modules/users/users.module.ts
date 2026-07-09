import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../../storage/storage.module';

@Module({
  imports: [AuditModule, StorageModule],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
