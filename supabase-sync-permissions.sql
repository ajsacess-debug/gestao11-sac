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

-- Permite desativar acessos sem excluir seus registros nem o histórico de atividades.
-- ADM pode desativar qualquer usuário operacional; gerente, somente coordenadores.
-- A função também bloqueia o login no Supabase. O acesso ADM nunca pode ser removido.
create or replace function public.deactivate_managed_user(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requester_role text;
  target_role text;
begin
  select role into requester_role
  from public.profiles
  where id = auth.uid() and active = true;

  if requester_role not in ('admin', 'manager') then
    raise exception 'Sem permissão para excluir acessos.';
  end if;

  if target_id = auth.uid() then
    raise exception 'Não é possível excluir o próprio acesso.';
  end if;

  select role into target_role from public.profiles where id = target_id;
  if target_role is null then
    raise exception 'Usuário não localizado.';
  end if;
  if target_role = 'admin' then
    raise exception 'O acesso ADM não pode ser excluído.';
  end if;
  if requester_role = 'manager' and target_role <> 'coordinator' then
    raise exception 'Gerente pode excluir somente acessos de coordenação.';
  end if;

  update public.profiles set active = false where id = target_id;
  update auth.users set banned_until = 'infinity' where id = target_id;
end;
$$;

revoke all on function public.deactivate_managed_user(uuid) from public;
grant execute on function public.deactivate_managed_user(uuid) to authenticated;

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
