-- =========================================================
-- PawCloud — esquema de base de datos (v2) para Supabase
-- Pégalo completo en: Supabase > SQL Editor > New query > Run
-- Es seguro volver a correrlo: borra y recrea las tablas de PawCloud.
-- =========================================================

-- ---------- Limpieza (para poder re-ejecutar) ----------
drop trigger if exists on_auth_user_created on auth.users;
drop table if exists public.adoption_requests cascade;
drop table if exists public.pets cascade;
drop table if exists public.places cascade;
drop table if exists public.profiles cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.set_pet_moderation() cascade;
drop function if exists public.guard_pet_update() cascade;
drop type if exists public.user_role cascade;

-- ---------- Tipos y tablas ----------
create type public.user_role as enum ('adoptante', 'refugio', 'rescatista', 'admin');

-- Perfil de cada cuenta (el login real lo maneja Supabase Auth)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null,
  role public.user_role not null default 'adoptante',
  org_name text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

-- Mascotas publicadas (por refugios o rescatistas individuales)
create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  owner_name text,
  name text not null,
  species text not null check (species in ('perro','gato')),
  size text not null check (size in ('pequeno','mediano','grande')),
  age text not null,
  description text,
  photo_url text,
  apto_depto boolean not null default false,
  tag text,
  moderation text not null default 'pendiente' check (moderation in ('pendiente','aprobada','rechazada')),
  status text not null default 'disponible' check (status in ('disponible','adoptada')),
  created_at timestamptz not null default now()
);

-- Solicitudes de adopción
create table public.adoption_requests (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  adopter_id uuid not null references public.profiles(id) on delete cascade,
  adopter_name text,
  housing_type text,
  other_pets text,
  message text,
  status text not null default 'pendiente' check (status in ('pendiente','aceptada','rechazada')),
  created_at timestamptz not null default now(),
  unique (pet_id, adopter_id)
);

-- Centros de ayuda y veterinarias (para el mapa)
create table public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('veterinaria','refugio','centro_ayuda')),
  address text,
  phone text,
  lat double precision not null,
  lng double precision not null,
  created_at timestamptz not null default now()
);

