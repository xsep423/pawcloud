-- PawCloud — migración v8: sexo y salud de cada mascota (etiquetas de las tarjetas)
-- Corre UNA vez en Supabase > SQL Editor > New query > Run. NO borra datos.

alter table public.pets
  add column if not exists sex text check (sex in ('macho','hembra')),
  add column if not exists vacunado boolean not null default false,
  add column if not exists esterilizado boolean not null default false;

-- Datos demo: sexo y salud de las 29 mascotas de ejemplo (puedes ajustarlos después)
update public.pets p set sex = d.sex, vacunado = d.vacunado, esterilizado = d.esterilizado
from (values
  ('de000000-0000-4000-9000-000000000001', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000002', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000003', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000004', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000005', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000006', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000007', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000008', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000009', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000010', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000011', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000012', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000013', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000014', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000015', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000016', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000017', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000018', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000019', 'hembra', true, true),
  ('de000000-0000-4000-9000-000000000020', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000021', 'hembra', false, false),
  ('de000000-0000-4000-9000-000000000022', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000023', 'macho', true, true),
  ('de000000-0000-4000-9000-000000000024', 'hembra', true, false),
  ('de000000-0000-4000-9000-000000000025', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000026', 'hembra', false, false),
  ('de000000-0000-4000-9000-000000000027', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000028', 'macho', false, false),
  ('de000000-0000-4000-9000-000000000029', 'hembra', false, false)
) as d(id, sex, vacunado, esterilizado)
where p.id = d.id::uuid;
