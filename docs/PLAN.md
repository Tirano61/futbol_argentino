# Fútbol Argentino — Plan Maestro · v2 (aprobado 11/10/2026)

> v2 incorpora la revisión del 11/10/2026: horario conservador (D5), fases sin forzar (D6), sincronización incremental cancelable (D9), política de merge (§5.3), T0.3 como validación obligatoria y MVP en hitos.

## Contexto

El proyecto `futbol_argentino` (Flutter 3.41.6, Dart ^3.11.4) ya tiene una **prueba técnica funcional (Prompt 1)**: consulta `eventsround.php?id=4616&r=33&s=2026` con `http` + `flutter_bloc`, muestra HTTP, tiempo, cantidad, JSON y error real. Funcionó el 11/10/2026 en Android (tablet SKY PAD10MAX) y en Flutter Web/Chrome.

El objetivo es convertir esa prueba en una app completa (Inicio, Competiciones, Equipos, Detalle de partido, Favoritos) con arquitectura DDD por features, caché offline y datos 100 % de TheSportsDB (clave gratuita `123`), desarrollada **una tarea por vez**.

Código existente a reutilizar (se reubica, no se descarta):

| Archivo actual | Destino | Qué se reutiliza |
|---|---|---|
| `lib/data/services/thesportsdb_service.dart` | `lib/core/network/thesportsdb_client.dart` | timeout, manejo de `ClientException`/CORS en Web, medición de tiempo |
| `lib/data/repositories/match_repository_impl.dart` | `core/network/json_envelope.dart` + data sources | validación de JSON raíz, `"events": null` → lista vacía, errores de formato |
| `lib/data/models/event_model.dart` (`parseUtcTimestamp`) | `features/matches/data/models/event_dto.dart` + `core/time/` | parsing tolerante de timestamp UTC |
| `lib/presentation/utils/argentina_time.dart` | `lib/core/time/argentina_time.dart` (Dart puro) | conversión UTC→UTC−3 y formato `dd/MM/yyyy` / `HH:mm` |
| `lib/domain/errors/api_failure.dart` | `core/network/api_exception.dart` (data) + `core/error/failure.dart` (dominio) | tipos de error |
| `ApiTestPage` / `ApiTestBloc` | `features/diagnostics/` (solo debug) | herramienta de prueba técnica |

---

## 1. Resumen de la aplicación

App personal, gratuita, sin login ni backend, para Android y Web (escritorio y móvil). Muestra partidos de **Primera División (4406)**, **Primera Nacional (4616)** y **Copa Argentina (4500, verificada)** con fechas y horarios en `America/Argentina/Buenos_Aires`, resultados, estados, escudos, búsqueda de equipos, ficha multi-competición, favoritos locales y caché offline. Agregar una competición = agregar una entrada al catálogo.

---

## 2. Investigación de TheSportsDB (verificada el 11/10/2026 con la clave `123`)

### 2.1 Límites oficiales y comprobados
- **30 peticiones/minuto** (gratuita); al superarlo → **HTTP 429** y espera de 1 minuto.
- **Sin livescore** en la gratuita (v2 es premium). Aun así `eventsround` devolvió estados en juego (`1H`, `HT`, `2H`) en Primera Nacional fecha 33 → se muestran, sin garantía de frescura.
- **Sin paginación** (`page`/`limit`) en v1. No se inventa.
- **CORS de la API: resuelto.** Las respuestas JSON envían `Access-Control-Allow-Origin: *`; el usuario ya lo probó en Chrome.
- **CORS de imágenes: riesgo abierto.** `r2.thesportsdb.com` **no envía** `Access-Control-Allow-Origin`. En Flutter Web (CanvasKit/skwasm) `Image.network` puede fallar. Candidato sin proxy: `webHtmlElementStrategy: WebHtmlElementStrategy.fallback`. **Validado en T0.2: la carga normal falla en Web y el fallback `<img>` funciona.**
- Variantes de imagen: `/tiny` (50 px, ~8 KB), `/small` (250 px), `/medium` (500 px). `/tiny` y `/small` verificadas.
- Caché CDN: `lookupleague`/`lookupteam` con `max-age=14400` (4 h). `eventsround`, `eventsnextleague`, `eventspastleague`, `lookupevent` → `DYNAMIC` (frescos).

### 2.2 Endpoints confirmados y útiles

| Endpoint | Tope gratuito | Observado | Uso |
|---|---|---|---|
| `eventsround.php?id=&r=&s=` | **sin tope observado** (30–38) | base del fixture | **Fuente principal** |
| `lookupleague.php?id=` | 1 | 4406, 4616, **4500 "Copa Argentina"**; `strCurrentSeason=2026`; `strBadge` | metadatos |
| `eventsnextleague.php?id=` | **1** | próximo evento con `intRound` | descubrir ronda actual |
| `eventspastleague.php?id=` | **1** | último evento con `intRound` | descubrir última ronda jugada |
| `lookupevent.php?id=` | 1 | evento completo (`strVenue`, `strThumb`, `strVideo`) | detalle, verificaciones |
| `lookupteam.php?id=` | 1 | `strStadium`, `strBadge`, `idLeague..idLeague7` | ficha de equipo |
| `searchteams.php?t=` | **1** | "River Plate" OK; "River" → River-PI (Brasil); "Boca" → Boca Unidos | respaldo de búsqueda |
| `search_all_leagues.php?c=Argentina` | 10 | así se encontró Copa Argentina = 4500 | investigación |
| `eventsnext.php` / `eventslast.php?id={idTeam}` | **1, solo de local** | Boca → Sudamericana (4724) | complemento post-MVP |

### 2.3 Confirmados pero no aptos con clave gratuita
`eventsseason` (tope 15) · `eventsday` (tope 3) · `search_all_seasons` (tope 5, devuelve las más antiguas) · `search_all_teams` (tope 10) · `lookup_all_teams` (dataset fijo incorrecto: equipos ingleses) · `lookuptable` (5 filas) · `lookupeventstats` / `lookuptimeline` / `lookuplineup` (5 filas).

