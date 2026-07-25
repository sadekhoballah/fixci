import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddAwaitingClientConfirmationStatus1784900000000 implements MigrationInterface {
  name = 'AddAwaitingClientConfirmationStatus1784900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "service_request_status_enum" ADD VALUE 'awaiting_client_confirmation'`,
    );
  }

  // Postgres does not support removing enum values; rolling back would
  // require recreating the type and remapping every dependent column.
  public down(): Promise<void> {
    throw new Error(
      'Cannot revert: Postgres does not support dropping enum values',
    );
  }
}
