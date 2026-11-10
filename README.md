# PawCloud

Plataforma web en la nube para la adopción responsable de mascotas en Tijuana. Es el proyecto final de **Diseño y Evaluación de Interfaces de Usuario Aplicando Cómputo en la Nube** y el objeto de estudio de **Taller de Investigación II** (TecNM, Instituto Tecnológico de Tijuana).

**Alumno:** Kevin Isaac Carretero Ocaña · No. de control 22211531 · Grupo SC8A

## Demo en vivo

https://benevolent-fairy-cf7335.netlify.app/

## Qué hace

- **Catálogo** de mascotas de refugios y rescatistas, con búsqueda y filtros por especie, tamaño y si se adapta a departamento.
- **Cuatro roles:** adoptante, rescatista, refugio (verificado por un administrador) y administrador, que además supervisa todas las solicitudes y responde las de mascotas sin responsable.
- **Adopción completa:** publicar, moderar, solicitar, aceptar o rechazar, y cancelar o retirar.
- **Seguimiento posterior a la adopción:** el adoptante registra vacunas, desparasitación, esterilización y citas de su mascota, con estados (hecho, próximo, vencido) y un plan básico sugerido. El refugio ve cuántos cuidados lleva cada mascota que dio en adopción.
- **Mapa "Ayuda cerca de ti"** con 20 veterinarias, refugios y centros de ayuda reales de Tijuana, administrable desde el panel del admin.

## Stack

| Capa | Tecnología |
| --- | --- |
| Frontend | HTML, CSS y JavaScript sin framework (`index.html`) |
| Backend | Supabase: PostgreSQL con RLS, autenticación y Storage |
| Mapa | Leaflet 1.9.4 + OpenStreetMap / Nominatim |
| Hosting | Netlify (CDN, vista previa por pull request, producción desde `main`) |
| CI | GitHub Actions (`.github/workflows/main.yml`) |

## Base de datos

- `supabase/schema.sql`: esquema completo (borra y recrea las tablas; solo para un proyecto nuevo).
- `supabase/migracion_v5.sql` y `supabase/migracion_v6_seguimiento.sql`: cambios incrementales que **no** borran datos.
- `supabase/datos_demo.sql`: datos de demostración para ver la plataforma en uso (ver abajo).

### Datos de demostración

`supabase/datos_demo.sql` carga 16 cuentas, 29 mascotas nuevas con fotos reales (`images/mascotas/`), solicitudes en todos los estados y seguimiento de cuatro adopciones. Se corre en el SQL Editor después del esquema; se puede repetir y no toca cuentas reales (solo las de `@pawcloud.test`). Las personas, los refugios y las historias son ficticios; los créditos de las fotos están en `images/mascotas/CREDITOS.md`.

Contraseña de todas las cuentas demo: `PawCloud2026`

| Rol | Correo | Para ver |
| --- | --- | --- |
| Admin | `coordinacion@pawcloud.test` | Refugio por verificar, 2 publicaciones por moderar, todas las solicitudes |
| Refugio | `huellas@pawcloud.test` | Refugio Huellas de Tijuana: 11 mascotas, solicitudes pendientes, seguimiento de Bruno |
| Refugio | `rescatefelino@pawcloud.test` | Rescate Felino BC: 11 gatos |
| Refugio | `patitasfelices@pawcloud.test` | Patitas Felices A.C.: 9 perros |
| Refugio | `albergueotay@pawcloud.test` | Albergue Canino Otay, aún sin verificar |
| Rescatista | `daniela.castro@pawcloud.test` | Publicaciones aprobadas y una en revisión |
| Adoptante | `carlos.martinez@pawcloud.test` | Adoptó a Bruno: seguimiento con un cuidado vencido |
| Adoptante | `paola.jimenez@pawcloud.test` | Adoptó a Toby: seguimiento casi completo |
| Adoptante | `alejandro.vega@pawcloud.test` | Solicitudes pendientes y una rechazada |

Otras cuentas: `luisf.ramirez`, `sofia.mendez` (rescatistas); `valeria.torres`, `diego.navarro`, `fernanda.ortiz`, `ricardo.flores`, `anasofia.guerrero` (adoptantes).

## Integración continua

Cada push a `main` y cada pull request ejecutan:

1. Validación de HTML (`npm run lint`).
2. 32 pruebas de flujo (`npm test`) con jsdom y un simulador de la base de datos con las mismas reglas que Supabase.
3. Lighthouse CI (rendimiento, accesibilidad, buenas prácticas y SEO).

En local: `npm install`, `npm run lint` y `npm test`.

## Estado

- [x] Investigación de usuarios, prototipo y encuesta de diseño (86 respuestas)
- [x] Registro e inicio de sesión reales con cuatro roles
- [x] Moderación de publicaciones y verificación de refugios
- [x] Mapa de ayuda con 20 lugares reales
- [x] Evaluación heurística y correcciones
- [x] Pantalla de inicio
- [x] Seguimiento posterior a la adopción (vacunas y citas)
- [x] CI con validación, pruebas y Lighthouse; despliegue continuo en Netlify