### 2.4 Estructura real de los datos
**Primera División (4406)**
- `eventsround r=1..16, s=2026` → **30 eventos: 15 del Apertura (ene–may) + 15 del Clausura (jul–dic)**; `strGroup` vacío → la fase no viene en el dato.
- `r=16` → **38**: 15 regulares Apertura (abr) + **8 octavos Apertura (may)** + 15 regulares Clausura (nov).
- `r=0` → **7**: cuartos, semis y final del Apertura (`AET`, `PEN`).
- `r=17`, `32`, `125`, `150`, `160`, `170`, `200` → vacíos. 2025 tiene la misma mezcla.

**Primera Nacional (4616)**: 18 partidos por ronda, sin zonas en eventos; `r=38` vacío; Reducido pendiente.

**Copa Argentina (4500)**: códigos `64` (32 p.), `32` (16), `16` (8), `125` (4), `150` (2), `200` (vacío aún). `PEN` sin goles de penales ni ganador.

**Horarios**: `strTimestamp` UTC sin zona (preferido) · `dateEvent`+`strTime` UTC (a veces `HH:mm`) · `strTimeLocal` inconsistente (20:45 UTC → `18:00`; vacío o null) · `dateEventLocal` = fecha local · varios `00:00:00` ambiguos.

**Estados observados**: `NS`, `1H`, `HT`, `2H`, `FT`, `AET`, `PEN`; `strPostponed: "no"`.

### 2.5 Pendientes de validación

| # | Tema | Cómo |
|---|---|---|
| V1 | Escudos en Flutter Web | ✅ **Resuelto en T0.2 (11/10/2026)**: carga normal bloqueada por CORS en Web; `webHtmlElementStrategy.fallback` funciona (ver «Resultado T0.2») |
| V2 | Código de la final de Copa (¿200?) | ✅ Resuelto: 200 = Final (final 2025) |
| V3 | Reducido de Nacional / playoffs del Clausura | nov–dic 2026 |
| V4 | Estados no observados (`PST`, `CANC`, `ABD`…) | log de estados desconocidos en debug |
| V5 | Significado de `00:00:00` UTC | regla conservadora D5 mientras tanto |
| V6 | Ausencia de tope en `eventsround` | clasificación de calidad de respuesta (§5.3) |
| V7 | Cantidad de rondas de Nacional 2026 | ✅ Resuelto (11/10/2026): 36 fechas (r=37 vacía) |

---

## 3. Arquitectura DDD

### 3.1 Features y cómo evitar duplicación
- **`matches` es el núcleo**: dueño de `Match`, `TeamRef`, `MatchStatus`, `Kickoff`, del DTO de evento, del store local de eventos y de `MatchRepository`. Todos consultan partidos por ese repositorio → un parser, una tabla de eventos deduplicada por `idEvent`.
- **`fixtures` vive dentro de `competitions`** (un fixture = partidos de competición/temporada/fase/ronda).
- **`teams`**: `Team`, índice de búsqueda y ficha; usa `MatchRepository`.
- **`favorites`**: solo `idTeam` + snapshot (nombre, escudo).
- **`home`**: compone casos de uso de otras features, sin datos propios.
- Dependencias: `home → competitions, matches, favorites`; `teams → matches`; `competitions → matches`; `matches → core`. Nunca al revés.

### 3.2 Estructura de directorios
```
lib/
  main.dart                          # abre DB, crea AppDependencies, runApp
  app/
    app.dart                         # MaterialApp.router, temas, es_AR
    di/app_dependencies.dart         # composition root
    router/app_router.dart           # go_router + StatefulShellRoute
    shell/adaptive_shell.dart        # NavigationBar / NavigationRail
    theme/app_theme.dart
  core/
    config/app_config.dart           # baseUrl, apiKey (--dart-define, default 123)
    network/{thesportsdb_client, rate_limiter, api_exception, json_envelope}.dart
    storage/local_database.dart      # sembast io / web
    cache/{cache_policy, query_metadata_store}.dart
    sync/{sync_scheduler, sync_job, cancel_token}.dart
    time/{clock, argentina_time}.dart
    error/failure.dart
    result/data_result.dart
    text/text_normalizer.dart        # sin acentos, reparación de mojibake
  shared/presentation/widgets/       # §6.3
  features/
    matches/
      domain/entities/{match, team_ref, match_status, kickoff, score}.dart
      domain/services/{kickoff_resolver, match_status_mapper, round_merge_policy, match_grouping}.dart
      domain/repositories/match_repository.dart
      domain/usecases/{watch_stage_matches, get_match_detail, watch_team_matches, watch_matches_in_window}.dart
      data/models/event_dto.dart
      data/mappers/event_mapper.dart
      data/datasources/{match_remote_data_source, match_local_data_source}.dart
      data/repositories/match_repository_impl.dart
      presentation/{bloc/match_detail_*, pages/match_detail_page}.dart
    competitions/
      domain/entities/{competition, season, phase, phase_assignment, stage}.dart
      domain/catalog/competition_catalog.dart
      domain/services/{phase_resolver, stage_labeler, round_navigator}.dart
      domain/repositories/competition_repository.dart
      domain/usecases/{get_competitions, resolve_current_stage, list_stages}.dart
      data/{models/league_dto, datasources/competition_remote_data_source, repositories/competition_repository_impl}.dart
      presentation/bloc/competition_fixture_*.dart
      presentation/pages/competitions_page.dart
      presentation/widgets/{competition_selector, season_selector, phase_selector, stage_navigator}.dart
    teams/        domain (team, team_repository, search_teams, get_team) · data (team_dto, datasources, repo) · presentation (team_search_*, team_detail_*)
    favorites/    domain (favorite_team, repo, watch/toggle) · data (local ds, repo) · presentation (favorites_bloc global, favorites_page, favorite_button)
    home/         domain/usecases/get_home_feed.dart · presentation (home_bloc, home_page, secciones)
    diagnostics/  prueba técnica (solo kDebugMode)
test/
  fixtures/api/                      # JSON REALES grabados de la API
  core/ features/ ...
```

