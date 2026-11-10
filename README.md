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
