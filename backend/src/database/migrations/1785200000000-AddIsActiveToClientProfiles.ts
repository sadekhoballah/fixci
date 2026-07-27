import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddIsActiveToClientProfiles1785200000000 implements MigrationInterface {
  name = 'AddIsActiveToClientProfiles1785200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" ADD COLUMN "is_active" boolean NOT NULL DEFAULT true`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" DROP COLUMN "is_active"`,
    );
  }
}