### 3.3 Convenciones (irán a `CLAUDE.md`)
- `Bloc` + events/states sealed. **Prohibido `Cubit`.**
- Sin HTTP en widgets; sin lógica de negocio en presentation; las pantallas solo ven entidades.
- `domain/` es Dart puro (sin `flutter`, `http`, `sembast`).
- Parsing en DTO (`fromJson`); mappers DTO → entidad.
- Repositorios devuelven `DataResult<T>` o `Stream<DataResult<T>>`; traducen errores a `Failure`.
- Casos de uso solo cuando hay lógica o composición.
- UI en español rioplatense. `flutter analyze` limpio antes de cerrar cada tarea.
- **Nunca datos simulados presentados como reales.**

### 3.4 Dependencias
`http`, `flutter_bloc` (ya están) · `bloc_concurrency` · `stream_transform` · `equatable` · `go_router` · `sembast` + `sembast_web` · `path_provider` + `path` · `intl` + `flutter_localizations` · dev: `bloc_test`, `mocktail`. Versiones estables vigentes al instalar. Sin `get_it`, sin `dartz`, sin codegen. Cada paquete se agrega en la tarea que lo necesita (no todos de una vez).

---

## 4. Modelo de dominio

- **`Competition`** `{id (idLeague), name, shortName, format: league|cup, badgeUrl?, currentSeason}`
- **`Season`** `{"2026"}` (formato `YYYY`)
- **`Phase`** `{key: apertura|clausura|regular|unica|undetermined, label, kind: regular|knockout}`
- **`PhaseAssignment`** `{phaseKey, stageKind, source: catalog|inferred|undetermined}` — por partido, nunca forzada.
- **`Stage`** `{competitionId, season, phaseKey, apiRound, kind, label ("Fecha 12", "Octavos de final"…), order}`
- **`TeamRef`** `{id (idTeam), name, badgeUrl?}` · **`Team`** `{id, name, alternateNames, badgeUrl?, stadium?, leagueIds}`
- **`Kickoff`** `{utc?, argentinaDay?, certainty: confirmed|tentative|unknown, evidence}`
- **`MatchStatus`** `{kind: scheduled|live|halfTime|finished|postponed|cancelled|abandoned|suspended|unknown, decidedBy: regular|extraTime|penalties, raw}`
- **`Match`** `{id (idEvent), competitionId, competitionName, season, apiRound, phase: PhaseAssignment, home, away, kickoff, status, score?, venue?, thumbUrl?, videoUrl?, previousKickoffUtc?, previousApiRound?, membership: active|unconfirmed|orphaned|removed, lastSeenAt}`
- **`FavoriteTeam`** `{teamId, name, badgeUrl?, addedAt}`
- **`DataResult<T>`** `{data, origin: remote|cache, fetchedAt, refreshError?}` · **`Failure`** sealed: `Network`, `RateLimit`, `Server(status)`, `Format`, `NotFound`.

### Reglas de negocio (Dart puro, con tests sobre JSON reales)

1. **Hora argentina**: UTC−3 fijo encapsulado en `ArgentinaTime` (Argentina sin horario de verano desde 2009); cambiar al paquete `timezone` afectaría un solo archivo.

2. **Kickoff — regla conservadora (D5)**, `KickoffResolver`:
   - Instante candidato: `strTimestamp`; si falta, `dateEvent` + `strTime` (UTC, `HH:mm` o `HH:mm:ss`). `strTimeLocal` **nunca** es fuente; solo sirve para corroborar.
   - **`confirmed`**: instante candidato con hora UTC distinta de `00:00` (ej. `20:45` → 17:45 ART).
   - **`confirmed` por corroboración**: hora `00:00` UTC **y** `strTimeLocal == "21:00"` (coincide con la conversión a ART).
   - **`tentative`**: hora `00:00` UTC sin corroboración (caso real: `2026-03-21T00:00:00` con `strTimeLocal = 18:00`). Se muestra **«Horario por confirmar»**; el detalle aclara «La API informa 00:00 UTC, sin confirmar».
   - **`unknown`**: sin hora → «Horario por confirmar»; sin fecha → «Fecha por confirmar».
   - **Día argentino**: `confirmed` → día de `utc − 3 h`; `tentative`/`unknown` → `dateEventLocal ?? dateEvent` (no se resta 3 h a una hora dudosa, así el partido no salta al día anterior).
   - Orden en el día: primero `confirmed` por hora, luego los no confirmados.
   - Se re-evalúa en cada actualización; un `tentative` pasa a `confirmed` apenas llega una hora distinta de `00:00`.

3. **Estado**: tabla `strStatus` + `strPostponed`. `NS` con inicio `confirmed` hace más de 3 h → «Resultado pendiente de actualización». Estados desconocidos → se muestra el código crudo y se registra (V4).

4. **Fase (D6)**, `PhaseResolver`, con fuente explícita:
   - **Catálogo por temporada** (fuente principal): para Primera, cada temporada declara ventanas en fecha argentina `{phaseKey, regularDesde, regularHasta, eliminatoriasDesde?, eliminatoriasHasta?}` **cargadas desde datos reales grabados**, no por división fija de meses. Un partido se asigna si su día cae en **exactamente una** ventana → `source: catalog`.
   - **Inferencia** (solo temporadas sin catálogo): la ronda tiene **exactamente dos** grupos de fechas separados por ≥ 45 días y cada uno ≤ 15 partidos → Apertura/Clausura con `source: inferred` (indicado en la UI).
   - **Sin evidencia suficiente** (fuera de toda ventana, en dos ventanas, grupos ambiguos, día desconocido) → **`undetermined`**: no se ubica en Apertura ni Clausura; se ve en la opción «Sin fase determinada» y en la ficha del equipo; se registra en debug.
   - **Consistencia**: en una fecha regular de una fase cada equipo juega una vez; si aparece dos veces, el partido posterior solo puede ser eliminatoria si cae en la ventana de eliminatorias; si no → `undetermined`.
   - Eliminatorias de Primera: `r=0` → knockout de la fase cuya ventana de eliminatorias lo contiene; `r=16` dentro de esa ventana → «Octavos de final».
   - *Nacional*: fase «regular» sin zonas (D7). *Copa*: knockout; `64→32avos, 32→16avos, 16→Octavos, 125→Cuartos, 150→Semifinales, 200→Final (V2)`; desconocido → «Ronda {n}».

