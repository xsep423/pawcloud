-- =========================================================
-- PawCloud — DATOS DE DEMOSTRACIÓN
-- Simula la plataforma en uso: 16 cuentas (admin, 4 refugios, 3 rescatistas, 8 adoptantes),
-- 29 mascotas nuevas con fotos reales, solicitudes en todos los estados y seguimiento de adopciones.
--
-- Cómo usarlo: Supabase > SQL Editor > New query > pega todo > Run.
--   * Requiere haber corrido schema.sql (y las migraciones) antes.
--   * Se puede correr varias veces: primero borra los datos demo anteriores.
--   * No toca tu cuenta ni las cuentas reales: solo las que terminan en @pawcloud.test.
--   * Para quitar la demo, corre solo el bloque "0) Limpieza".
--
-- Todas las cuentas demo usan la contraseña:  PawCloud2026
-- Las personas, refugios e historias son ficticios. Fotos: images/mascotas/CREDITOS.md
-- =========================================================

begin;

-- El guardia de pets impide cambiar owner_id fuera de una sesión de admin; lo pausamos durante la carga.
alter table public.pets disable trigger pets_guard;

-- ---------- 0) Limpieza de una carga anterior ----------
delete from public.pets where photo_url like 'images/mascotas/%';
update public.pets set owner_id = null, status = 'disponible'
  where owner_id in (select id from auth.users where email like '%@pawcloud.test');
delete from auth.users where email like '%@pawcloud.test';  -- borra en cascada perfiles, solicitudes y seguimiento

-- ---------- 1) Cuentas ----------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, last_sign_in_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new)
select '00000000-0000-0000-0000-000000000000', v.id::uuid, 'authenticated', 'authenticated', v.email,
  extensions.crypt('PawCloud2026', extensions.gen_salt('bf')), now() - v.dias * interval '1 day', now() - interval '1 day' * (v.dias / 4),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('name', v.name, 'role', v.role, 'org_name', coalesce(v.org, '')),
  now() - v.dias * interval '1 day', now() - v.dias * interval '1 day', '', '', '', ''
from (values
  ('de000000-0000-4000-8000-000000000001', 'coordinacion@pawcloud.test', 'Coordinación PawCloud', 'admin', null, 75),
  ('de000000-0000-4000-8000-000000000002', 'huellas@pawcloud.test', 'Mariana López Ibarra', 'refugio', 'Refugio Huellas de Tijuana', 70),
  ('de000000-0000-4000-8000-000000000003', 'rescatefelino@pawcloud.test', 'Andrea Ruiz Beltrán', 'refugio', 'Rescate Felino BC', 68),
  ('de000000-0000-4000-8000-000000000004', 'patitasfelices@pawcloud.test', 'Jorge Hernández Soto', 'refugio', 'Patitas Felices A.C.', 66),
  ('de000000-0000-4000-8000-000000000005', 'albergueotay@pawcloud.test', 'Roberto Salas Medina', 'refugio', 'Albergue Canino Otay', 2),
  ('de000000-0000-4000-8000-000000000006', 'daniela.castro@pawcloud.test', 'Daniela Castro Rivera', 'rescatista', null, 50),
  ('de000000-0000-4000-8000-000000000007', 'luisf.ramirez@pawcloud.test', 'Luis Fernando Ramírez', 'rescatista', null, 41),
  ('de000000-0000-4000-8000-000000000008', 'sofia.mendez@pawcloud.test', 'Sofía Méndez Arce', 'rescatista', null, 37),
  ('de000000-0000-4000-8000-000000000009', 'carlos.martinez@pawcloud.test', 'Carlos Martínez Peña', 'adoptante', null, 45),
  ('de000000-0000-4000-8000-000000000010', 'valeria.torres@pawcloud.test', 'Valeria Torres Luna', 'adoptante', null, 40),
  ('de000000-0000-4000-8000-000000000011', 'diego.navarro@pawcloud.test', 'Diego Navarro Gil', 'adoptante', null, 34),
  ('de000000-0000-4000-8000-000000000012', 'fernanda.ortiz@pawcloud.test', 'Fernanda Ortiz Camacho', 'adoptante', null, 30),
  ('de000000-0000-4000-8000-000000000013', 'alejandro.vega@pawcloud.test', 'Alejandro Vega Rosas', 'adoptante', null, 21),
  ('de000000-0000-4000-8000-000000000014', 'paola.jimenez@pawcloud.test', 'Paola Jiménez Duarte', 'adoptante', null, 52),
  ('de000000-0000-4000-8000-000000000015', 'ricardo.flores@pawcloud.test', 'Ricardo Flores Ayala', 'adoptante', null, 12),
  ('de000000-0000-4000-8000-000000000016', 'anasofia.guerrero@pawcloud.test', 'Ana Sofía Guerrero', 'adoptante', null, 6)
) as v(id, email, name, role, org, dias);

insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id::text, u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', u.last_sign_in_at, u.created_at, u.created_at
from auth.users u where u.email like '%@pawcloud.test';

-- Perfiles (el trigger ya los creó; aquí se fija rol, verificación y fecha)
insert into public.profiles (id, email, name, role, org_name, verified, created_at)
select v.id::uuid, v.email, v.name, v.role::public.user_role, v.org, v.verified, now() - v.dias * interval '1 day'
from (values
  ('de000000-0000-4000-8000-000000000001', 'coordinacion@pawcloud.test', 'Coordinación PawCloud', 'admin', null, true, 75),
  ('de000000-0000-4000-8000-000000000002', 'huellas@pawcloud.test', 'Mariana López Ibarra', 'refugio', 'Refugio Huellas de Tijuana', true, 70),
  ('de000000-0000-4000-8000-000000000003', 'rescatefelino@pawcloud.test', 'Andrea Ruiz Beltrán', 'refugio', 'Rescate Felino BC', true, 68),
  ('de000000-0000-4000-8000-000000000004', 'patitasfelices@pawcloud.test', 'Jorge Hernández Soto', 'refugio', 'Patitas Felices A.C.', true, 66),
  ('de000000-0000-4000-8000-000000000005', 'albergueotay@pawcloud.test', 'Roberto Salas Medina', 'refugio', 'Albergue Canino Otay', false, 2),
  ('de000000-0000-4000-8000-000000000006', 'daniela.castro@pawcloud.test', 'Daniela Castro Rivera', 'rescatista', null, true, 50),
  ('de000000-0000-4000-8000-000000000007', 'luisf.ramirez@pawcloud.test', 'Luis Fernando Ramírez', 'rescatista', null, true, 41),
  ('de000000-0000-4000-8000-000000000008', 'sofia.mendez@pawcloud.test', 'Sofía Méndez Arce', 'rescatista', null, true, 37),
  ('de000000-0000-4000-8000-000000000009', 'carlos.martinez@pawcloud.test', 'Carlos Martínez Peña', 'adoptante', null, true, 45),
  ('de000000-0000-4000-8000-000000000010', 'valeria.torres@pawcloud.test', 'Valeria Torres Luna', 'adoptante', null, true, 40),
  ('de000000-0000-4000-8000-000000000011', 'diego.navarro@pawcloud.test', 'Diego Navarro Gil', 'adoptante', null, true, 34),
  ('de000000-0000-4000-8000-000000000012', 'fernanda.ortiz@pawcloud.test', 'Fernanda Ortiz Camacho', 'adoptante', null, true, 30),
  ('de000000-0000-4000-8000-000000000013', 'alejandro.vega@pawcloud.test', 'Alejandro Vega Rosas', 'adoptante', null, true, 21),
  ('de000000-0000-4000-8000-000000000014', 'paola.jimenez@pawcloud.test', 'Paola Jiménez Duarte', 'adoptante', null, true, 52),
  ('de000000-0000-4000-8000-000000000015', 'ricardo.flores@pawcloud.test', 'Ricardo Flores Ayala', 'adoptante', null, true, 12),
  ('de000000-0000-4000-8000-000000000016', 'anasofia.guerrero@pawcloud.test', 'Ana Sofía Guerrero', 'adoptante', null, true, 6)
) as v(id, email, name, role, org, verified, dias)
on conflict (id) do update set name = excluded.name, role = excluded.role, org_name = excluded.org_name,
  verified = excluded.verified, created_at = excluded.created_at;

