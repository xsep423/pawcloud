-- PawCloud — migración v9: campañas de esterilización, vacunación y adopción en el mapa
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 100),
  kind text not null check (kind in ('esterilizacion','vacunacion','adopcion')),
  organizer text,
  address text,
  lat double precision not null,
  lng double precision not null,
  starts_on date not null,
  ends_on date not null,
  cost text,
  details text check (details is null or char_length(details) <= 400),
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);
create index if not exists campaigns_ends_on on public.campaigns (ends_on);

alter table public.campaigns enable row level security;
drop policy if exists "campanas publicas" on public.campaigns;
create policy "campanas publicas" on public.campaigns for select using (true);
drop policy if exists "admin gestiona campanas" on public.campaigns;
create policy "admin gestiona campanas" on public.campaigns for all using (public.is_admin()) with check (public.is_admin());

-- Campañas de EJEMPLO para la demostración (fechas relativas a hoy, para que siempre se vean vigentes).
-- Organiza el refugio ficticio de los datos demo; las ubicaciones son aproximadas.
insert into public.campaigns (title, kind, organizer, address, lat, lng, starts_on, ends_on, cost, details)
select v.* from (values
  ('Vacunación antirrábica gratuita (ejemplo)', 'vacunacion', 'Refugio Huellas de Tijuana', 'Parque Teniente Guerrero, Zona Centro',
   32.5325, -117.0423, current_date - 1, current_date + 5, 'Gratis',
   'Campaña de ejemplo. Perros y gatos desde los 3 meses. De 9:00 a 14:00; lleva a tu mascota con correa o en transportadora.'),
  ('Jornada de esterilización a bajo costo (ejemplo)', 'esterilizacion', 'Refugio Huellas de Tijuana', 'Explanada del CECUT, Zona Río',
   32.5297, -117.0221, current_date + 3, current_date + 4, '$250 perro · $200 gato',
   'Campaña de ejemplo. Cupo limitado: llega temprano. La mascota debe venir en ayuno de 8 horas.'),
  ('Feria de adopción de fin de mes (ejemplo)', 'adopcion', 'Refugio Huellas de Tijuana', 'Malecón de Playas de Tijuana',
   32.5280, -117.1228, current_date + 10, current_date + 10, 'Entrada libre',
   'Campaña de ejemplo. Conoce a perros y gatos listos para adopción; los que adopten ese día se llevan un kit de bienvenida.')
) as v(title, kind, organizer, address, lat, lng, starts_on, ends_on, cost, details)
where not exists (select 1 from public.campaigns c where c.title = v.title);
