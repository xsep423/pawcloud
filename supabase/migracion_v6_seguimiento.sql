-- PawCloud — migración v6: seguimiento posterior a la adopción
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.

-- Cuidados de cada mascota adoptada: vacunas, desparasitación, esterilización y citas
create table if not exists public.care_events (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  adopter_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('vacuna','desparasitacion','esterilizacion','cita','otro')),
  title text not null check (char_length(title) between 1 and 80),
  event_date date not null,
  done boolean not null default false,
  notes text check (notes is null or char_length(notes) <= 300),
  created_at timestamptz not null default now()
);

create index if not exists care_events_adopter on public.care_events (adopter_id, event_date);
create index if not exists care_events_pet on public.care_events (pet_id);

alter table public.care_events enable row level security;

-- El adoptante gestiona el seguimiento SOLO de mascotas cuya adopción fue aceptada
drop policy if exists "adoptante gestiona su seguimiento" on public.care_events;
create policy "adoptante gestiona su seguimiento" on public.care_events for all
  using (adopter_id = auth.uid())
  with check (
    adopter_id = auth.uid() and exists (
      select 1 from public.adoption_requests r
      where r.pet_id = care_events.pet_id and r.adopter_id = auth.uid() and r.status = 'aceptada')
  );

-- Quien dio la mascota en adopción y el admin pueden consultar el seguimiento
drop policy if exists "dueno y admin ven seguimiento" on public.care_events;
create policy "dueno y admin ven seguimiento" on public.care_events for select
  using (
    public.is_admin()
    or exists (select 1 from public.pets p where p.id = care_events.pet_id and p.owner_id = auth.uid())
  );
