-- Ajuste de permissões para sincronização online da Gestão One The One.
-- Seguro para dados existentes: não altera, não exclui e não substitui registros.

-- Permite que usuários logados consultem a lista operacional de usuários ativos.
-- O perfil ADM continua oculto nas telas porque role = 'admin' não é retornado.
alter table if exists public.profiles enable row level security;

drop policy if exists "profiles_select_active_operational" on public.profiles;
create policy "profiles_select_active_operational"
on public.profiles for select
to authenticated
using (active = true and role <> 'admin');

-- Reforça leitura e gravação compartilhada das atividades entre usuários autenticados.
-- A aplicação controla a visibilidade: ADM/Gerente veem tudo; Coordenador vê somente vínculo próprio.
alter table if exists public.activity_records enable row level security;

drop policy if exists "activity_records_select" on public.activity_records;
create policy "activity_records_select"
on public.activity_records for select
to authenticated
using (true);

drop policy if exists "activity_records_insert" on public.activity_records;
create policy "activity_records_insert"
on public.activity_records for insert
to authenticated
with check (true);

drop policy if exists "activity_records_update" on public.activity_records;
create policy "activity_records_update"
on public.activity_records for update
to authenticated
using (true)
with check (true);
