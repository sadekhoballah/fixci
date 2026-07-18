import { IsEnum, IsLatitude, IsLongitude, IsUUID } from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class CreateServiceRequestDto {
  @IsUUID()
  clientId: string;

  @IsEnum(ServiceCategory)
  serviceCategory: ServiceCategory;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}
