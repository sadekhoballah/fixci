import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSubscriptionPaymentUserIdIndex1784720500000 implements MigrationInterface {
  name = 'AddSubscriptionPaymentUserIdIndex1784720500000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE INDEX "idx_subscription_payments_user_id" ON "subscription_payments" ("user_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "idx_subscription_payments_user_id"`);
  }
}