5. **Merge y deduplicación**: §5.3.
6. **Agrupación**: por día argentino, luego hora (regla 2); desempate por `idEvent`.
7. **Partidos de equipo**: `idHomeTeam == id || idAwayTeam == id`, todas las competiciones, excluyendo `removed`.

---

## 5. Integración y estrategia de datos

### 5.1 Unidad de carga: la ronda
Sin paginación, la unidad incremental es **(competición, temporada, `apiRound`)** = 1 petición. La ronda trae ambas fases; se descarga una vez y **se filtra por fase localmente** → nunca se mezclan en pantalla y la otra fase queda en caché.

| Necesidad | Peticiones |
|---|---|
| Ronda actual de una competición | 2 (`eventsnextleague` + `eventspastleague`) |
| Ver una fecha/ronda | 1 |
| Temporada completa: Primera / Copa / Nacional | ~17 / 6 / ~35–38 |
| Índice de equipos inicial | 3 (Primera r=1, Nacional r=1, Copa r=64) |
| Inicio en frío | ≤ 12 |

### 5.2 Navegación anterior/siguiente
`RoundNavigator` arma la lista de `Stage` de la fase: liga → `1..maxRound` (catálogo o descubierto) + eliminatorias; copa → lista de códigos. Solo se carga la etapa pedida (+ prefetch P1 de la vecina).

### 5.3 Política de merge (`RoundMergePolicy`, Dart puro)
`query_meta` por ronda guarda `lastCompleteIds`, `fetchedAt`, `quality`. Cada evento guarda `apiRound`, `previousApiRound?`, `membership`, `lastSeenAt`.

**Clasificación de la respuesta**

| Calidad | Condición | Efecto |
|---|---|---|
| `complete` | cantidad ≥ esperada del catálogo (Primera 15 por fase presente; Nacional 18) **o** ≥ `lastCompleteIds` | altas, cambios **y bajas** |
| `partial` | 0 < cantidad < anterior y < esperada | altas y cambios, **sin bajas**; reintento en 15 min |
| `suspectEmpty` | `events: null` habiendo datos previos | no se toca nada; reintento en 15 min; log |
| `empty` | `events: null` sin datos previos | ronda vacía |

**Por evento**
- Presente → upsert; si cambia `intRound` → `previousApiRound`; si cambia el instante → `previousKickoffUtc` («Reprogramado»); `membership = active`.
- El payload indica otra ronda que la consultada → manda el payload.
- Ausente en respuesta `complete` → `orphaned` (deja de verse en esa fecha, se conserva para historial) + verificación P3 con `lookupevent`: con otra ronda/fecha → actualizado y `active`; igual → `unconfirmed` (visible con aviso); inexistente → `removed` (oculto, se purga a 30 días).
- Ausente en `partial`/`suspectEmpty` → sin cambios.
- `orphaned` sin verificar > 7 días → se reintenta la verificación; ninguna asociación obsoleta queda indefinidamente.

**Por campo**: un resultado no nulo no se pisa con nulo si el estado sigue final (sí si pasa a `NS`/`PST`/`CANC`); un kickoff `confirmed` no se degrada a `tentative` del mismo instante; vacío no pisa escudo/estadio; nombres sin mojibake tienen prioridad.

### 5.4 Persistencia (sembast)
Stores: `events` (key `idEvent`), `teams`, `competitions`, `query_meta` (`"round:4406:2026:12"`, `"next:4406"`…), `favorites`, `settings`. ~1.200 eventos/temporada ≈ 0,6 MB.

### 5.5 TTL por consulta

| Clase | Condición | TTL |
|---|---|---|
| `live` | partido en juego o iniciado hace < 3 h sin final | 2 min |
| `today` | partido hoy (día argentino) | 10 min |
| `upcoming` | `NS` en los próximos 7 días | 1 h |
| `future` | solo partidos a > 7 días | 12 h |
| `closed` | todos finalizados/cancelados y el último hace > 48 h | 30 días |
| `partial` / `suspectEmpty` | §5.3 | 15 min |
| `empty` | ronda sin eventos | 24 h |
| next/past league | — | 30 min |
| equipo / competición | — | 7 días |

Flujo stale-while-revalidate: caché inmediata → si vencida, red → upsert y nueva emisión → si falla, caché + `refreshError`. Refresco manual ignora TTL (mínimo 30 s por clave).

### 5.6 Cliente HTTP
`getJson(endpoint, params)`: base + clave desde `AppConfig`; timeout 15 s; `RateLimiter` 25/min con cola y pausa 60 s ante 429; reintentos (1 s, 3 s + jitter, máx. 2) **solo** para timeout, conexión y 5xx; `ApiException` tipada; log de URL/status/tiempo en debug.

### 5.7 Búsqueda de equipos
Índice local de `TeamRef` derivado de los eventos guardados (3 peticiones cubren Primera, Nacional y Copa), normalizado sin acentos, por subcadena ("river" → River Plate; "gimnasia" → las tres). Sin resultados locales y ≥ 3 letras → respaldo `searchteams` filtrado a Argentina.

### 5.8 Sincronización incremental (D9) — `SyncScheduler`
Un planificador único en `core/sync/` que ejecuta **trabajos de una petición** por prioridad. Nunca bloquea: las pantallas muestran caché al instante y se actualizan por `Stream` a medida que llega cada ronda.

| Prioridad | Qué | Cuándo |
|---|---|---|
| P0 Visible | ronda/partido en pantalla, refresco manual | inmediato |
| P1 Contexto | ronda actual/anterior de cada competición (Inicio), prefetch de etapa vecina | al abrir pantallas |
| P2 Equipo | rondas de la temporada actual de las competiciones del equipo abierto | al abrir la ficha |
| P3 Historial | rondas `closed` faltantes, verificaciones `orphaned`, temporada anterior | en reposo |

