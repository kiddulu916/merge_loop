-- Phase 3: friends graph + friend codes + contacts matching + friends board.
--
-- Privacy model: contacts matching NEVER receives raw phone/email. The client
-- normalizes + SHA256-hashes on device; only hashes are stored (for opted-in
-- players) and only hashes are sent to match-contacts. Friend codes are the
-- primary, permission-free path; contacts are a bonus that requires the OTHER
-- player to have explicitly opted in.
--
-- Trust/RLS model (mirrors Phase 2): friendship edges are self-only readable
-- (auth.uid() in (a,b)); edge creation + contact matching go through
-- SECURITY DEFINER RPCs / the service-role Edge Function so RLS stays strict and
-- clients can't forge edges or enumerate the membership table.

-- ---------------------------------------------------------------------------
-- Friend code: a short unique token on the player's row used to add friends.
-- ---------------------------------------------------------------------------
alter table players add column if not exists friend_code text unique;

-- ---------------------------------------------------------------------------
-- friendships: one canonical row per pair (a < b) to avoid duplicate edges.
-- Query both directions; the (a,b) PK makes redeem idempotent.
-- ---------------------------------------------------------------------------
create table if not exists friendships (
  a uuid not null references players(id) on delete cascade,
  b uuid not null references players(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (a, b),
  check (a < b)
);
alter table friendships enable row level security;

-- Self-only read: a caller can only see edges they are part of.
drop policy if exists friendship_self on friendships;
create policy friendship_self on friendships for select using (auth.uid() in (a, b));
-- No client insert/update/delete policy beyond what's below: edge creation goes
-- through redeem_code (security definer). Allow a member to delete their own
-- edge (remove-a-friend, recommended in the spec open items).
drop policy if exists friendship_delete_self on friendships;
create policy friendship_delete_self on friendships for delete using (auth.uid() in (a, b));

-- ---------------------------------------------------------------------------
-- contact_hashes: opted-in players store SHA256 hashes of THEIR OWN normalized
-- phone/email so other players' contact hashes can match them. Self-only RLS;
-- matching is done server-side (service role) by match-contacts, which never
-- exposes the table to clients. Revoking opt-in = delete these rows.
-- ---------------------------------------------------------------------------
create table if not exists contact_hashes (
  player_id uuid not null references players(id) on delete cascade,
  hash text not null,
  created_at timestamptz default now(),
  primary key (player_id, hash)
);
create index if not exists idx_contact_hashes_hash on contact_hashes (hash);
alter table contact_hashes enable row level security;

-- Self-only: a player manages only their own hashes (insert on opt-in, delete on
-- revoke, select to show opt-in status). The service role bypasses RLS for the
-- cross-player match in match-contacts.
drop policy if exists contact_hashes_self on contact_hashes;
create policy contact_hashes_self on contact_hashes
  for all using (auth.uid() = player_id) with check (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- redeem_code(p_code): validate a friend code and create the mutual edge.
-- SECURITY DEFINER so it can insert into friendships (which has no client insert
-- policy) while still keying off the authenticated caller. Rejects self-add;
-- idempotent via the canonical (a<b) PK.
-- ---------------------------------------------------------------------------
create or replace function redeem_code(p_code text)
returns json
language plpgsql security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_target uuid;
  v_a uuid;
  v_b uuid;
begin
  if v_me is null then
    return json_build_object('ok', false, 'reason', 'unauthenticated');
  end if;

  select id into v_target from players where friend_code = p_code;
  if v_target is null then
    return json_build_object('ok', false, 'reason', 'invalid_code');
  end if;
  if v_target = v_me then
    return json_build_object('ok', false, 'reason', 'self');
  end if;

  -- Canonical ordering: a < b.
  if v_me < v_target then
    v_a := v_me; v_b := v_target;
  else
    v_a := v_target; v_b := v_me;
  end if;

  insert into friendships (a, b) values (v_a, v_b)
    on conflict (a, b) do nothing;

  return json_build_object('ok', true, 'friend_id', v_target);
end;
$$;

grant execute on function redeem_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- ensure_friend_code(): generate (collision-retry) a friend code for the caller
-- if they don't have one yet, and return it. Lets the client lazily assign a
-- code without colliding. SECURITY DEFINER to read other rows for uniqueness.
-- ---------------------------------------------------------------------------
create or replace function ensure_friend_code()
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_existing text;
  v_code text;
  v_alphabet text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; -- base32 (Crockford-ish, no 0/1/8/9)
  i int;
  attempt int := 0;
begin
  if v_me is null then
    raise exception 'unauthenticated';
  end if;

  select friend_code into v_existing from players where id = v_me;
  if v_existing is not null then
    return v_existing;
  end if;

  loop
    attempt := attempt + 1;
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    begin
      update players set friend_code = v_code where id = v_me;
      return v_code;
    exception when unique_violation then
      if attempt > 10 then
        raise exception 'could not allocate friend code';
      end if;
      -- retry with a fresh code
    end;
  end loop;
end;
$$;

grant execute on function ensure_friend_code() to authenticated;

-- ---------------------------------------------------------------------------
-- friends_leaderboard(p_date, p_diff): Phase 2's daily board filtered to the
-- caller's friend set + self, per tier. security invoker so auth.uid() is the
-- caller (friendships RLS already restricts visible edges, but we filter
-- explicitly so the result is the friend set regardless).
-- ---------------------------------------------------------------------------
create or replace function friends_leaderboard(p_date date, p_diff text)
returns table(rank bigint, display_name text, score int, is_me boolean)
language sql stable security invoker as $$
  with friends as (
    select case when a = auth.uid() then b else a end as fid
    from friendships where auth.uid() in (a, b)
    union
    select auth.uid()
  )
  select rank() over (order by s.score desc) as rank,
         p.display_name, s.score, (s.player_id = auth.uid()) as is_me
  from scores s join players p on p.id = s.player_id
  where s.utc_date = p_date and s.difficulty = p_diff
    and s.player_id in (select fid from friends)
  order by s.score desc;
$$;

grant execute on function friends_leaderboard(date, text) to authenticated;
