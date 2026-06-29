#  backend — runnable base (auth)

This is a real, runnable Node.js/Express/MySQL backend with Firebase
phone-auth wired up end to end. Get this running first, then we layer
on assessments/payments/etc. on top of this same base.

## 1. Install

```bash
cd damage-assessor-backend
npm install
```

## 2. Set up the database

If you don't already have a `damage_assessor` MySQL database with a `users`
table, create the database first:

```sql
CREATE DATABASE damage_assessor;
```

Then run the migrations **in order**:

```bash
mysql -u root -p damage_assessor < migrations/2026_06_19_create_users_table.sql
mysql -u root -p damage_assessor < migrations/2026_06_20_add_firebase_auth_columns.sql
```

**If you already have an existing `users` table** from prior
 work: skip the first migration, and check the second one
doesn't conflict with columns you already have (e.g. if `phone`
already exists, remove that line from the migration before running it).

## 3. Get a Firebase service account key

Firebase Console → Project Settings → Service Accounts → Generate new
private key → downloads a JSON file.

Open that JSON file, copy its entire contents, and paste it as a single
line into your `.env` file (see next step).

## 4. Configure environment variables

```bash
cp .env.example .env
```

Then fill in `.env`:
- `DB_USER`, `DB_PASSWORD`, `DB_NAME` — your real MySQL credentials.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — the full JSON from step 3, as one line.
- `JWT_SECRET` — any long random string, e.g. generate one with:
  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
  ```

## 5. Run it

```bash
npm run dev
```

You should see:
```
✅ MySQL connection OK
🚀  backend running on http://localhost:4000
```

If you see a MySQL connection error instead, double-check `.env` — the
server fails fast on a bad DB connection rather than starting silently broken.

## 6. Test the health check

```bash
curl http://localhost:4000/health
# {"status":"ok"}
```

## 7. Test the auth endpoint

You need a real Firebase ID token to test this properly — easiest way
is to run the Flutter app's login flow against this backend (point
`Env.apiBaseUrl` in the Flutter scaffold at `http://localhost:4000`,
or your machine's LAN IP if testing on a physical phone).

Once you have a token, you can also test directly with curl:

```bash
curl -X POST http://localhost:4000/auth/firebase \
  -H "Content-Type: application/json" \
  -d '{"firebase_id_token": "PASTE_REAL_TOKEN_HERE"}'
```

Expected response:
```json
{
  "token": "eyJ...",
  "user": {
    "id": "1",
    "phone": "+213...",
    "free_report_used": false,
    "subscription_status": "none",
    ...
  }
}
```

## 8. Test the protected /me route

```bash
curl http://localhost:4000/auth/me \
  -H "Authorization: Bearer PASTE_BACKEND_TOKEN_FROM_STEP_7"
```

## What's NOT included yet (by design — next steps)

- `/assessments` routes (capture, analyze, results)
- `/payments` routes (Chargily checkout, webhook)
- `/reports` route (PDF generation)

These get added as their own route files + controllers, mounted in
`app.js` the same way `authRoutes` is, reusing `requireAuth` middleware
for any route that needs a logged-in user.