- **Incremental y reanudable**: el progreso es `query_meta`; tras reiniciar solo se piden rondas faltantes o vencidas; `closed` no se repite salvo refresco manual.
- **Sin repeticiones**: trabajos deduplicados por clave; peticiones en vuelo compartidas.
- **Cancelable**: `CancelToken` por dueño (BLoC/pantalla); salir de la ficha cancela sus P2; app en segundo plano pausa la cola; P0 se adelanta a todo.
- **Rate limiter**: tope global 25/min; P2+P3 ≤ 10/min para reservar cupo a P0/P1; ante 429 pausa 60 s y se sigue con caché.
- **Progreso visible no bloqueante**: «Completando historial… 12/23».
- **Por hitos**: Hito A = P0 + P1 con cola simple; Hito B = P2 y cancelación por pantalla; P3 = post-MVP.

---

## 6. Navegación y pantallas

### 6.1 Rutas (go_router, `StatefulShellRoute.indexedStack`)
`/` Inicio · `/competiciones/:leagueId?temporada=&fase=&ronda=` · `/equipos?q=` · `/equipos/:teamId` · `/partidos/:eventId` · `/favoritos` · `/diagnostico` (debug).

### 6.2 Layout adaptable
< 600 px: `NavigationBar` inferior, pull-to-refresh · 600–1199 px: `NavigationRail` · ≥ 1200 px: rail extendido, buscador en barra superior, Inicio en 2 columnas, fixture con panel de detalle, ancho máx. 1200 px. En Web también botón «Actualizar».

### 6.3 Componentes reutilizables
`MatchCard`, `TeamBadge` (`/tiny`/`/small`, placeholder con iniciales; estrategia Web según T0.2), `ScoreBox`, `MatchStatusChip`, `KickoffText` («Horario por confirmar»), `DayHeader`, `MatchListByDay`, `StaleDataBanner`, `EmptyView`, `ErrorView`, `LoadingView`, `CompetitionChip`, `SectionHeader`, `ResponsiveScaffold`. Accesibilidad: `Semantics` en tarjetas, contraste M3, objetivos ≥ 48 px, escala de texto.

---

## 7. BLoC y estados

| BLoC | Events | Concurrencia |
|---|---|---|
| `CompetitionFixtureBloc` | `CompetitionSelected`, `SeasonSelected`, `PhaseSelected`, `StageSelected`, `Next/PreviousStageRequested`, `FixtureRefreshRequested` | `restartable` + descarte si la `StageKey` ya no es la actual |
| `MatchDetailBloc` | `MatchDetailStarted(id)`, `MatchDetailRefreshRequested` | `droppable` |
| `HomeBloc` | `HomeStarted`, `HomeRefreshRequested` | `droppable` |
| `TeamSearchBloc` | `SearchQueryChanged` (debounce 350 ms), `SearchCleared` | debounce + `restartable` |
| `TeamDetailBloc` | `TeamDetailStarted(id)`, `TeamDetailRefreshRequested` | `restartable`; cancela su sync al cerrarse |
| `FavoritesBloc` (global) | `FavoritesSubscribed`, `FavoriteToggled` | secuencial |

Estados sealed comunes: `Initial`, `Loading`, `Loaded{data, isRefreshing, origin, fetchedAt, refreshError?}`, `Empty{reason}`, `Failure{failure}`. «Actualizando» = `isRefreshing`; «caché con error» = `refreshError != null`.

---

## 8. Riesgos técnicos

| Riesgo | Mitigación |
|---|---|
| Escudos sin CORS en Web | T0.2 obligatoria antes de construir `TeamBadge`; opciones D12 |
| Fases mezcladas en `eventsround` | `PhaseResolver` con catálogo + `undetermined` en vez de adivinar |
| Hora `00:00` ambigua | regla conservadora D5 |
| Respuestas truncadas / eventos movidos | `RoundMergePolicy` §5.3 |
| Tope 30 req/min y 429 | rate limiter, TTL, `SyncScheduler` con cupos |
| Clave `123` pública | `--dart-define`; caché offline; premium solo con tu aprobación |
| Códigos de ronda no documentados | «Ronda {n}» + log + actualización del catálogo |
| Catálogo de fases a mantener cada semestre | tarea documentada en `CLAUDE.md`; partidos fuera de ventana quedan `undetermined`, no mal ubicados |
| Ganador por penales desconocido | «Definido por penales»; inferencia por ronda siguiente post-MVP |
| ~~Mojibake~~ | Descartado en Fase 4: era un artefacto de la consola de Windows al inspeccionar; los 65 fixtures son UTF-8 correcto |

---

## 9. Roadmap definitivo

Cada `Tx.y` es un pedido independiente. Al cerrar cada tarea: `flutter analyze` limpio + tests de la tarea + ejecución en tablet y Chrome cuando haya UI.

### Hitos
- **Hito A — Primera versión navegable** (lo antes posible): fixture real de **Primera División y Primera Nacional** con navegación por temporada/fase/fecha, hora argentina conservadora, estados, resultados, escudos, caché offline y detalle de partido. **Copa Argentina incluida desde el inicio** en catálogo, dominio y selector (etapas por código); solo su pulido se posterga.
- **Hito B — MVP completo**: Inicio, búsqueda, ficha de equipo con sync P2, favoritos, responsive de escritorio, estabilización.
- **Hito C — Post-MVP**: backlog.

### Fase 0 — Validaciones previas  ·  Hito A
- **Estado**: ✅ completada el 11/10/2026 — T0.1, T0.2, T0.3 hechas; V1 resuelto, D12 cerrada. Esperando aprobación para la Fase 1.
- **Objetivo**: cerrar dudas de plataforma y dejar documentación base.
- **Depende de**: nada.
- **Tareas**
  - **T0.1** Crear `CLAUDE.md` y `docs/` (`PLAN.md`, `ARCHITECTURE.md`, `API.md`, `DATA_STRATEGY.md`, `DECISIONS.md`) desde este plan. Sin código.
  - **T0.2 (obligatoria)** Prueba real de escudos en la pantalla de diagnóstico: mismo escudo con `Image.network` normal, con `webHtmlElementStrategy.fallback`, y variantes `/tiny` y `/small`; mostrar carga OK / error real. Ejecutar en Chrome y en la tablet. Documentar resultado en `docs/API.md`.
  - **T0.3** Grabar respuestas reales en `test/fixtures/api/` (Primera r=0, 1, 12, 16; Nacional r=1, 33; Copa r=64, 125, 150; `eventsnextleague`/`eventspastleague` 4406 y 4616; `lookupevent`; `lookupteam`). Nunca editadas a mano.
