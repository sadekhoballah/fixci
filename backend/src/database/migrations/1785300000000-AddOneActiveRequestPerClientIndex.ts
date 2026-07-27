import { MigrationInterface, QueryRunner } from 'typeorm';

// Backstops MatchingService.createServiceRequest against a client submitting
// more than one active request at once (e.g. a fast double-tap on
// "Réessayer", or retrying because the app hadn't yet shown a still-pending
// request as assigned) — a partial unique index is the only way to close
// this atomically; a check-then-insert in application code has the exact
// same race a double-tap can hit.
export class AddOneActiveRequestPerClientIndex1785300000000 implements MigrationInterface {
  name = 'AddOneActiveRequestPerClientIndex1785300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE UNIQUE INDEX "service_requests_one_active_per_client"
       ON "service_requests" ("client_id")
       WHERE "status" IN ('pending', 'assigned', 'in_progress', 'awaiting_client_confirmation')`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "service_requests_one_active_per_client"`,
    );
  }
}
