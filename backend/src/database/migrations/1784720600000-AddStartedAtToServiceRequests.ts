import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddStartedAtToServiceRequests1784720600000 implements MigrationInterface {
  name = 'AddStartedAtToServiceRequests1784720600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD COLUMN "started_at" timestamptz`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP COLUMN "started_at"`,
    );
  }
}
