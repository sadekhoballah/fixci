import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPhoneVerifiedToUsers1784377480786 implements MigrationInterface {
  name = 'AddPhoneVerifiedToUsers1784377480786';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "phone_verified" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "phone_verified"`);
  }
}
