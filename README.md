# PawCloud

Plataforma de adopción y cuidado de mascotas en la nube — proyecto final de la materia **Diseño y Evaluación de Interfaces de Usuario Aplicando Cómputo en la Nube** (TecNM, Instituto Tecnológico de Tijuana).

**Alumno:** Kevin Isaac Carretero Ocaña — No. Control 22211531
**Grupo:** SC8A · **Clave:** SCD-2503
**Docente:** Miguel Ángel López Ramírez

## Descripción

PawCloud centraliza el catálogo de mascotas en adopción de refugios y rescatistas, permite filtrar por especie, tamaño y compatibilidad, gestiona solicitudes de adopción con cuentas verificadas, y da seguimiento post-adopción (vacunas y citas veterinarias).

## Demo en vivo

👉 https://benevolent-fairy-cf7335.netlify.app/

## Stack

- HTML, CSS y JavaScript (sin framework)
- Hospedado en Netlify (CDN automático, desplegado desde este repositorio)
- Integración continua con GitHub Actions
- Próximo: base de datos y autenticación real con Supabase

## Pipeline de integración continua

Cada push a `main` y cada pull request ejecutan `.github/workflows/ci.yml`:

1. **Validación de HTML** (`npm run lint`, con html-validate).
2. **Pruebas de flujo** (`npm test`): catálogo, filtros, acceso como invitado, registro de adoptante y refugio, e inicio de sesión.
3. **Lighthouse CI**: mide rendimiento, accesibilidad, buenas prácticas y SEO (umbrales configurados en `lighthouserc.json`).

Netlify genera además una vista previa pública (staging) por cada pull request y publica en producción al integrar a `main`.

Para correrlo en local: `npm install`, `npm run lint` y `npm test`.

## Estado del proyecto

- [x] Investigación de usuarios (personas, escenarios, benchmarking)
- [x] Prototipo interactivo de alta fidelidad
- [x] Encuesta de evaluación de diseño (86 respuestas)
- [x] Registro e inicio de sesión con roles (adoptante / refugio), simulado en el navegador
- [x] Código versionado en GitHub con despliegue continuo (Netlify)
- [x] Validación automática, pruebas de flujo y Lighthouse en CI
- [ ] Base de datos real y autenticación con Supabase
- [ ] Rol de administrador (supervisión de refugios y verificaciones)
- [ ] Panel de publicación de mascotas y mapa de centros de ayuda y veterinarios
- [ ] Evaluación heurística formal
- [ ] Pruebas con usuarios dirigidas
- [ ] Pantalla de inicio
