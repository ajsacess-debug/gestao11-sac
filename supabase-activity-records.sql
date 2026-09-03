-- Armazenamento compartilhado e não destrutivo das atividades existentes.
create table if not exists public.activity_records (
  id bigint primary key,
  payload jsonb not null,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.activity_records enable row level security;

drop policy if exists "activity_records_select" on public.activity_records;
create policy "activity_records_select"
on public.activity_records for select
to authenticated
using (true);

drop policy if exists "activity_records_insert" on public.activity_records;
create policy "activity_records_insert"
on public.activity_records for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "activity_records_update" on public.activity_records;
create policy "activity_records_update"
on public.activity_records for update
to authenticated
using (true)
with check (true);

drop policy if exists "activity_records_delete_manager" on public.activity_records;
create policy "activity_records_delete_manager"
on public.activity_records for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.active = true
      and p.role in ('admin', 'manager')
  )
);
