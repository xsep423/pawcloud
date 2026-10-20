-- PawCloud — migración v5 (corre UNA vez en SQL Editor; NO borra datos)
-- 1) Una sola solicitud por adoptante y mascota
create unique index if not exists one_request_per_pet
  on public.adoption_requests (pet_id, adopter_id);

-- 2) El adoptante puede cancelar sus solicitudes pendientes
drop policy if exists "adoptante cancela solicitud" on public.adoption_requests;
create policy "adoptante cancela solicitud" on public.adoption_requests for delete
  using (adopter_id = auth.uid() and status = 'pendiente');

-- 3) Quien publicó una mascota puede retirarla
drop policy if exists "dueno retira mascota" on public.pets;
create policy "dueno retira mascota" on public.pets for delete
  using (owner_id = auth.uid());
