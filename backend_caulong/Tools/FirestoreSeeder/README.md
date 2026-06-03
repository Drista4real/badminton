# Firestore Seeder

One-time seed script for QA booking and wallet/payment flows.

## Run

```powershell
dotnet run --project backend_caulong\Tools\FirestoreSeeder -- `
  --project-id badminton-d689a `
  --credentials C:\path\to\service-account.json
```

Or set environment variables:

```powershell
$env:FIREBASE_PROJECT_ID="badminton-d689a"
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
dotnet run --project backend_caulong\Tools\FirestoreSeeder
```

## Seeded Data

- `courts/court-01` to `courts/court-10`
- Dynamic `hourlyPrices` from the source price table:
  - T2-T6 05:00-09:00: fixed `55000`, account `70000`, guest `80000`
  - T2-T6 09:00-16:00: fixed `45000`, account `60000`, guest `70000`
  - T2-T6 16:00-22:00: fixed `90000`, account `100000`, guest `110000`
  - T2-CN 22:00-24:00: fixed `60000`, account `70000`, guest `70000`
  - T7-CN 05:00-16:00: fixed `90000`, account `100000`, guest `110000`
  - T7-CN 16:00-22:00: fixed `90000`, account `100000`, guest `110000`
- Same active status and standard surface type for every court
- Court `imageUrl` is seeded as `null`; the Flutter app uses its bundled fallback image asset.
- Firebase Auth test user:
  - Email: `qa.test@badminton.local`
  - Password: `Test@123456`
- Matching `users/{uid}` Firestore document:
  - `walletBalance`: `500000`
  - `points`: `15`
  - `loyaltyPoints`: `15`
