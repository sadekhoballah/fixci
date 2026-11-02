import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddGardenerCategory1791200000000 implements MigrationInterface {
  name = 'AddGardenerCategory1791200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "service_category_enum" ADD VALUE IF NOT EXISTS 'gardener'`,
    );
  }

  // Postgres does not support removing enum values; rolling back would
  // require recreating the type and remapping every dependent column.
  public down(): Promise<void> {
    throw new Error(
      'Cannot revert: Postgres does not support dropping enum values',
    );
  }
}
