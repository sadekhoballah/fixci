import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSubscriptionPayments1784649500039 implements MigrationInterface {
  name = 'AddSubscriptionPayments1784649500039';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "subscription_tier_enum" AS ENUM('free', 'bronze', 'silver', 'gold')`,
    );
    await queryRunner.query(
      `CREATE TYPE "payment_status_enum" AS ENUM('pending', 'success', 'failed')`,
    );

    await queryRunner.query(`
      ALTER TABLE "craftsman_profiles"
        ADD COLUMN "subscription_tier" "subscription_tier_enum" NOT NULL DEFAULT 'free',
        ADD COLUMN "subscription_expires_at" timestamptz
    `);

    await queryRunner.query(`
      CREATE TABLE "subscription_payments" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "tier" "subscription_tier_enum" NOT NULL,
        "amount_cfa" integer NOT NULL,
        "phone" varchar(20) NOT NULL,
        "reference" varchar(64) NOT NULL UNIQUE,
        "provider_transaction_id" varchar(64),
        "status" "payment_status_enum" NOT NULL DEFAULT 'pending',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "subscription_payments"`);
    await queryRunner.query(`
      ALTER TABLE "craftsman_profiles"
        DROP COLUMN "subscription_expires_at",
        DROP COLUMN "subscription_tier"
    `);
    await queryRunner.query(`DROP TYPE "payment_status_enum"`);
    await queryRunner.query(`DROP TYPE "subscription_tier_enum"`);
  }
}
