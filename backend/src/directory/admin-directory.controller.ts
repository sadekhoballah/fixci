import {
  BadRequestException,
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { DirectoryService } from './directory.service';

@Controller('admin/directory')
@UseGuards(AdminJwtGuard)
export class AdminDirectoryController {
  constructor(private readonly directoryService: DirectoryService) {}

  @Get('clients')
  async clients(@Query('search') search?: string) {
    return { items: await this.directoryService.listClients(search) };
  }

  @Get('craftsmen')
  async craftsmen(
    @Query('search') search?: string,
    @Query('category') category?: string,
  ) {
    if (category && !Object.values(ServiceCategory).includes(category as ServiceCategory)) {
      throw new BadRequestException('Invalid category');
    }
    return {
      items: await this.directoryService.listCraftsmen(
        search,
        category as ServiceCategory | undefined,
      ),
    };
  }
}
