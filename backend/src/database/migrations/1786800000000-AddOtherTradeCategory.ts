import { MigrationInterface, QueryRunner } from 'typeorm';

// New craftsman category for a trade that doesn't fit any fixed category —
// see database/enums/service-category.enum.ts. Never shown as a
// client-facing tile, never queried by the matching engine: its only entry
// point is the Missions/Freelance board (see CreateMissions migration).
export class AddOtherTradeCategory1786800000000 implements MigrationInterface {
  name = 'AddOtherTradeCategory1786800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "service_category_enum" ADD VALUE 'other_trade'`,
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
