-- PawCloud — migración v10: día/hora de entrega al aprobar y notificaciones al adoptante
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.

-- 1) Datos de entrega que llena el refugio al aprobar
alter table public.adoption_requests
  add column if not exists pickup_at    timestamptz,
  add column if not exists pickup_place text check (pickup_place is null or char_length(pickup_place) <= 160),
  add column if not exists refuge_note  text check (refuge_note  is null or char_length(refuge_note)  <= 400);

-- 2) Notificaciones: una por cada cambio de estado de una solicitud
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid references public.adoption_requests(id) on delete cascade,
  status text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
drop policy if exists "ver mis notificaciones" on public.notifications;
create policy "ver mis notificaciones" on public.notifications for select using (user_id = auth.uid());
drop policy if exists "marcar mis notificaciones" on public.notifications;
create policy "marcar mis notificaciones" on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
-- Nadie las inserta desde el sitio: las crea el trigger de abajo

-- 3) Cada cambio de estado avisa al adoptante
create or replace function public.notify_request_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    insert into public.notifications (user_id, request_id, status) values (new.adopter_id, new.id, new.status);
  end if;
  return new;
end $$;

drop trigger if exists notify_request_status on public.adoption_requests;
create trigger notify_request_status after update on public.adoption_requests
  for each row execute function public.notify_request_status();