-- ---------- 2) Las 10 mascotas originales pasan a ser de sus refugios ----------
update public.pets set owner_id = 'de000000-0000-4000-8000-000000000002' where owner_name = 'Refugio Huellas de Tijuana' and owner_id is null;
update public.pets set owner_id = 'de000000-0000-4000-8000-000000000003' where owner_name = 'Rescate Felino BC' and owner_id is null;
update public.pets set owner_id = 'de000000-0000-4000-8000-000000000004' where owner_name = 'Patitas Felices A.C.' and owner_id is null;
update public.pets set status = 'adoptada' where name = 'Toby' and photo_url = 'images/pug.jpg';

-- ---------- 3) Mascotas nuevas ----------
insert into public.pets (id, owner_id, owner_name, name, species, size, age, description, photo_url, apto_depto, tag, moderation, status, created_at) values
('de000000-0000-4000-9000-000000000001', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Canela', 'perro', 'mediano', '3 años',
  'Canela llegó al refugio después de vivir en la calle por la colonia Libertad. Es dulce, un poco tímida al principio y muy cariñosa cuando agarra confianza. Ya está esterilizada y vacunada.',
  'images/mascotas/canela.jpg', true, null, 'aprobada', 'disponible', now() - interval '9 days' - interval '37 minutes'),
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Bruno', 'perro', 'mediano', '5 años',
  'Bruno es un bulldog tranquilo que disfruta de las siestas largas y los paseos cortos. Por su raza no tolera el calor fuerte, así que necesita un hogar fresco.',
  'images/mascotas/bruno.jpg', true, null, 'aprobada', 'adoptada', now() - interval '48 days' - interval '74 minutes'),
('de000000-0000-4000-9000-000000000003', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Chispa', 'perro', 'mediano', '2 años',
  'Chispa es muy inteligente y aprende rápido: ya sabe sentarse, dar la pata y esperar. Necesita actividad diaria y juegos de olfato para no aburrirse.',
  'images/mascotas/chispa.jpg', false, null, 'aprobada', 'disponible', now() - interval '22 days' - interval '111 minutes'),
('de000000-0000-4000-9000-000000000004', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Mostaza', 'perro', 'grande', '4 años',
  'Mostaza es noble y paciente con niños. Le encanta jugar con pelotas y nadar. Lo rescatamos en Playas de Tijuana; está sano y al día con sus vacunas.',
  'images/mascotas/mostaza.jpg', false, null, 'aprobada', 'disponible', now() - interval '31 days' - interval '148 minutes'),
('de000000-0000-4000-9000-000000000005', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Kira', 'perro', 'mediano', '1 año',
  'Kira tiene un ojo azul y uno café, y una energía contagiosa. Es sociable con otros perros; todavía está aprendiendo a caminar con correa.',
  'images/mascotas/kira.jpg', false, 'Nuevo', 'aprobada', 'disponible', now() - interval '3 days' - interval '185 minutes'),
('de000000-0000-4000-9000-000000000006', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Rocco', 'perro', 'grande', '3 años',
  'Rocco es un perro leal y juguetón, muy apegado a las personas. Busca un hogar donde sea el único perro y con alguien que tenga experiencia con perros grandes.',
  'images/mascotas/rocco.jpg', false, 'Urgente', 'aprobada', 'disponible', now() - interval '14 days' - interval '222 minutes'),
