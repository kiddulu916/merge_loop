-- Phase 3 security hotfix: stop the anon (unauthenticated) role from executing
-- our SECURITY DEFINER RPCs.
--
-- Root cause: Postgres grants EXECUTE to PUBLIC by default on CREATE FUNCTION.
-- Migration 0002 added `grant execute ... to authenticated` but never revoked the
-- implicit PUBLIC grant, so redeem_code() and ensure_friend_code() remained
-- callable by `anon` via /rest/v1/rpc/* (flagged by the Supabase security
-- advisor: "Public Can Execute SECURITY DEFINER Function"). Both already guard on
-- `auth.uid() IS NULL`, so an anon call was inert -- but exposing a DEFINER
-- function (runs with owner privileges, bypassing RLS) to anon is a
-- defense-in-depth violation we close here.

-- ---------------------------------------------------------------------------
-- redeem_code(text): MUST stay SECURITY DEFINER -- it inserts into friendships,
-- which has no client insert policy. Just remove the implicit PUBLIC/anon grant
-- and keep it callable only by authenticated users (Supabase anonymous-auth
-- users have a JWT and map to the `authenticated` role, so the app is unaffected).
-- ---------------------------------------------------------------------------
revoke execute on function public.redeem_code(text) from public;
revoke execute on function public.redeem_code(text) from anon;
grant execute on function public.redeem_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- ensure_friend_code(): does NOT need elevated rights. The players RLS policy
-- (player_self: `auth.uid() = id`, FOR ALL) already lets an authenticated caller
-- UPDATE their own friend_code, and the UNIQUE(friend_code) table constraint
-- enforces collision handling regardless of security context. Downgrade to
-- SECURITY INVOKER (least privilege) and restrict EXECUTE to authenticated.
-- Body is unchanged except for the security clause.
-- ---------------------------------------------------------------------------
create or replace function ensure_friend_code()
returns text
language plpgsql security invoker
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_existing text;
  v_code text;
  v_alphabet text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; -- base32 (no 0/1/8/9)
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

-- CREATE OR REPLACE preserves the existing (PUBLIC) ACL, so revoke explicitly.
revoke execute on function public.ensure_friend_code() from public;
revoke execute on function public.ensure_friend_code() from anon;
grant execute on function public.ensure_friend_code() to authenticated;
