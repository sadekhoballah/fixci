import { Controller, Get } from '@nestjs/common';
import { DistrictsService } from './districts.service';

// Deliberately unguarded — the registration screen needs this list before
// the caller has any account (or even a verified phone) at all.
@Controller('districts')
export class DistrictsController {
  constructor(private readonly districtsService: DistrictsService) {}

  @Get()
  async list() {
    const districts = await this.districtsService.listPublic();
    return {
      items: districts.map((d) => ({
        id: d.id,
        name: d.name,
        isArtisanRegistrationActive: d.isArtisanRegistrationActive,
        isClientOrderingActive: d.isClientOrderingActive,
      })),
    };
  }
}