- **Archivos**: `CLAUDE.md`, `docs/*`, `lib/presentation/pages/api_test_page.dart`, `test/fixtures/api/`.
- **Riesgos**: escudos bloqueados en Web.
- **Aceptación**: resultado de V1 documentado con evidencia de ambas plataformas; fixtures reales guardados.
- **Para pasar**: decisión D12 cerrada según el resultado de T0.2.

### Fase 1 — Base mínima  ·  Hito A
- **Estado**: ✅ completada el 11/10/2026 — T1.1 a T1.4 hechas; 30 tests verdes; validada en tablet Android y Chrome (escritorio y tablet). Esperando aprobación para la Fase 2.
- **Objetivo**: esqueleto definitivo con lo mínimo para un fixture.
- **Depende de**: Fase 0.
- **Tareas**
  - **T1.1** Reubicar el código existente en `core/` y `features/diagnostics/` sin cambiar comportamiento; agregar `equatable`, `go_router`, `bloc_concurrency`; actualizar `widget_test.dart`.
  - **T1.2** `AppConfig`, `TheSportsDbClient.getJson` + `JsonEnvelope` + `ApiException`; `RateLimiter` (25/min, pausa 429) y reintentos acotados; tests.
  - **T1.3** `Failure`, `DataResult`, `Clock`.
  - **T1.4** `AppTheme` M3 claro/oscuro (sistema) + `es_AR`; `go_router` + `AdaptiveShell` (4 destinos; Inicio/Equipos/Favoritos como placeholder «Próximamente»); `AppDependencies`.
- **Aceptación**: app arranca en Android y Chrome con navegación inferior/rail; diagnóstico sigue funcionando.
- **Validaciones**: tests de `JsonEnvelope` (null, lista, raíz inválida, JSON roto), `RateLimiter`, reintentos.

### Fase 2 — Dominio de partidos y competiciones  ·  Hito A
- **Estado**: ✅ completada el 11/10/2026 — T2.1 a T2.6 hechas; 125 tests verdes; `domain/` sin Flutter/http/sembast. Esperando aprobación para la Fase 3.
- **Depende de**: Fase 1 (y fixtures de T0.3).
- **Tareas**
  - **T2.1** Entidades de `matches` + `ArgentinaTime` + `KickoffResolver` (D5) + tests (cruce de medianoche, `00:00` sin/con corroboración, sin hora, `HH:mm`).
  - **T2.2** `MatchStatusMapper` + tests.
  - **T2.3** Entidades de `competitions` + `CompetitionCatalog` (4406, 4616, **4500**) con ventanas 2026 de Primera derivadas de los fixtures reales.
  - **T2.4** `PhaseResolver` + `StageLabeler` + `RoundNavigator` + tests (r=12 → 15/15; r=16 → 15 + 8 octavos + 15; r=0 → knockout Apertura; temporada sin catálogo → inferido o `undetermined`; Copa 125 → «Cuartos»).
  - **T2.5** `RoundMergePolicy` + `MatchGrouping` + tests (complete/partial/suspectEmpty, evento movido, reprogramado, resultado no se pierde).
  - **T2.6** Contratos `MatchRepository` y `CompetitionRepository`; casos de uso `WatchStageMatches`, `ResolveCurrentStage`, `GetMatchDetail`.
- **Aceptación**: `domain/` sin imports de Flutter/http/sembast; todos los tests verdes.

### Fase 3 — Datos y caché  ·  Hito A
- **Estado**: ✅ completada el 11/10/2026 — T3.1 a T3.4 hechas; 183 tests verdes; validada en tablet Android y Chrome (TTL sin peticiones, modo avión, reinicio). Esperando aprobación para la Fase 4.
- **Depende de**: Fase 2.
- **Tareas**
  - **T3.1** `EventDto` + `EventMapper` + `LeagueDto` + tests con fixtures reales y campos nulos.
  - **T3.2** `LocalDatabase` (sembast io/web, agregar `sembast`, `sembast_web`, `path_provider`) + stores + `QueryMetadataStore` + `CachePolicy` (TTL §5.5) + tests con `Clock` falso.
  - **T3.3** `MatchRemoteDataSource` / `MatchLocalDataSource` + `MatchRepositoryImpl` (stale-while-revalidate, merge §5.3, en vuelo compartido) + tests.
  - **T3.4** `CompetitionRepositoryImpl` (lookupleague + ronda actual) + `SyncScheduler` simple (P0/P1, sin cancelación por dueño aún).
- **Aceptación**: misma ronda dentro del TTL = 0 peticiones; modo avión muestra lo guardado; datos sobreviven reinicio en Android y Chrome.

### Fase 4 — Fixture  ·  Hito A
- **Estado**: ✅ completada el 11/10/2026 — T4.1 a T4.3 hechas; 219 tests verdes; validada con datos reales en tablet Android y Chrome. Esperando aprobación para la Fase 5.
- **Depende de**: Fase 3.
- **Tareas**
  - **T4.1** Widgets compartidos: `TeamBadge` (según resultado T0.2), `ScoreBox`, `MatchStatusChip`, `KickoffText`, `MatchCard`, `DayHeader`, `EmptyView`, `ErrorView`, `StaleDataBanner` + widget tests.
  - **T4.2** `CompetitionFixtureBloc` + `bloc_test` (navegación rápida: solo se muestra la última etapa; error con caché).
  - **T4.3** `CompetitionsPage`: selectores competición/temporada/fase (incluye «Sin fase determinada» solo si hay partidos así), navegador de etapas, lista por día, pull-to-refresh, URL sincronizada; abre en la etapa actual.