('de000000-0000-4000-9000-000000000007', 'de000000-0000-4000-8000-000000000002', 'Refugio Huellas de Tijuana', 'Ámbar', 'perro', 'mediano', '2 años',
  'Ámbar es activa, alegre y le fascina el agua. Convive bien con gatos. Ideal para una familia que salga a correr o de excursión.',
  'images/mascotas/ambar.jpg', false, null, 'aprobada', 'disponible', now() - interval '18 days' - interval '259 minutes'),
('de000000-0000-4000-9000-000000000008', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Pancho', 'perro', 'mediano', '9 años',
  'Pancho es un beagle senior que fue entregado cuando su familia se mudó. Es tranquilo, educado y solo pide una cama cómoda y paseos tranquilos.',
  'images/mascotas/pancho.jpg', true, 'Senior', 'aprobada', 'disponible', now() - interval '40 days' - interval '296 minutes'),
('de000000-0000-4000-9000-000000000009', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Galleta', 'perro', 'pequeno', '2 años',
  'Galleta es una perrita pequeña, juguetona y muy limpia. Se adapta perfecto a departamento y se lleva bien con niños.',
  'images/mascotas/galleta.jpg', true, null, 'aprobada', 'disponible', now() - interval '26 days' - interval '333 minutes'),
('de000000-0000-4000-9000-000000000010', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Frijol', 'perro', 'pequeno', '4 meses',
  'Frijol es un cachorro salchicha muy curioso. Tiene su primera vacuna y está aprendiendo a hacer sus necesidades en el tapete.',
  'images/mascotas/frijol.jpg', true, 'Cachorro', 'aprobada', 'disponible', now() - interval '5 days' - interval '370 minutes'),
('de000000-0000-4000-9000-000000000011', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Oso', 'perro', 'mediano', '3 meses',
  'Oso fue encontrado junto con sus hermanos en una caja cerca de la Presa. Es dormilón y tierno; crecerá a tamaño mediano-grande.',
  'images/mascotas/oso.jpg', false, 'Cachorro', 'aprobada', 'disponible', now() - interval '4 days' - interval '407 minutes'),
('de000000-0000-4000-9000-000000000012', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Lola', 'perro', 'mediano', '6 años',
  'Lola es una cocker muy dulce que adora que la cepillen. Necesita baño y corte de pelo cada mes y medio. Es tranquila dentro de casa.',
  'images/mascotas/lola.jpg', true, null, 'aprobada', 'disponible', now() - interval '35 days' - interval '444 minutes'),
('de000000-0000-4000-9000-000000000013', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Max', 'perro', 'grande', '2 años',
  'Max es un labrador chocolate lleno de energía. Ya tiene entrenamiento básico y le encanta traer la pelota una y otra vez.',
  'images/mascotas/max.jpg', false, null, 'aprobada', 'adoptada', now() - interval '44 days' - interval '481 minutes'),
('de000000-0000-4000-9000-000000000014', 'de000000-0000-4000-8000-000000000004', 'Patitas Felices A.C.', 'Bombón', 'perro', 'pequeno', '4 años',
  'Bombón es un perrito peludo y apapachador. Le gusta tomar el sol en el patio y acompañarte a todos lados dentro de la casa.',
  'images/mascotas/bombon.jpg', true, null, 'aprobada', 'disponible', now() - interval '12 days' - interval '518 minutes'),
('de000000-0000-4000-9000-000000000015', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Michi', 'gato', 'mediano', '3 años',
  'Michi es una gata atigrada, observadora y muy limpia. Prefiere hogares tranquilos; ya está esterilizada y desparasitada.',
  'images/mascotas/michi.jpg', true, null, 'aprobada', 'disponible', now() - interval '28 days' - interval '555 minutes'),
('de000000-0000-4000-9000-000000000016', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Humo', 'gato', 'mediano', '6 años',
  'Humo es un gato gris sereno al que le encanta dormir en lugares altos. Es ideal para alguien que trabaje desde casa.',
  'images/mascotas/humo.jpg', true, null, 'aprobada', 'disponible', now() - interval '33 days' - interval '592 minutes'),
