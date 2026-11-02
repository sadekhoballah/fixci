import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateServiceRequestContacts1791100000000 implements MigrationInterface {
  name = 'CreateServiceRequestContacts1791100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "service_request_contacts" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "service_request_id" uuid NOT NULL,
        "client_id" uuid NOT NULL,
        "craftsman_id" uuid NOT NULL,
        "channel" varchar(16) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_request_contacts" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_service_request_contacts_request_craftsman_channel"
          UNIQUE ("service_request_id", "craftsman_id", "channel"),
        CONSTRAINT "CHK_service_request_contacts_channel"
          CHECK ("channel" IN ('whatsapp', 'call')),
        CONSTRAINT "FK_service_request_contacts_request" FOREIGN KEY ("service_request_id")
          REFERENCES "service_requests"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_service_request_contacts_client" FOREIGN KEY ("client_id")
          REFERENCES "users"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_service_request_contacts_craftsman" FOREIGN KEY ("craftsman_id")
          REFERENCES "users"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_service_request_contacts_craftsman_id" ON "service_request_contacts" ("craftsman_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "service_request_contacts"`);
  }
}