- **Aceptación**: Primera 2026 Clausura fecha 12 = los 15 de octubre; Apertura fecha 12 = los 15 de marzo; Nacional fecha 33 = 18; Copa muestra Cuartos y Semifinales; partidos `00:00` sin corroborar dicen «Horario por confirmar».

### Fase 5 — Detalle de partido  ·  Hito A (cierra la primera versión)
- **Estado**: ✅ completada el 11/10/2026 — T5.1 hecha; 228 tests verdes; validada en tablet Android y Chrome. **Hito A entregado**: esperando revisión y aprobación para el Hito B (Fase 6).
- **Tareas**
  - **T5.1** `MatchDetailBloc` + `MatchDetailPage` (equipos, escudos, fecha, hora ART o «Horario por confirmar», competición, fase/etapa, estado, resultado, estadio, imagen y video si existen, «Reprogramado») + navegación desde `MatchCard` y deep link `/partidos/:id`.
- **Aceptación**: campos ausentes no aparecen; deep link funciona en Web.
- **Entrega Hito A**: build de prueba en tablet y Chrome; revisión tuya antes de seguir.

### Fase 6 — Inicio  ·  Hito B
- **Estado**: ✅ completada el 11/10/2026 — T6.1 y T6.2 hechas; 267 tests verdes; validada en tablet Android y Chrome (escritorio y tablet): frío = 12 peticiones, caliente = 0.
- **Ajuste en T6.1**: «ronda actual/anterior» se resolvió como *ronda del último partido + etapa siguiente* (o la del próximo partido si es otra), máx. 2 por competición, más los partidos de los punteros aunque su ronda no se cargue. Motivo: con la fecha en curso, próximo y último caen en la misma ronda (caso real del 11/10) y la fecha siguiente quedaba fuera de «Próximos».
- **Observaciones para revisar**: «Recientes» cubre solo ayer (ventana del plan): entre semana suele quedar vacío; se podría ampliar a «últimos 3 días» sin peticiones extra (las rondas ya están cargadas).
- **T6.1** `GetHomeFeed` (ronda actual/anterior de cada competición → ayer…+7 días) + `HomeBloc` + tests.
- **T6.2** `HomePage`: Hoy, Próximos, Recientes, accesos a competiciones y al buscador.
- **Aceptación**: frío ≤ 12 peticiones; caliente 0 dentro del TTL.

### Fase 7 — Equipos  ·  Hito B
- **Estado**: ✅ completada el 12/10/2026 — T7.1 a T7.4 hechas; 343 tests verdes; validada en la tablet (app Android y Chrome de la tablet). Esperando aprobación para la Fase 8.
- **Aceptación verificada**: «river» → River Plate sin red (test, y tablet en modo avión tras reiniciar la app); la ficha de Boca reúne Primera + Copa (23 rondas: 17 + 6); salir de la ficha detiene su sync (test, y tablet: 0 peticiones en los 80 s siguientes).
- **Presupuesto medido (Boca, en frío)**: 25 peticiones = `lookupteam` + 3 del índice + 21 rondas P2 (10 por minuto: 0 s, 60 s, 120 s). En caliente: 0.
- **Ajustes**: ver «Estado de implementación (Fase 7)» en ARCHITECTURE y el registro de DECISIONS.
- **T7.1** Índice local de equipos + bootstrap (3 peticiones) + `TextNormalizer` + tests.
- **T7.2** `TeamSearchBloc` (debounce, restartable, respaldo remoto) + `TeamSearchPage`.
- **T7.3** `SyncScheduler` P2 con `CancelToken` por dueño, cupo 10/min, pausa en segundo plano + tests de presupuesto y cancelación.
- **T7.4** `TeamDetailBloc` + `TeamDetailPage` (próximos y disputados de todas las competiciones guardadas; progreso no bloqueante).
- **Aceptación**: «river» encuentra River Plate sin red; la ficha de Boca reúne Primera + Copa; salir de la ficha detiene su sync.

### Fase 8 — Favoritos  ·  Hito B
- **Estado**: ✅ completada el 12/10/2026 — T8.1 y T8.2 hechas; 366 tests verdes; validada en la tablet (app Android release y Chrome de la tablet). Esperando aprobación para la Fase 9.
- **Aceptación verificada**: los favoritos persisten tras reiniciar — test con archivo sembast cerrado y reabierto; tablet Android: Boca y River siguen tras `force-stop` + reinstalación; Web: Gimnasia LP sigue tras recargar la página (IndexedDB).
- **Presupuesto**: «Tus equipos» no hace peticiones (solo lee lo guardado): Inicio en caliente con favoritos = 0 peticiones en la tablet; tests `watch_favorite_teams_test.dart` y `home_page_test.dart`.
- **Ajustes**: ver «Estado de implementación (Fase 8)» en ARCHITECTURE y el registro de DECISIONS.
- **Observaciones para la Fase 9**: «Tus equipos» aparece ~1 s después que el resto del Inicio en Web y empuja el contenido; el aviso «se agregó a favoritos» sigue visible al cambiar de sección. La primera apertura del Inicio en Web tardó ~70 s por una pausa ante 429 (la misma IP venía de sincronizar la ficha de River en Android).
- **T8.1** Repo local + `FavoritesBloc` global + `FavoriteButton` + `FavoritesPage`.
- **T8.2** Sección «Tus equipos» en Inicio.
- **Aceptación**: favoritos persisten tras reinicio en Android y Web.