('de000000-0000-4000-9000-000000000017', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Sombra', 'gato', 'pequeno', '2 años',
  'Sombra es reservada con desconocidos, pero en cuanto te conoce no se despega de ti. Usa su arenero sin problema.',
  'images/mascotas/sombra.jpg', true, null, 'aprobada', 'disponible', now() - interval '15 days' - interval '29 minutes'),
('de000000-0000-4000-9000-000000000018', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Don Gato', 'gato', 'mediano', '8 años',
  'Don Gato es un señor gato tranquilo que busca un retiro cómodo. Está sano, solo necesita su revisión anual y mucho cariño.',
  'images/mascotas/don-gato.jpg', true, 'Senior', 'aprobada', 'disponible', now() - interval '38 days' - interval '66 minutes'),
('de000000-0000-4000-9000-000000000019', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Mandarina', 'gato', 'pequeno', '1 año',
  'Mandarina es juguetona y muy platicadora. Se lleva bien con otros gatos y con perros tranquilos.',
  'images/mascotas/mandarina.jpg', true, null, 'aprobada', 'adoptada', now() - interval '42 days' - interval '103 minutes'),
('de000000-0000-4000-9000-000000000020', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Tigre', 'gato', 'mediano', '4 años',
  'Tigre es un gato fuerte y cariñoso que llegó al rescate con una pata lastimada; ya está totalmente recuperado.',
  'images/mascotas/tigre.jpg', true, null, 'aprobada', 'disponible', now() - interval '20 days' - interval '140 minutes'),
('de000000-0000-4000-9000-000000000021', 'de000000-0000-4000-8000-000000000003', 'Rescate Felino BC', 'Pecas', 'gato', 'pequeno', '3 meses',
  'Pecas es una gatita de tres meses, curiosa y juguetona. Se entrega con su primera vacuna y desparasitación.',
  'images/mascotas/pecas.jpg', true, 'Cachorro', 'aprobada', 'disponible', now() - interval '2 days' - interval '177 minutes'),
('de000000-0000-4000-9000-000000000022', 'de000000-0000-4000-8000-000000000006', 'Daniela Castro Rivera', 'Copito', 'perro', 'pequeno', '5 años',
  'Encontré a Copito en Playas de Tijuana sin collar. Nadie lo reclamó en un mes. Es tranquilo, educado y se lleva bien con gatos.',
  'images/mascotas/copito.jpg', true, null, 'aprobada', 'disponible', now() - interval '24 days' - interval '214 minutes'),
('de000000-0000-4000-9000-000000000023', 'de000000-0000-4000-8000-000000000006', 'Daniela Castro Rivera', 'Bigotes', 'gato', 'mediano', '2 años',
  'Bigotes apareció en mi cochera y se quedó. Lo llevé a esterilizar y vacunar; ahora busca un hogar definitivo.',
  'images/mascotas/bigotes.jpg', true, null, 'aprobada', 'disponible', now() - interval '16 days' - interval '251 minutes'),
('de000000-0000-4000-9000-000000000024', 'de000000-0000-4000-8000-000000000006', 'Daniela Castro Rivera', 'Nala', 'perro', 'pequeno', '1 año',
  'Nala es alegre y súper juguetona. La rescaté en la colonia Mariano Matamoros; ya está vacunada y lista para adopción.',
  'images/mascotas/nala.jpg', true, 'Nuevo', 'pendiente', 'disponible', now() - interval '1 days' - interval '288 minutes'),
('de000000-0000-4000-9000-000000000025', 'de000000-0000-4000-8000-000000000007', 'Luis Fernando Ramírez', 'Güero', 'perro', 'grande', '1 año',
  'Güero vivía en un lote baldío en Otay. Es noble y obediente; necesita espacio y paseos largos todos los días.',
  'images/mascotas/guero.jpg', false, null, 'aprobada', 'disponible', now() - interval '19 days' - interval '325 minutes'),