-- ---------- Funciones ----------
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Al registrarse alguien, se crea su perfil. Nunca se puede crear un admin desde el registro.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare r text := coalesce(new.raw_user_meta_data->>'role', 'adoptante');
begin
  if r not in ('adoptante','refugio','rescatista') then r := 'adoptante'; end if;
  insert into public.profiles (id, email, name, role, org_name, verified)
  values (
    new.id, new.email,
    coalesce(nullif(new.raw_user_meta_data->>'name',''), split_part(new.email,'@',1)),
    r::public.user_role,
    nullif(new.raw_user_meta_data->>'org_name',''),
    r in ('adoptante','rescatista')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Moderación automática: las publicaciones de un refugio verificado se aprueban solas;
-- las de rescatistas individuales quedan "pendiente" hasta que un admin las apruebe.
create or replace function public.set_pet_moderation()
returns trigger language plpgsql security definer set search_path = public as $$
declare p public.profiles;
begin
  select * into p from public.profiles where id = auth.uid();
  new.owner_id := auth.uid();
  new.owner_name := coalesce(p.org_name, p.name);
  if p.role = 'admin' or (p.role = 'refugio' and p.verified) then
    new.moderation := 'aprobada';
  else
    new.moderation := 'pendiente';
  end if;
  return new;
end $$;

create trigger pets_moderation
  before insert on public.pets
  for each row when (auth.uid() is not null)
  execute function public.set_pet_moderation();

-- Solo un admin puede cambiar el estado de moderación o el dueño de una publicación
create or replace function public.guard_pet_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.moderation := old.moderation;
    new.owner_id := old.owner_id;
  end if;
  return new;
end $$;

create trigger pets_guard
  before update on public.pets
  for each row execute function public.guard_pet_update();

-- ---------- Seguridad por filas (RLS) ----------
alter table public.profiles enable row level security;
alter table public.pets enable row level security;
alter table public.adoption_requests enable row level security;
alter table public.places enable row level security;

-- profiles: cada quien ve el suyo; el admin ve y modifica todos (verificar refugios)
create policy "perfil propio" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "admin actualiza perfiles" on public.profiles for update using (public.is_admin());

-- pets: todos ven las aprobadas; el dueño ve las suyas; el admin ve y modera todas
create policy "catalogo publico" on public.pets for select
  using (moderation = 'aprobada' or owner_id = auth.uid() or public.is_admin());
create policy "publicar mascota" on public.pets for insert
  with check (
    owner_id = auth.uid() and exists (
      select 1 from public.profiles p where p.id = auth.uid()
      and (p.role = 'rescatista' or (p.role = 'refugio' and p.verified) or p.role = 'admin'))
  );
create policy "dueno edita sus mascotas" on public.pets for update
  using (owner_id = auth.uid() or public.is_admin());
create policy "admin borra mascotas" on public.pets for delete using (public.is_admin());
create policy "dueno retira mascota" on public.pets for delete using (owner_id = auth.uid());

-- adoption_requests
create policy "adoptante crea solicitud" on public.adoption_requests for insert
  with check (adopter_id = auth.uid());
create policy "ver solicitudes" on public.adoption_requests for select
  using (
    adopter_id = auth.uid() or public.is_admin()
    or exists (select 1 from public.pets p where p.id = pet_id and p.owner_id = auth.uid())
  );
create policy "adoptante cancela solicitud" on public.adoption_requests for delete
  using (adopter_id = auth.uid() and status = 'pendiente');
create policy "dueno responde solicitud" on public.adoption_requests for update
  using (public.is_admin() or exists (select 1 from public.pets p where p.id = pet_id and p.owner_id = auth.uid()));

-- places: lectura pública, escritura solo admin
create policy "mapa publico" on public.places for select using (true);
create policy "admin gestiona lugares" on public.places for all using (public.is_admin()) with check (public.is_admin());

-- ---------- Almacenamiento de fotos ----------
insert into storage.buckets (id, name, public)
values ('pet-photos', 'pet-photos', true)
on conflict (id) do nothing;

drop policy if exists "fotos publicas" on storage.objects;
drop policy if exists "subir fotos" on storage.objects;
create policy "fotos publicas" on storage.objects for select using (bucket_id = 'pet-photos');
create policy "subir fotos" on storage.objects for insert to authenticated with check (bucket_id = 'pet-photos');

-- ---------- Datos iniciales: 10 mascotas de ejemplo (fotos en /images del sitio) ----------
insert into public.pets (owner_name, name, species, size, age, description, photo_url, apto_depto, tag, moderation) values
('Refugio Huellas de Tijuana','Rex','perro','mediano','2 años','Rex es tranquilo, sociable con otros perros y ya conoce la orden "sentado". Ideal para una familia con patio o para salidas frecuentes.','images/beagle.jpg',false,'Nuevo','aprobada'),
('Rescate Felino BC','Mía','gato','pequeno','1 año','Mía es curiosa y cariñosa una vez que confía en ti. Se lleva bien con niños y le encanta dormir cerca de una ventana soleada.','images/siamese.jpg',true,null,'aprobada'),
('Refugio Huellas de Tijuana','Toby','perro','pequeno','4 años','Toby es juguetón, le encanta la compañía y se adapta bien a departamentos. Ya está acostumbrado a caminar con correa.','images/pug.jpg',true,null,'aprobada'),
('Rescate Felino BC','Luna','gato','mediano','3 años','Luna es independiente pero muy leal a su familia. Convive bien con otros gatos y disfruta de espacios altos para trepar.','images/tigercat.jpg',true,null,'aprobada'),
('Patitas Felices A.C.','Nube','perro','pequeno','1 año','Nube es enérgica y muy apegada a las personas. Todavía está en entrenamiento básico, ideal para alguien con tiempo para socializarla.','images/chihuahua.jpg',true,'Nuevo','aprobada'),
('Refugio Huellas de Tijuana','Sol','perro','grande','3 años','Sol es amigable con todos, niños incluidos. Le encanta nadar y necesita ejercicio diario, ideal para familias activas.','images/golden.jpg',false,null,'aprobada'),
('Rescate Felino BC','Coco','gato','mediano','2 años','Coco es tranquila y elegante, disfruta de siestas largas. Requiere cepillado semanal por su pelaje largo.','images/persian.jpg',true,null,'aprobada'),
('Patitas Felices A.C.','Thor','perro','grande','4 años','Thor es protector, inteligente y obediente. Ya tiene entrenamiento básico y se lleva bien con otros perros grandes.','images/shepherd.jpg',false,null,'aprobada'),
('Rescate Felino BC','Cleo','gato','pequeno','2 años','Cleo es activa y vocal, le gusta jugar con pelotas y perseguir luces. Se adapta rápido a hogares con otras mascotas.','images/egyptian.jpg',true,null,'aprobada'),
('Refugio Huellas de Tijuana','Nieve','perro','grande','2 años','Nieve es vivaz y necesita mucho ejercicio. Es vocal y muy sociable, perfecta para dueños con experiencia en razas activas.','images/husky.jpg',false,'Nuevo','aprobada');

-- ---------- Crear al administrador ----------
-- 1) Regístrate en el sitio con tu correo (como "adoptante").
-- 2) Corre esta línea cambiando el correo, en una consulta nueva:
--
-- update public.profiles set role = 'admin', verified = true where email = 'TU_CORREO@gmail.com';
