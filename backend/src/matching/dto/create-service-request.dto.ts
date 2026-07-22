import { IsEnum, IsLatitude, IsLongitude } from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class CreateServiceRequestDto {
  @IsEnum(ServiceCategory)
  serviceCategory: ServiceCategory;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