('de000000-0000-4000-9000-000000000026', 'de000000-0000-4000-8000-000000000007', 'Luis Fernando Ramírez', 'Manchas', 'perro', 'mediano', '3 años',
  'Manchas es una perrita tranquila que se echa a tomar el sol todo el día. La rescaté atropellada; ya está recuperada.',
  'images/mascotas/manchas.jpg', false, null, 'pendiente', 'disponible', now() - interval '1 days' - interval '362 minutes'),
('de000000-0000-4000-9000-000000000027', 'de000000-0000-4000-8000-000000000008', 'Sofía Méndez Arce', 'Toffee', 'perro', 'grande', '5 meses',
  'Toffee es un cachorro dorado lleno de energía y amor. Necesita una familia con tiempo para educarlo y jugar con él.',
  'images/mascotas/toffee.jpg', false, 'Cachorro', 'aprobada', 'disponible', now() - interval '8 days' - interval '399 minutes'),
('de000000-0000-4000-9000-000000000028', 'de000000-0000-4000-8000-000000000008', 'Sofía Méndez Arce', 'Rizos', 'perro', 'pequeno', '2 años',
  'Rizos casi no suelta pelo y es perfecto para departamento. Es sociable y le encanta saludar a todos en el parque.',
  'images/mascotas/rizos.jpg', true, null, 'aprobada', 'adoptada', now() - interval '36 days' - interval '436 minutes'),
('de000000-0000-4000-9000-000000000029', 'de000000-0000-4000-8000-000000000008', 'Sofía Méndez Arce', 'Frida', 'perro', 'pequeno', '3 años',
  'Frida es una bulldog francés simpática y un poco terca. Ronca al dormir y es la reina del sillón.',
  'images/mascotas/frida.jpg', true, null, 'aprobada', 'disponible', now() - interval '11 days' - interval '473 minutes');

-- ---------- 4) Solicitudes de adopción ----------
insert into public.adoption_requests (pet_id, adopter_id, adopter_name, housing_type, other_pets, message, status, created_at) values
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000009', 'Carlos Martínez Peña', 'Casa con patio', 'No',
  'Tengo tiempo para él y mi casa es fresca. Siempre quise un bulldog y quiero darle una buena vida.', 'aceptada', now() - interval '40 days' - interval '261 minutes'),
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000013', 'Alejandro Vega Rosas', 'Departamento', 'No',
  'Me encantaron sus fotos, vivo solo y trabajo en casa.', 'rechazada', now() - interval '39 days' - interval '189 minutes'),
('de000000-0000-4000-9000-000000000019', 'de000000-0000-4000-8000-000000000010', 'Valeria Torres Luna', 'Departamento', 'Un gato de 5 años',
  'Mi gato es muy tranquilo y creo que una compañera juguetona le haría bien.', 'aceptada', now() - interval '35 days' - interval '462 minutes'),
('de000000-0000-4000-9000-000000000013', 'de000000-0000-4000-8000-000000000011', 'Diego Navarro Gil', 'Casa con patio', 'Una perrita mestiza de 3 años',
  'Salgo a correr todos los días y busco un compañero activo para mi perrita y para mí.', 'aceptada', now() - interval '30 days' - interval '92 minutes'),
('de000000-0000-4000-9000-000000000028', 'de000000-0000-4000-8000-000000000012', 'Fernanda Ortiz Camacho', 'Departamento', 'No',
  'Vivo en un departamento en Zona Río y busco un perro pequeño que no suelte mucho pelo.', 'aceptada', now() - interval '25 days' - interval '118 minutes'),
