import { MigrationInterface, QueryRunner } from 'typeorm';

// 2026-11 African wave. Launched artisan-side first, like Lebanon: craftsmen
// can register and go online, clients can register but only join the
// waitlist (is_client_ordering_active = false) until the founder opens each
// city from the admin panel once it has enough verified craftsmen — so a
// client never lands on an empty radar. Cities, not neighbourhoods: the
// admin panel can split a city later as it grows.
const AFRICAN_CITIES: Record<string, string[]> = {
  SN: ['Dakar', 'Thiès', 'Touba', 'Saint-Louis'],
  CM: ['Douala', 'Yaoundé', 'Bafoussam', 'Garoua'],
  BJ: ['Cotonou', 'Abomey-Calavi', 'Porto-Novo', 'Parakou'],
  TG: ['Lomé', 'Kara', 'Sokodé'],
  GH: ['Accra', 'Kumasi', 'Tema', 'Takoradi'],
  NG: ['Lagos', 'Abuja', 'Port Harcourt', 'Ibadan', 'Kano'],
  CG: ['Brazzaville', 'Pointe-Noire'],
  CD: ['Kinshasa', 'Lubumbashi', 'Goma'],
  BF: ['Ouagadougou', 'Bobo-Dioulasso'],
  ML: ['Bamako'],
  GN: ['Conakry'],
};

export class AddAfricanCountries1791300000000 implements MigrationInterface {
  name = 'AddAfricanCountries1791300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    for (const [countryCode, cities] of Object.entries(AFRICAN_CITIES)) {
      for (const name of cities) {
        await queryRunner.query(
          `INSERT INTO "districts"
             ("name", "country_code", "is_artisan_registration_active", "is_client_ordering_active")
           VALUES ($1, $2, true, false)
           ON CONFLICT ("name") DO NOTHING`,
          [name, countryCode],
        );
      }
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Leaves any city someone already registered in (users.district_id is a
    // RESTRICT foreign key).
    await queryRunner.query(
      `DELETE FROM "districts" d
       WHERE d."country_code" = ANY($1)
         AND NOT EXISTS (SELECT 1 FROM "users" u WHERE u."district_id" = d."id")
         AND NOT EXISTS (SELECT 1 FROM "broadcast_notifications" b WHERE b."target_district_id" = d."id")`,
      [Object.keys(AFRICAN_CITIES)],
    );
  }
}
