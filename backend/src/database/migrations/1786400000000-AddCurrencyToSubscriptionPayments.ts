import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCurrencyToSubscriptionPayments1786400000000 implements MigrationInterface {
  name = 'AddCurrencyToSubscriptionPayments1786400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "subscription_payments"
      ADD COLUMN "currency" varchar(3) NOT NULL DEFAULT 'CFA'
    `);
    await queryRunner.query(`
      ALTER TABLE "subscription_payments"
      RENAME COLUMN "amount_cfa" TO "amount"
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "subscription_payments"
      RENAME COLUMN "amount" TO "amount_cfa"
    `);
    await queryRunner.query(`
      ALTER TABLE "subscription_payments"
      DROP COLUMN "currency"
    `);
  }
}
