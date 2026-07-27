import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddFcmTokenToUsers1785400000000 implements MigrationInterface {
  name = 'AddFcmTokenToUsers1785400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "fcm_token" varchar(255)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "fcm_token"`);
  }
}
