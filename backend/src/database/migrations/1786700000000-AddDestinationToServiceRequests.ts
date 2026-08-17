import { MigrationInterface, QueryRunner } from 'typeorm';

// Purely informational free text, not a PostGIS point — unlike
// client_location, destination is never used for matching/radius, only
// shown to a taxi/camion craftsman before they accept (see
// CreateServiceRequestDto.destinationAddress). Nullable: every other
// category never sets it.
export class AddDestinationToServiceRequests1786700000000 implements MigrationInterface {
  name = 'AddDestinationToServiceRequests1786700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD COLUMN "destination_address" text`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" ADD COLUMN "load_details" text`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP COLUMN "load_details"`,
    );
    await queryRunner.query(
      `ALTER TABLE "service_requests" DROP COLUMN "destination_address"`,
    );
  }
}
