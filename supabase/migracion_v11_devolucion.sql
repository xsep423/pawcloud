-- PawCloud — migración v11: al aprobar se cierran las demás solicitudes; devolución en el periodo de prueba
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.

-- Motivo de cierre automático (para explicarle al adoptante por qué se cerró)
alter table public.adoption_requests
  add column if not exists close_reason text check (close_reason is null or close_reason in ('adoptada_otra'));

-- Nuevo estado: devuelta (la mascota regresó al refugio durante la entrega o el periodo de prueba)
alter table public.adoption_requests drop constraint if exists adoption_requests_status_check;
alter table public.adoption_requests add constraint adoption_requests_status_check
  check (status in ('pendiente','en_revision','aceptada','periodo_prueba','completada','rechazada','devuelta'));

-- Efectos de cada cambio de estado, hechos por la base de datos (no dependen de quién apruebe):
--   aceptada → la mascota sale del catálogo y las demás solicitudes abiertas por ella se cierran
--   devuelta → la mascota vuelve al catálogo
create or replace function public.request_status_effects() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'aceptada' then
      update public.pets set status = 'adoptada' where id = new.pet_id;
      update public.adoption_requests set status = 'rechazada', close_reason = 'adoptada_otra'
       where pet_id = new.pet_id and id <> new.id and status in ('pendiente','en_revision');
    elsif new.status = 'devuelta' then
      update public.pets set status = 'disponible' where id = new.pet_id;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists request_status_effects on public.adoption_requests;
create trigger request_status_effects after update on public.adoption_requests
  for each row execute function public.request_status_effects();