### Fase 9 — Responsive y estabilización  ·  Hito B
- **Estado**: ✅ completada el 12/10/2026 — T9.1 a T9.3 hechas; 397 tests verdes; builds release APK y Web; validada en la tablet (app Android en vertical y horizontal, Chrome de la tablet en vertical y horizontal). **Hito B (MVP) completo**: esperando revisión y aprobación.
- **Aceptación verificada**: layout sin desbordes a 360, 768, 1280 y 1920 px (`test/app/responsive_layout_test.dart`); pautas de Flutter de objetivos ≥ 48 px, controles con nombre y contraste en todas las secciones a 360 y 1280 px; texto al 200 % sin desbordes en un teléfono (`test/app/accessibility_test.dart`); offline, 429, timeout y formato con su mensaje en cada pantalla.
- **Observaciones resueltas**: «Tus equipos» ya no aparece después (el Inicio espera a tenerlo); el aviso de favoritos se cierra solo (con acción, Flutter lo dejaba fijo) y no pasa a otra sección; actualizar antes de 30 s avisa «Ya está actualizado»; durante una pausa por 429 se avisa hasta qué hora. Web en la tablet: ~10–12 s hasta ver el Inicio (medido a mano, con otras 8 pestañas de la app inactivas; antes ~20 s).
- **Ajustes**: ver «Estado de implementación (Fase 9)» en ARCHITECTURE y el registro de DECISIONS.
- **Observaciones para revisar**: al volver de un partido abierto a pantalla completa, la URL Web del fixture queda en `#/competiciones` (sin la fecha; ya pasaba antes); la ficha de un equipo sigue sincronizando si se cambia de sección sin cerrarla (la sección queda viva en segundo plano); la ficha no avisa «Ya está actualizado».
- **Observaciones de la Fase 8** (ver arriba): aparición tardía de «Tus equipos» en Web; aviso de favoritos que persiste entre secciones.
- **Observaciones del Hito A en la tablet (11/10/2026)** para revisar acá:
  - Deslizar para actualizar antes de 30 s de la última carga no hace nada y no lo avisa (la regla es correcta; falta feedback, p. ej. «Ya está actualizado»).
  - La versión Web tardó ~20 s en abrir en la tablet con 4 pestañas de la app abiertas: medir con una sola.
- **T9.1** Breakpoints (360, 768, 1280, 1920 px), Inicio en 2 columnas, panel de detalle en escritorio, buscador en barra superior.
- **T9.2** Accesibilidad básica y revisión de errores (offline, 429, timeout, formato) en todas las pantallas.
- **T9.3** Tests faltantes, `flutter analyze` limpio, builds release (APK + Web), prueba completa; actualizar docs y `CLAUDE.md`.

### Fase 10 — Post-MVP  ·  Hito C
Copa: final (V2), «Avanza X» tras penales, cuadro de llaves · Nacional: Reducido (V3) y zonas si se aprueba D7-b · Playoffs del Clausura (V3) · Sync P3 (historial y temporada anterior) · Otras competiciones del equipo (D8) · Auto-refresco con partidos en vivo (D11) · Selector manual de tema · Caché de escudos en disco (Android) · Purga de temporadas viejas · Tabla de posiciones calculada localmente · Notificaciones · Calendario mensual · Compartir partido · Agregar al calendario · Más competiciones (5215, 5523, 5524).

---

## 10. Validaciones y pruebas

| Área | Tipo | Casos clave |
|---|---|---|
| Parsing | unit (fixtures reales) | null/"", `strTime` "17:45", `events: null`, JSON inválido |
| Hora | unit | medianoche, `00:00` con/sin corroboración, sin hora, día argentino |
| Estados | unit | NS/1H/HT/2H/FT/AET/PEN/PST/desconocido, NS vencido |
| Fases | unit | catálogo, inferido, `undetermined`, consistencia, códigos Copa |
| Merge | unit | complete/partial/suspectEmpty, movido, reprogramado, `orphaned`→verificación |
| Caché | unit + Clock falso | cada TTL, refresco manual, fallo → caché + error |
| Rate limit / sync | unit | cola 25/min, 429, cupo P2/P3, cancelación, sin duplicados |
| BLoC | `bloc_test` | estados, navegación rápida, debounce, respuestas fuera de orden |
| Widgets | widget test | `MatchCard` por estado, «Horario por confirmar», vacío, error, banner |
| Plataformas | manual | tablet Android, Chrome escritorio y móvil, offline |

---

## 11. Decisiones

**Aprobadas**: DDD por features · BLoC sin Cubit · go_router (D3) · sembast/sembast_web (D1) · catálogo de competiciones · carga incremental por rondas.

| # | Decisión | Estado / recomendación |
|---|---|---|
| D2 | DI | Composition root manual + `RepositoryProvider` (sin `get_it`) — recomendada |
| D4 | Zona horaria | UTC−3 fijo encapsulado — recomendada |
| D5 | Horarios ambiguos | **Ajustada**: regla conservadora confirmed/tentative/unknown; `00:00` sin corroboración → «Horario por confirmar» |
| D6 | Fases de Primera | **Ajustada**: catálogo por temporada desde datos reales; inferencia solo con evidencia limpia; si no, `undetermined` |
| D7 | Zonas de Nacional | (a) sin zonas en MVP — recomendada · (b) mapeo manual post-MVP |
| D8 | Otras competiciones del equipo | post-MVP como «información parcial» |
| D9 | Sincronización | **Ajustada**: `SyncScheduler` incremental, priorizado, cancelable, reanudable, con cupos |
| D10 | Temporadas | actual y anterior (`YYYY`) |
| D11 | En juego | estado + «actualizado hh:mm», refresco manual; auto-refresco post-MVP |
| D12 | Escudos en Web | ✅ **Cerrada tras T0.2**: `Image.network(..., webHtmlElementStrategy: WebHtmlElementStrategy.fallback)` + placeholder con iniciales si falla la red. Sin proxy. |
| D13 | `matches` como núcleo; fixtures dentro de `competitions` | recomendada |
| D14 | Datos y caché antes que pantallas; Copa en el fixture desde el inicio | recomendada |

---

## 12. Primera tarea de implementación

**T0.1 — Crear `CLAUDE.md` y `docs/`** (PLAN, ARCHITECTURE, API, DATA_STRATEGY, DECISIONS) a partir de este plan v2. No toca código Dart ni dependencias; deja el contexto estable para cada sesión siguiente.

Inmediatamente después: **T0.2 — validación real de escudos en Flutter Web y Android** (primera tarea con código, obligatoria antes de construir `TeamBadge`).

## Verificación
Cada tarea termina con `flutter analyze` limpio y sus tests verdes; cada fase con UI se prueba en la tablet Android y en Chrome (escritorio y vista móvil) con datos reales de la API, nunca simulados. El Hito A se entrega para tu revisión antes de iniciar el Hito B.
