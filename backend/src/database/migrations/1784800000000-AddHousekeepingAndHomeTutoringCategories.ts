import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddHousekeepingAndHomeTutoringCategories1784800000000
  implements MigrationInterface
{
  name = 'AddHousekeepingAndHomeTutoringCategories1784800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "service_category_enum" ADD VALUE 'housekeeping'`,
    );
    await queryRunner.query(
      `ALTER TYPE "service_category_enum" ADD VALUE 'home_tutoring'`,
    );
  }

  public async down(): Promise<void> {
    // Postgres does not support removing enum values; rolling back would
    // require recreating the type and remapping every dependent column.
    throw new Error(
      'Cannot revert: Postgres does not support dropping enum values',
    );
  }
}