((select id from public.pets where name = 'Toby' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000014', 'Paola Jiménez Duarte', 'Departamento', 'No',
  'Toby es justo lo que buscaba: pequeño y tranquilo. Trabajo medio tiempo.', 'aceptada', now() - interval '46 days' - interval '436 minutes'),
('de000000-0000-4000-9000-000000000003', 'de000000-0000-4000-8000-000000000013', 'Alejandro Vega Rosas', 'Casa con patio', 'No',
  'Hago senderismo los fines de semana y me gustaría un perro que me acompañe.', 'pendiente', now() - interval '6 days' - interval '475 minutes'),
('de000000-0000-4000-9000-000000000004', 'de000000-0000-4000-8000-000000000015', 'Ricardo Flores Ayala', 'Casa con patio', 'Dos gatos',
  'Tenemos un patio grande y dos hijos de 8 y 11 años que lo cuidarían mucho.', 'pendiente', now() - interval '4 days' - interval '462 minutes'),
((select id from public.pets where name = 'Sol' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000015', 'Ricardo Flores Ayala', 'Casa con patio', 'Dos gatos',
  'Si no se puede con Mostaza, también nos encantaría Sol.', 'pendiente', now() - interval '4 days' - interval '215 minutes'),
('de000000-0000-4000-9000-000000000015', 'de000000-0000-4000-8000-000000000016', 'Ana Sofía Guerrero', 'Departamento', 'No',
  'Busco una gata tranquila para acompañarme; trabajo desde casa.', 'pendiente', now() - interval '3 days' - interval '306 minutes'),
('de000000-0000-4000-9000-000000000022', 'de000000-0000-4000-8000-000000000009', 'Carlos Martínez Peña', 'Casa con patio', 'Un bulldog de 5 años',
  'Quiero un compañero para Bruno, a quien adopté en PawCloud.', 'pendiente', now() - interval '2 days' - interval '267 minutes'),
('de000000-0000-4000-9000-000000000029', 'de000000-0000-4000-8000-000000000016', 'Ana Sofía Guerrero', 'Departamento', 'No',
  'Las bulldog francés me encantan, conozco sus cuidados.', 'rechazada', now() - interval '5 days' - interval '202 minutes'),
('de000000-0000-4000-9000-000000000008', 'de000000-0000-4000-8000-000000000010', 'Valeria Torres Luna', 'Departamento', 'Un gato y Mandarina',
  'Me gustaría darle un hogar tranquilo a un perrito senior.', 'pendiente', now() - interval '1 days' - interval '241 minutes'),
('de000000-0000-4000-9000-000000000027', 'de000000-0000-4000-8000-000000000013', 'Alejandro Vega Rosas', 'Casa con patio', 'No',
  'Tengo experiencia entrenando cachorros.', 'pendiente', now() - interval '1 days' - interval '7 minutes'),
((select id from public.pets where name = 'Mía' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000011', 'Diego Navarro Gil', 'Casa con patio', 'Max (labrador) y una perrita',
  'Queremos sumar una gatita a la familia; Max ya convive con gatos.', 'pendiente', now() - interval '7 days' - interval '345 minutes'),
('de000000-0000-4000-9000-000000000025', 'de000000-0000-4000-8000-000000000014', 'Paola Jiménez Duarte', 'Casa sin patio', 'Toby (pug)',
  'Me mudé a una casa más grande y quiero un hermano para Toby.', 'pendiente', now() - interval '2 days' - interval '280 minutes');

-- ---------- 5) Seguimiento posterior a la adopción ----------
insert into public.care_events (pet_id, adopter_id, kind, title, event_date, done, notes) values
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000009', 'cita', 'Primera revisión veterinaria', current_date + -33, true, 'Todo bien. Peso: 24 kg.'),
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000009', 'vacuna', 'Refuerzo de rabia', current_date + -19, true, 'Aplicada en Hospivet.'),
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000009', 'desparasitacion', 'Desparasitación interna', current_date + -5, false, 'Se me pasó, agendar esta semana.'),
('de000000-0000-4000-9000-000000000002', 'de000000-0000-4000-8000-000000000009', 'cita', 'Limpieza de pliegues y revisión de piel', current_date + 12, false, null),
('de000000-0000-4000-9000-000000000019', 'de000000-0000-4000-8000-000000000010', 'cita', 'Primera revisión veterinaria', current_date + -28, true, null),
('de000000-0000-4000-9000-000000000019', 'de000000-0000-4000-8000-000000000010', 'vacuna', 'Triple felina (refuerzo)', current_date + -14, true, 'Cartilla actualizada.'),
('de000000-0000-4000-9000-000000000019', 'de000000-0000-4000-8000-000000000010', 'esterilizacion', 'Esterilización', current_date + 9, false, 'Ayuno de 8 horas antes de la cirugía.'),
('de000000-0000-4000-9000-000000000013', 'de000000-0000-4000-8000-000000000011', 'cita', 'Primera revisión veterinaria', current_date + -24, true, 'Sano, 31 kg.'),
('de000000-0000-4000-9000-000000000013', 'de000000-0000-4000-8000-000000000011', 'vacuna', 'Vacuna múltiple anual', current_date + -10, true, null),
('de000000-0000-4000-9000-000000000013', 'de000000-0000-4000-8000-000000000011', 'desparasitacion', 'Desparasitación trimestral', current_date + 20, false, null),
('de000000-0000-4000-9000-000000000028', 'de000000-0000-4000-8000-000000000012', 'cita', 'Primera revisión veterinaria', current_date + -18, true, null),
('de000000-0000-4000-9000-000000000028', 'de000000-0000-4000-8000-000000000012', 'vacuna', 'Revisar cartilla de vacunación', current_date + -2, false, 'Llevar la cartilla que dio la rescatista.'),
('de000000-0000-4000-9000-000000000028', 'de000000-0000-4000-8000-000000000012', 'otro', 'Corte de pelo', current_date + 15, false, 'Estética canina en Zona Río.'),
((select id from public.pets where name = 'Toby' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000014', 'cita', 'Primera revisión veterinaria', current_date + -39, true, null),
((select id from public.pets where name = 'Toby' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000014', 'vacuna', 'Vacuna de rabia', current_date + -25, true, null),
((select id from public.pets where name = 'Toby' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000014', 'esterilizacion', 'Esterilización', current_date + -11, true, 'Recuperación sin complicaciones.'),
((select id from public.pets where name = 'Toby' and photo_url like 'images/%' and photo_url not like 'images/mascotas/%' limit 1), 'de000000-0000-4000-8000-000000000014', 'desparasitacion', 'Desparasitación', current_date + 30, false, null);

alter table public.pets enable trigger pets_guard;

commit;

-- ---------- Cuentas demo (contraseña: PawCloud2026) ----------
--   admin      coordinacion@pawcloud.test    Coordinación PawCloud
--   refugio    huellas@pawcloud.test    Mariana López Ibarra — Refugio Huellas de Tijuana
--   refugio    rescatefelino@pawcloud.test    Andrea Ruiz Beltrán — Rescate Felino BC
--   refugio    patitasfelices@pawcloud.test    Jorge Hernández Soto — Patitas Felices A.C.
--   refugio    albergueotay@pawcloud.test    Roberto Salas Medina — Albergue Canino Otay (sin verificar)
--   rescatista daniela.castro@pawcloud.test    Daniela Castro Rivera
--   rescatista luisf.ramirez@pawcloud.test    Luis Fernando Ramírez
--   rescatista sofia.mendez@pawcloud.test    Sofía Méndez Arce
--   adoptante  carlos.martinez@pawcloud.test    Carlos Martínez Peña
--   adoptante  valeria.torres@pawcloud.test    Valeria Torres Luna
--   adoptante  diego.navarro@pawcloud.test    Diego Navarro Gil
--   adoptante  fernanda.ortiz@pawcloud.test    Fernanda Ortiz Camacho
--   adoptante  alejandro.vega@pawcloud.test    Alejandro Vega Rosas
--   adoptante  paola.jimenez@pawcloud.test    Paola Jiménez Duarte
--   adoptante  ricardo.flores@pawcloud.test    Ricardo Flores Ayala
--   adoptante  anasofia.guerrero@pawcloud.test    Ana Sofía Guerrero
