# FixCi

On-demand marketplace connecting clients with home-service craftsmen
(plumbers, electricians, AC technicians, carpenters, mechanics, painters,
and more) — style automatic matching instead of manual browsing.
Launching in Abidjan, Côte d'Ivoire.

## Structure

- `backend/` — NestJS API (TypeORM + PostgreSQL/PostGIS, Redis, Socket.io)
- `mobile/` — Flutter app (Riverpod), mobile-first, desktop targets later
- `docker-compose.yml` — local Postgres+PostGIS and Redis for development

## Local development

```bash
# 1. Start infra
docker compose up -d

# 2. Backend
cd backend
cp .env.example .env   # already done if you cloned after initial scaffold
npm install
npm run start:dev

# 3. Mobile
cd mobile
flutter pub get
flutter run
```
