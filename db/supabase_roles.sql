-- Роли пользователей в Supabase.
-- Выполняется один раз в SQL Editor панели Supabase.
--
-- Идея: у каждого зарегистрированного пользователя есть строка в таблице
-- profiles с ролью. Приложение читает оттуда свою роль и по ней решает,
-- показывать ли кнопку удаления. Но решает не только приложение: само
-- правило удаления записано в базе, поэтому обойти его, подменив
-- интерфейс, не получится.

-- ───────── 1. Таблица профилей ─────────

create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  email      text,
  role       text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Пользователь видит только свой профиль.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select using (auth.uid() = id);

-- Политик insert/update/delete для приложения нет намеренно:
-- менять роли можно только отсюда, из SQL Editor. Иначе любой желающий
-- выдал бы себе роль администратора прямо из браузера.

-- ───────── 2. Профиль создаётся сам при регистрации ─────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────── 3. Профили тем, кто зарегистрировался раньше ─────────

insert into public.profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- ───────── 4. Права на таблицу Users ─────────

alter table public."Users" enable row level security;

-- Читать список может кто угодно: список показывается и тем, кто вошёл
-- через ВК или Яндекс, а для Supabase такой вход «чужой».
drop policy if exists users_select_all on public."Users";
create policy users_select_all on public."Users"
  for select using (true);

-- Добавлять — тоже кто угодно, по той же причине.
drop policy if exists users_insert_all on public."Users";
create policy users_insert_all on public."Users"
  for insert with check (true);

-- А удалять — только администратор.
drop policy if exists users_delete_admin on public."Users";
create policy users_delete_admin on public."Users"
  for delete using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- ───────── 5. Назначить себе роль администратора ─────────

update public.profiles
   set role = 'admin'
 where email = 'hotfloe0410@gmail.com';

-- Проверка: должно быть видно, у кого какая роль.
select email, role, created_at from public.profiles order by created_at;
