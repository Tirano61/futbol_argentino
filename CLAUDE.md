# CLAUDE.md — Fútbol Argentino

App Flutter (Android + Web) de uso personal para consultar partidos del fútbol argentino con datos de TheSportsDB. Sin login, sin backend propio, sin servicios pagos.

## Documentación
- `docs/PLAN.md` — plan maestro v2 y roadmap por fases/tareas (fuente de verdad).
- `docs/ARCHITECTURE.md` — estructura DDD, modelo de dominio, pantallas, BLoC.
- `docs/API.md` — endpoints verificados, topes de la clave gratuita, hallazgos de datos.
- `docs/DATA_STRATEGY.md` — carga por rondas, TTL, merge, sincronización incremental.
- `docs/DECISIONS.md` — decisiones y alternativas.

## Forma de trabajo
- Se trabaja **por fases**. Dentro de una fase se avanza tarea por tarea; **al terminar cada fase**: validar, informar, actualizar docs y **esperar aprobación** antes de la siguiente.
- No implementar nada fuera del alcance de la fase actual. No avanzar si falla una validación crítica.
- Cada tarea termina con `flutter analyze` sin issues y sus tests verdes.
- Probar UI en la tablet Android (`SOP10X2501001122`, SKY PAD10MAX) y en Chrome.
- **Nunca** datos simulados presentados como reales. Los tests usan JSON reales de `test/fixtures/api/` (no editarlos a mano).
- No implementar proxies ni servicios externos sin aprobación.

## Convenciones de código
- DDD por features (`lib/features/<feature>/{data,domain,presentation}`), `lib/core`, `lib/shared`, `lib/app`.
- `flutter_bloc` con `Bloc` y events/states `sealed`. **Prohibido `Cubit`.**
- `domain/` es Dart puro: sin imports de `flutter`, `http` ni `sembast`.
- Sin HTTP en widgets, sin lógica de negocio en presentation, sin DTO/JSON en pantallas.
- El parsing de JSON vive en los DTO (`fromJson`); mappers DTO → entidad.
- Repositorios devuelven `DataResult<T>` / `Stream<DataResult<T>>` y traducen errores a `Failure`.
- DI: composition root manual (`lib/app/di/app_dependencies.dart`) + `RepositoryProvider`. Sin `get_it`.
- Textos de UI en español rioplatense. Evitar sobreingeniería.

## Datos clave de TheSportsDB
- Base: `https://www.thesportsdb.com/api/v1/json/123/` (clave en `--dart-define=TSDB_API_KEY`, por defecto `123`).
- Ligas: Primera División `4406`, Primera Nacional `4616`, Copa Argentina `4500`.
- Límite: 30 peticiones/minuto (HTTP 429). Sin paginación. Fuente principal: `eventsround.php?id=&r=&s=`.
- Primera: cada `r` (1..16) trae **Apertura y Clausura juntos**; `r=0` = eliminatorias; `r=16` incluye octavos. La fase se resuelve con el catálogo por temporada (`PhaseResolver`); si no hay evidencia → `undetermined`.
- Copa: rondas `64, 32, 16, 125 (cuartos), 150 (semis), 200 (final, sin validar)`.
- Identificadores: `idEvent` (partidos, deduplicación), `idTeam` (equipos), `idLeague`.

## Escudos
- Siempre mediante `TeamBadge`, con `Image.network(..., webHtmlElementStrategy: WebHtmlElementStrategy.fallback)`: `r2.thesportsdb.com` no envía CORS y en Web la carga normal falla (validado en T0.2).
- Variantes de tamaño: `/tiny` (listas), `/small` (fichas).

## Horarios
- Mostrar siempre en `America/Argentina/Buenos_Aires` = UTC−3 fijo. Nunca usar la zona del dispositivo.
- `strTimestamp` es UTC sin zona. `strTimeLocal` no es fuente (es inconsistente).
- Hora `00:00` UTC sin corroboración → «Horario por confirmar» (regla conservadora D5).
- Formatos: fecha `dd/MM/yyyy`, hora `HH:mm`.

## Mantenimiento periódico
- Cada semestre: cargar en `CompetitionCatalog` las ventanas de fase de Primera de la temporada (desde datos reales).
- Revisar los pendientes V2–V7 de `docs/API.md` cuando haya datos nuevos.

## Comandos
- `flutter analyze` · `flutter test`
- `flutter run -d SOP10X2501001122` (tablet) · `flutter run -d chrome`
- Web release con diagnóstico: `flutter build web --dart-define=DIAGNOSTICS=true`; probar en la tablet con `adb reverse tcp:8080 tcp:8080` y `http://localhost:8080/`.
- La pantalla de diagnóstico está en `/diagnostico` (botón 🐞 en Inicio, solo en debug o con `DIAGNOSTICS=true`).

## Contrato de red y errores
- Todo HTTP pasa por `TheSportsDbClient.getJson` (rate limiter 25/min, timeout 15 s, reintentos solo transitorios).
- Data lanza `ApiException`; los repositorios lo convierten con `toFailure()`. Presentation solo ve `Failure` y `DataResult`.
- Los tests de red usan `MockClient` + `FakeClock` (`test/helpers/`) y JSON reales de `test/fixtures/api/`.
