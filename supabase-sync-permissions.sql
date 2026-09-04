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

-- Permite restaurar um acesso anteriormente desativado, sem criar duplicidade.
-- A senha provisória informada pelo ADM/gerente passa a valer imediatamente.
create or replace function public.reactivate_managed_user(
  p_name text,
  p_email text,
  p_username text,
  p_password text,
  p_role text default 'coordinator'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  requester_role text;
  target_role text;
  target_id uuid;
begin
  select role into requester_role from public.profiles where id = auth.uid() and active = true;
  if requester_role not in ('admin', 'manager') then
    raise exception 'Sem permissão para reativar acessos.';
  end if;
  if p_role not in ('coordinator', 'manager') then
    raise exception 'Nível de acesso inválido.';
  end if;
  if requester_role = 'manager' and p_role <> 'coordinator' then
    raise exception 'Gerente pode reativar somente acessos de coordenação.';
  end if;

  select id into target_id from auth.users where lower(email) = lower(p_email);
  if target_id is null then
    raise exception 'Não existe um acesso anterior com este e-mail.';
  end if;
  select role into target_role from public.profiles where id = target_id;
  if target_role = 'admin' then
    raise exception 'O acesso ADM não pode ser alterado por este fluxo.';
  end if;

  update auth.users
  set banned_until = null,
      encrypted_password = crypt(p_password, gen_salt('bf')),
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('name', p_name, 'username', p_username, 'role', p_role, 'must_change_password', true),
      updated_at = now()
  where id = target_id;

  insert into public.profiles (id, name, username, role, active, must_change_password)
  values (target_id, p_name, p_username, p_role, true, true)
  on conflict (id) do update
  set name = excluded.name,
      username = excluded.username,
      role = excluded.role,
      active = true,
      must_change_password = true;

  return target_id;
end;
$$;

revoke all on function public.reactivate_managed_user(text, text, text, text, text) from public;
grant execute on function public.reactivate_managed_user(text, text, text, text, text) to authenticated;

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
