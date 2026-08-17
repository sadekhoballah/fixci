import {
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class CreateServiceRequestDto {
  @IsEnum(ServiceCategory)
  serviceCategory: ServiceCategory;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  // Taxi/camion only — the craftsman needs this before deciding whether to
  // accept, unlike every other category where the client's own location is
  // the only thing that matters (the artisan comes to them).
  @ValidateIf(
    (dto: CreateServiceRequestDto) =>
      dto.serviceCategory === ServiceCategory.TAXI ||
      dto.serviceCategory === ServiceCategory.CAMION,
  )
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  destinationAddress?: string;

  // Optional for both taxi and camion — most relevant for camion (cargo
  // size/access constraints) but harmless to allow for taxi too.
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  loadDetails?: string;
}
