-- PawCloud — migración v7: línea de tiempo de la solicitud de adopción
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.
-- Estados: pendiente → en_revision → aceptada → periodo_prueba (15 días) → completada  (o rechazada)

-- 1) Fechas de cada paso
alter table public.adoption_requests
  add column if not exists reviewed_at  timestamptz,
  add column if not exists approved_at  timestamptz,
  add column if not exists trial_until  date,
  add column if not exists completed_at timestamptz;

-- 2) Nuevos estados permitidos
alter table public.adoption_requests drop constraint if exists adoption_requests_status_check;
alter table public.adoption_requests add constraint adoption_requests_status_check
  check (status in ('pendiente','en_revision','aceptada','periodo_prueba','completada','rechazada'));

-- 3) Cada vez que cambia el estado se guarda la fecha del paso (el periodo de prueba dura 15 días)
create or replace function public.stamp_request_status() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'en_revision'    then new.reviewed_at  := coalesce(new.reviewed_at, now()); end if;
    if new.status = 'aceptada'       then new.approved_at  := coalesce(new.approved_at, now()); end if;
    if new.status = 'periodo_prueba' then new.trial_until  := coalesce(new.trial_until, current_date + 15); end if;
    if new.status = 'completada'     then new.completed_at := coalesce(new.completed_at, now()); end if;
  end if;
  return new;
end $$;

drop trigger if exists stamp_request_status on public.adoption_requests;
create trigger stamp_request_status before update on public.adoption_requests
  for each row execute function public.stamp_request_status();

-- 4) El adoptante puede cancelar mientras no se haya aprobado
drop policy if exists "adoptante cancela solicitud" on public.adoption_requests;
create policy "adoptante cancela solicitud" on public.adoption_requests for delete
  using (adopter_id = auth.uid() and status in ('pendiente','en_revision'));

-- 5) El seguimiento (vacunas, citas) sigue disponible en prueba y después de completar
drop policy if exists "adoptante gestiona su seguimiento" on public.care_events;
create policy "adoptante gestiona su seguimiento" on public.care_events for all
  using (adopter_id = auth.uid())
  with check (
    adopter_id = auth.uid() and exists (
      select 1 from public.adoption_requests r
      where r.pet_id = care_events.pet_id and r.adopter_id = auth.uid()
        and r.status in ('aceptada','periodo_prueba','completada'))
  );

-- 6) Datos demo: las solicitudes ya aceptadas tienen fechas en su línea de tiempo
update public.adoption_requests
   set reviewed_at = coalesce(reviewed_at, created_at + interval '1 day'),
       approved_at = coalesce(approved_at, created_at + interval '3 days')
 where status = 'aceptada';
