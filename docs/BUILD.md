# Building Merge Count

## Online features (leaderboards, friends)

The global + Friends leaderboards require Supabase credentials injected at
build time. Without them the app runs offline and the leaderboard entry
points are disabled (the main-menu Leaderboard button shows an
"internet connection" message).

1. Copy `env/supabase.example.json` to `env/supabase.json` and fill in your
   project URL + anon (publishable) key. `env/supabase.json` is git-ignored.
2. Build/run with the key file:

   ```bash
   flutter run --dart-define-from-file=env/supabase.json
   flutter build apk --release --dart-define-from-file=env/supabase.json
   ```

`env/supabase.example.json` is committed as a template; never commit
`env/supabase.json`.

## Backend

The database schema lives in `supabase/migrations/`. Deploy it with the
Supabase CLI (a local dev dependency):

```bash
npx supabase link --project-ref <your-ref>
npx supabase db push
```
