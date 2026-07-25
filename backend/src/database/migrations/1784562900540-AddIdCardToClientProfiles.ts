import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddIdCardToClientProfiles1784562900540 implements MigrationInterface {
  name = 'AddIdCardToClientProfiles1784562900540';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" ADD COLUMN "id_card_storage_key" varchar(255)`,
    );
    await queryRunner.query(
      `ALTER TABLE "client_profiles" ADD COLUMN "id_verified" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" DROP COLUMN "id_verified"`,
    );
    await queryRunner.query(
      `ALTER TABLE "client_profiles" DROP COLUMN "id_card_storage_key"`,
    );
  }
}
