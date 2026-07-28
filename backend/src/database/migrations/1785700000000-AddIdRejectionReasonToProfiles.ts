import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddIdRejectionReasonToProfiles1785700000000
  implements MigrationInterface
{
  name = 'AddIdRejectionReasonToProfiles1785700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" ADD COLUMN "id_rejection_reason" text`,
    );
    await queryRunner.query(
      `ALTER TABLE "client_profiles" ADD COLUMN "id_rejection_reason" text`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "client_profiles" DROP COLUMN "id_rejection_reason"`,
    );
    await queryRunner.query(
      `ALTER TABLE "craftsman_profiles" DROP COLUMN "id_rejection_reason"`,
    );
  }
}
