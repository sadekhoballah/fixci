import { MigrationInterface, QueryRunner } from 'typeorm';

// Closes the mutual-reference loop between missions and mission_applications
// (the column itself was added in CreateMissions, before this table existed).
export class AddSelectedApplicationFkToMissions1787300000000 implements MigrationInterface {
  name = 'AddSelectedApplicationFkToMissions1787300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "missions"
      ADD CONSTRAINT "FK_missions_selected_application"
      FOREIGN KEY ("selected_application_id") REFERENCES "mission_applications"("id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "missions" DROP CONSTRAINT "FK_missions_selected_application"`,
    );
  }
}
