-- Finance Cloud: safe Supabase schema + permissions repair
-- Run in Supabase Dashboard > SQL Editor > New query.
-- This script is re-runnable and does not delete existing financial rows.

create extension if not exists pgcrypto;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null,
  amount bigint not null check (amount > 0),
  type text not null check (type in ('income', 'expense')),
  category text not null default '' check (char_length(category) <= 100),
  note text not null default '' check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  tags text[] not null default '{}'
);

create table if not exists public.settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  opening bigint not null default 0,
  unit text not null default 'toman' check (unit in ('toman', 'rial'))
);

create table if not exists public.budgets (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null check (char_length(category) between 1 and 100),
  amount bigint not null check (amount > 0),
  primary key (user_id, category)
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 100),
  target bigint not null check (target > 0),
  saved bigint not null default 0 check (saved >= 0),
  deadline date,
  created_at timestamptz not null default now()
);

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('payable', 'receivable')),
  person text not null check (char_length(person) between 1 and 100),
  amount bigint not null check (amount > 0),
  settled bigint not null default 0 check (settled >= 0 and settled <= amount),
  due_date date,
  note text not null default '' check (char_length(note) <= 500),
  created_at timestamptz not null default now()
);

alter table public.transactions add column if not exists tags text[] not null default '{}';

create index if not exists transactions_user_date_idx
  on public.transactions (user_id, date desc);
create index if not exists debts_user_created_idx
  on public.debts (user_id, created_at desc);

alter table public.transactions enable row level security;
alter table public.settings enable row level security;
alter table public.budgets enable row level security;
alter table public.goals enable row level security;
alter table public.debts enable row level security;

-- Ensure the browser's public/anon key cannot read or write private financial data.
revoke all on public.transactions from anon;
revoke all on public.settings from anon;
revoke all on public.budgets from anon;
revoke all on public.goals from anon;
revoke all on public.debts from anon;

-- The signed-in app needs these table privileges; RLS below still limits rows to auth.uid().
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.settings to authenticated;
grant select, insert, update, delete on public.budgets to authenticated;
grant select, insert, update, delete on public.goals to authenticated;
grant select, insert, update, delete on public.debts to authenticated;

drop policy if exists tx_select_own on public.transactions;
drop policy if exists tx_insert_own on public.transactions;
drop policy if exists tx_update_own on public.transactions;
drop policy if exists tx_delete_own on public.transactions;
create policy tx_select_own on public.transactions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy tx_insert_own on public.transactions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy tx_update_own on public.transactions for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy tx_delete_own on public.transactions for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists set_select_own on public.settings;
drop policy if exists set_insert_own on public.settings;
drop policy if exists set_update_own on public.settings;
drop policy if exists set_delete_own on public.settings;
create policy set_select_own on public.settings for select to authenticated
  using ((select auth.uid()) = user_id);
create policy set_insert_own on public.settings for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy set_update_own on public.settings for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy set_delete_own on public.settings for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists budgets_select_own on public.budgets;
drop policy if exists budgets_insert_own on public.budgets;
drop policy if exists budgets_update_own on public.budgets;
drop policy if exists budgets_delete_own on public.budgets;
create policy budgets_select_own on public.budgets for select to authenticated
  using ((select auth.uid()) = user_id);
create policy budgets_insert_own on public.budgets for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy budgets_update_own on public.budgets for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy budgets_delete_own on public.budgets for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists goals_select_own on public.goals;
drop policy if exists goals_insert_own on public.goals;
drop policy if exists goals_update_own on public.goals;
drop policy if exists goals_delete_own on public.goals;
create policy goals_select_own on public.goals for select to authenticated
  using ((select auth.uid()) = user_id);
create policy goals_insert_own on public.goals for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy goals_update_own on public.goals for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy goals_delete_own on public.goals for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists debts_select_own on public.debts;
drop policy if exists debts_insert_own on public.debts;
drop policy if exists debts_update_own on public.debts;
drop policy if exists debts_delete_own on public.debts;
create policy debts_select_own on public.debts for select to authenticated
  using ((select auth.uid()) = user_id);
create policy debts_insert_own on public.debts for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy debts_update_own on public.debts for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy debts_delete_own on public.debts for delete to authenticated
  using ((select auth.uid()) = user_id);

-- PostgREST schema cache refresh (safe; no data changes).
notify pgrst, 'reload schema';
