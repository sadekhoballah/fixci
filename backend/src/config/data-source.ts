import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { DataSource, DataSourceOptions } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ServiceRequest } from '../database/entities/service-request.entity';
import { Rating } from '../database/entities/rating.entity';

dotenv.config();

// Shared by both the running app and the TypeORM CLI. The app never touches
// migration files at runtime (migrations run only via `npm run migration:run`),
// so `appDataSourceOptions` omits the `migrations` glob — including it here
// caused an ESM/CJS race when ts-node's watch mode tried to require() the
// .ts migration files during ordinary app boot.
const baseOptions = {
  type: 'postgres' as const,
  host: process.env.DATABASE_HOST ?? 'localhost',
  port: Number(process.env.DATABASE_PORT ?? 5432),
  username: process.env.DATABASE_USER ?? 'fixci',
  password: process.env.DATABASE_PASSWORD ?? 'fixci',
  database: process.env.DATABASE_NAME ?? 'fixci',
  entities: [User, ClientProfile, CraftsmanProfile, ServiceRequest, Rating],
  synchronize: false,
};

export const appDataSourceOptions: DataSourceOptions = baseOptions;

export const dataSourceOptions: DataSourceOptions = {
  ...baseOptions,
  migrations: ['src/database/migrations/*.ts'],
};

export default new DataSource(dataSourceOptions);
