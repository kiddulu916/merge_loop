-- Phase 2: players + scores + RLS + leaderboard RPC.
--
-- Trust model: the public leaderboard is tied to ad revenue, so the client
-- NEVER writes a score directly. The submit-score Edge Function (service role)
-- replays the move log and is the ONLY writer to `scores`. There is therefore
-- deliberately NO client insert/update policy on `scores` — RLS denies any
-- client write by default. Scores are world-readable for leaderboards;
-- players rows are self-only.

create table if not exists players (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 20),
  avatar text,
  created_at timestamptz default now()
);

create table if not exists scores (
  id bigint generated always as identity primary key,
  player_id uuid not null references players(id) on delete cascade,
  utc_date date not null,
  difficulty text not null check (difficulty in ('easy','medium','hard','legendary')),
  score int not null check (score >= 0),
  highest_tier int not null,
  created_at timestamptz default now(),
  unique (player_id, utc_date, difficulty)   -- one best score per tier per day
);
create index if not exists idx_scores_board on scores (utc_date, difficulty, score desc);

alter table players enable row level security;
alter table scores  enable row level security;

-- players: a user reads/writes only their own row.
drop policy if exists player_self on players;
create policy player_self on players for all using (auth.uid() = id) with check (auth.uid() = id);

-- scores: world-readable (leaderboards), but NO client insert/update — only the
-- service role (Edge Function) writes. No insert/update policy = clients cannot
-- write (RLS denies by default).
drop policy if exists scores_read on scores;
create policy scores_read on scores for select using (true);

-- Leaderboard read RPC: top N for a (date,difficulty) plus the caller's own
-- rank flag. `security invoker` so auth.uid() resolves to the caller.
create or replace function leaderboard(p_date date, p_diff text, p_limit int default 100)
returns table(rank bigint, display_name text, score int, is_me boolean)
language sql stable security invoker as $$
  select rank() over (order by s.score desc) as rank,
         p.display_name, s.score, (s.player_id = auth.uid()) as is_me
  from scores s join players p on p.id = s.player_id
  where s.utc_date = p_date and s.difficulty = p_diff
  order by s.score desc limit p_limit;
$$;

grant execute on function leaderboard(date, text, int) to anon, authenticated;
