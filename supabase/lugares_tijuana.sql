-- PawCloud — lugares reales del mapa en Tijuana (corre en SQL Editor; NO borra datos)
-- Se puede correr más de una vez: no duplica lugares que ya existan con el mismo nombre.
--
-- Fuentes:
--   Coordenadas: DENUE de INEGI (Directorio Estadístico Nacional de Unidades Económicas)
--   y OpenStreetMap. Teléfonos: sitios de cada lugar, directorios web y DENUE.
--   Conviene llamar antes de visitar: horarios y teléfonos pueden cambiar.

insert into public.places (name, kind, address, phone, lat, lng)
select v.name, v.kind, v.address, v.phone, v.lat, v.lng
from (values
  -- Veterinarias
  ('Profauna Hospital Veterinario 24 Horas', 'veterinaria', 'Blvd. Fundadores 3008, Col. Juárez', '664 200 2451', 32.513683, -117.031192),
  ('Hospivet', 'veterinaria', 'Blvd. Padre Kino 10298-B, Zona Río', '664 683 6650', 32.531239, -117.013643),
  ('Hospital y Hotel Veterinario Dr. Zoo', 'veterinaria', 'Paseo del Centenario 9211, Plaza Pueblo Amigo, Zona Río', '664 607 7527', 32.536878, -117.024710),
  ('Hospital Veterinario El Perro Andaluz', 'veterinaria', 'Blvd. Cuauhtémoc Sur Ote. 2920, Col. Gavilondo', '664 208 5314', 32.515436, -117.021199),
  ('Hospital de Mascotas SAJI', 'veterinaria', 'Vía Rápida Oriente 6876, Río Tijuana 3a. Etapa', '664 866 6457', 32.486987, -116.934569),
  ('Centro Médico Veterinario Tijuana', 'veterinaria', 'Blvd. de las Américas 361, Col. 20 de Noviembre', '664 104 4221', 32.514471, -116.987385),
  ('Otay Vet Clínica Veterinaria', 'veterinaria', 'Calle Cándido Aguilar 1908, Local 6, Otay Constituyentes', '664 623 7999', 32.530241, -116.947991),
  ('Centro Médico Felino Langostitas', 'veterinaria', 'Calle Venustiano Carranza s/n, Otay Galerías', '664 331 7047', 32.534917, -116.934952),
  ('Clínica Veterinaria Dog''na', 'veterinaria', 'Blvd. Héctor Terán Terán 2714, Jardín Dorado', '661 125 8466', 32.522248, -116.890274),
  ('Pet Clinic de Playas', 'veterinaria', 'Paseo Playas de Tijuana 2587-A, Playas Costa Hermosa', '664 631 1660', 32.512873, -117.120108),
  ('Veterinaria Gutiérrez', 'veterinaria', 'Av. Séptima (Galeana) 8123-103, Zona Centro', '664 638 4164', 32.529922, -117.030437),
  ('Hospital Veterinario Chapultepets', 'veterinaria', 'Calle 13a. Ignacio Ramos 1024-C, Col. Libertad', '663 203 0182', 32.534982, -117.012119),
  ('Hospital Veterinario Florens', 'veterinaria', 'Av. Insurgentes 40, Col. Tomás Aquino', '664 912 7034', 32.529129, -116.983010),
  ('Hospital Veterinario Las Palmas', 'veterinaria', 'Av. Las Palmas 4721, Fracc. Las Palmas', '664 681 6856', 32.503518, -116.985737),
  ('Veterinaria de Urgencias', 'veterinaria', 'Calle Guadalupe I. Ramírez 794, Col. del Río', '664 394 7956', 32.525535, -116.994823),
  ('Veterinaria 24 Horas El Refugio', 'veterinaria', 'Circuito Oyameles s/n, El Refugio Quintas Campestres', '664 385 0371', 32.461391, -116.832364),
  -- Refugios
  ('Refugio de Perros Patitas Firmes', 'refugio', 'Calle Cañón del Padre s/n, Col. Murúa Oriente', null, 32.516786, -116.920297),
  -- Centros de ayuda
  ('Centro de Control Animal Municipal', 'centro_ayuda', 'Blvd. Insurgentes s/n, Valle de las Flores (adopciones lun–sáb 8:00–15:00)', '664 208 9212', 32.460704, -116.900964),
  ('Centro de Observación y Vacunación Canina-Felina', 'centro_ayuda', 'Calle Nahuas, Zempoala s/n, Col. Mariano Matamoros', '664 987 8584', 32.479499, -116.875735)
) as v(name, kind, address, phone, lat, lng)
where not exists (select 1 from public.places p where p.name = v.name);
