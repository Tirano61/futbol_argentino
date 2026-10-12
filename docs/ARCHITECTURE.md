# Arquitectura DDD

> Generado desde el Plan Maestro v2 (aprobado el 11/10/2026). Las referencias «§N» apuntan a secciones de [PLAN.md](PLAN.md).

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


## Estado de implementación (Fase 1, 11/10/2026)

Implementado:
- `lib/app/`: `app.dart` (MaterialApp.router, tema M3 claro/oscuro según sistema, `es_AR`), `di/app_dependencies.dart` (composition root), `router/app_router.dart` (`AppRoutes`, `StatefulShellRoute.indexedStack`), `shell/adaptive_shell.dart` (`NavigationBar` < 600 px, `NavigationRail` 600–1199 px, riel extendido ≥ 1200 px), `theme/app_theme.dart`.
- `lib/core/`: `config/app_config.dart`, `network/` (`TheSportsDbClient`, `RateLimiter`, `ApiException`, `JsonEnvelope`), `error/failure.dart`, `result/data_result.dart`, `time/` (`Clock`, `argentina_time.dart`).
- `lib/features/diagnostics/`: prueba técnica reubicada (debug o `--dart-define=DIAGNOSTICS=true`), ruta `/diagnostico`.
- `lib/shared/presentation/widgets/coming_soon_page.dart`: placeholder de Inicio, Competiciones, Equipos y Favoritos.

### Contrato de errores
- `TheSportsDbClient` lanza `ApiException` (capa de datos): tipo, mensaje real, URI, status, tiempo y cuerpo.
- Los repositorios lo traducen con `ApiException.toFailure()` y nunca lo dejan pasar al dominio ni a la UI.
- Un repositorio **lanza** `Failure` solo si no tiene ningún dato; si tiene caché, devuelve `DataResult` con `refreshError`.
- Reintentos: solo timeout, error de conexión y HTTP 5xx (máx. 2, con 1 s y 3 s + hasta 500 ms al azar). Nunca 4xx, 429 ni JSON inválido. En Web un `ClientException` no se reintenta (puede ser CORS).
- HTTP 429: el `RateLimiter` se pausa 60 s para todas las consultas.

### URLs en Web
Por ahora go_router usa la estrategia por defecto con `#` (`/#/diagnostico`), que funciona en cualquier hosting estático sin configuración. Las URLs sin `#` (`usePathUrlStrategy`) requieren que el servidor reescriba todas las rutas a `index.html`; se decidirá cuando se defina dónde se publica la versión Web.

## Estado de implementación (Fase 2, 11/10/2026)

Dominio implementado (Dart puro, 125 tests):
- `core/time/`: `CalendarDay`, `ArgentinaTime` (UTC−3 fijo, día argentino, formatos).
- `features/matches/domain/`: `Match`, `TeamRef`, `Kickoff`, `MatchStatus`, `Score`; servicios `KickoffResolver` (D5), `MatchStatusMapper`, `RoundMergePolicy` (§5.3), `MatchGrouping`; contrato `MatchRepository` + `RoundQuery`.
- `features/competitions/domain/`: `Competition`, `Season`, `PhaseKey`/`StageKind`, `PhaseAssignment`, `Stage`; `CompetitionCatalog` (4406, 4616, 4500 con ventanas 2025–2026 desde datos reales); servicios `PhaseResolver` (D6), `StageLabeler`, `RoundNavigator`; contrato `CompetitionRepository`; casos de uso `WatchStageMatches`, `ResolveCurrentStage`.

### Ajustes respecto del plan
- **`Match` no guarda la fase.** La fase depende del catálogo de `competitions` y `matches` no puede depender de `competitions` (§3.1). `PhaseResolver` la calcula por ronda y `WatchStageMatches` devuelve `StageMatches.assignments`. Ventaja extra: corregir el catálogo no exige migrar datos guardados.
- **Sin caso de uso `GetMatchDetail`**: sería un pasamanos de `MatchRepository.getMatch` (convención: casos de uso solo con lógica). El BLoC de detalle usará el repositorio.

### Reglas de fase implementadas (`PhaseResolver`)
1. Temporada con catálogo: el día argentino debe caer en el período de **un solo** torneo. Ronda 0 → eliminatorias solo dentro de la ventana de eliminatorias; ronda 16 → octavos si cae en esa ventana, fecha 16 si cae en la regular; fechas 1–15 → solo dentro del período regular.
2. Un torneo en curso puede no tener fin (`regularTo: null`); sin ventana de eliminatorias verificada, sus partidos de ronda 0 quedan `undetermined`.
3. Sin catálogo: inferencia solo con exactamente dos grupos de días separados por ≥ 45 días y ≤ 15 partidos cada uno.
4. Consistencia: si un equipo aparece dos veces en la misma fase y fecha regular, **ambos** partidos quedan `undetermined` (no se puede saber cuál es cuál).

### Política de merge implementada (`RoundMergePolicy`)
- `complete` si trae al menos lo que había visible en la ronda y lo esperado del catálogo; si no, `partial`.
- En `complete`, los faltantes pasan a `orphaned` y se verifican. En `partial` no hay bajas; solo se verifican faltantes que no aparecen hace más de 24 h (así una respuesta siempre truncada no deja datos viejos para siempre).
- Verificación (`applyVerification`): no existe → `removed`; misma ronda → `unconfirmed` (visible con aviso); otra ronda → activo en la nueva.

## Estado de implementación (Fase 3, 11/10/2026)

- `features/matches/data/`: `EventDto` (parsing tolerante), `EventMapper`, `MatchRecord` (formato guardado), `MatchRemoteDataSource`, `MatchLocalDataSource`, `RoundCachePolicy`, `MatchRepositoryImpl`.
- `features/competitions/data/`: `LeagueDto`, `CompetitionRecord`, `CompetitionRemoteDataSource`, `CompetitionRepositoryImpl`.
- `core/`: `storage/local_database.dart` (+ apertura por plataforma con import condicional), `cache/` (`CacheClass`, `QueryMetadataStore`), `sync/sync_scheduler.dart`, `network/remote_call.dart` (traduce `ApiException`/`JsonShapeException` a `Failure`).
- `MatchRepository` suma `prefetchRound` (P1, no lanza errores).
- Diagnóstico suma «Prueba de caché» (`CacheProbeBloc`) para validar la caché en dispositivos.
- `main` es asíncrono: abre la base antes de `runApp`.

## Estado de implementación (Fase 4, 11/10/2026)

- `shared/presentation/`: `MatchLabels` (días en español, horario D5, estados, descripción accesible), `failureMessage`, `TeamBadge` (fallback `<img>` en Web + iniciales), `MatchStatusChip`, `MatchCard` (incluye marcador y horario; reemplaza a `ScoreBox`/`KickoffText` separados), `matchDayItems`/`DayHeader`, `EmptyView`, `ErrorView`, `StaleDataBanner`.
- `features/competitions/presentation/`: `CompetitionFixtureBloc` (un solo handler `restartable`: cada selección cancela la carga anterior; precarga P1 de la etapa siguiente), `CompetitionsPage`, `FixtureSelectors`, `StageNavigator`, `FixtureRoute` (URL ↔ selección).
- **URL**: `/competiciones/4406?temporada=2026&fase=clausura&ronda=12[&etapa=eliminatoria]`. En Web se actualiza con `SystemNavigator.routeInformationUpdated(replace: true)` sin recrear la pantalla. `/competiciones` y `/competiciones/:leagueId` son rutas **hermanas** (si se anidan, el enlace directo muestra «atrás»).
- **Sin fase determinada**: si la ronda tiene partidos así, aparece «N partidos de esta ronda sin fase determinada» y se pueden ver aparte.
- `Clock` disponible por `RepositoryProvider`.
- `LocalDatabase.openOrMemory` con timeout de 5 s: si IndexedDB no responde, la app arranca con base en memoria en lugar de quedar en blanco.

## Estado de implementación (Fase 5, 11/10/2026) — Hito A completo

- **Nueva feature `match_detail`** (desvío del plan, que ubicaba el detalle en `matches/presentation`): el detalle muestra fase y etapa, que dependen del catálogo de `competitions`, y `matches` no puede depender de `competitions`. Igual que `home`, compone las dos: `match_detail → competitions, matches`.
  - `GetMatchDetail`: partido (`MatchRepository.getMatch`) + fase/etapa con `PhaseResolver` sobre la ronda guardada (primera emisión de `watchRound`, normalmente la caché); sin ronda, clasifica con el partido solo.
  - `MatchDetailBloc` (`droppable`): `Loading`, `Loaded` (con `refreshError`/`isRefreshing`), `Failure`.
  - `MatchDetailPage`: competición, «Fase · Etapa», escudos, marcador o «vs», fecha y hora ART o «Horario por confirmar» (con nota si es `00:00` UTC sin corroborar), «Reprogramado», estado, aviso de penales sin resultado, estadio, video (`url_launcher`) e imagen, solo si existen.
- **Rutas**: `/partidos/:eventId` fuera del shell (pantalla completa). `GoRouter.optionURLReflectsImperativeAPIs = true`: abrir un partido actualiza la URL en Web. Con enlace directo (sin «atrás») se ofrece «Ir al inicio».

## Estado de implementación (Fase 6, 11/10/2026)

- **Feature `home`** (`home → competitions, matches`, sin datos propios):
  - `domain/entities/home_feed.dart`: `HomeMatch` (partido + competición, fase y etapa visibles), `CompetitionFeed` (por competición: cargando, partidos de la ventana, `fetchedAt`, error) y `HomeFeed` (secciones `todayMatches`/`upcoming`/`recent` calculadas, `carryOver` para refrescar sin parpadeos).
  - `domain/usecases/get_home_feed.dart` (`GetHomeFeed`): stream que emite a medida que llega cada competición; ventana de ayer a +7 días (día argentino); fase con `PhaseResolver` sobre la ronda completa. Un error de una competición no afecta a las demás.
  - `presentation/bloc/home_*` (`HomeBloc`, `droppable`): `Initial`, `Loading`, `Loaded{feed}` (`isBusy` mientras alguna competición carga), `Failure` (ninguna competición con datos).
  - `presentation/pages/home_page.dart`: accesos a «Buscar equipo» (lleva a Equipos; la búsqueda es la Fase 7) y a cada fixture; secciones Hoy, Próximos 7 días (por día) y Recientes (ayer); subtítulo «Competición · Fase · Etapa» en cada tarjeta; aviso de datos guardados y de competiciones que no cargaron; pull-to-refresh y botón «Actualizar»; acceso al diagnóstico.
- `RoundNavigator.locate`: etapa de un partido suelto (extraída de `ResolveCurrentStage`, la usan ambos).
- `MatchRepository.watchRound` y `CompetitionRepository.getSchedulePointers` aceptan `priority`: el Inicio carga con P1 y el refresco manual con P0.
- `shared/presentation/widgets/section_header.dart` (`SectionHeader`).

## Estado de implementación (Fase 7, 12/10/2026)

- **Feature `teams`** (`teams → competitions, matches`; desvío del plan, que decía `teams → matches`: la ficha necesita catálogo, fases y etapas, igual que `home` y `match_detail`).
  - `domain/entities`: `Team` (`lookupteam`), `TeamSummary` (ítem de búsqueda: `TeamRef` + competiciones), `TeamDetail` / `TeamMatch` / `TeamSyncProgress`.
  - `domain/services/team_index.dart` (`TeamIndex`): cada palabra buscada debe aparecer en el nombre normalizado; orden: empieza con la búsqueda → alguna palabra empieza con ella → resto; alfabético dentro de cada grupo. Búsqueda en línea solo desde 3 letras.
  - `domain/usecases`: `EnsureTeamIndex` (primera etapa de cada competición del catálogo = todos sus equipos; temporada = año argentino, o la anterior si la primera etapa todavía está vacía), `SearchTeamsOnline` (respaldo `searchteams`), `WatchTeamDetail` (stream: guardado → `lookupteam` P0 + índice P1 → rondas de la temporada P2 de a una, alternando competiciones, de la última a la primera).
  - `data`: `TeamDto`, `TeamRecord` (store `teams`), `TeamRemoteDataSource` (`lookupteam`, `searchteams`), `TeamRepositoryImpl` (índice desde los partidos guardados sin reconstruirlos, con `MatchLocalDataSource.teamSightings`; nombre y escudo del partido visto más recientemente; competiciones de la temporada más reciente; `lookupteam` con TTL 7 días; búsqueda en línea filtrada a fútbol de Argentina).
  - `presentation`: `TeamSearchBloc` (búsqueda `restartable` con debounce de 350 ms dentro del handler; la carga del índice va aparte y solo repite la búsqueda si el índice nuevo cambia el resultado), `TeamSearchPage` (`/equipos?q=`; en Web la URL refleja la búsqueda), `TeamDetailBloc` (`restartable`; un `CancelToken` por carga, cancelado al reemplazarla o al cerrar), `TeamDetailPage` (`/equipos/:teamId`, anidada: «atrás» vuelve al buscador; encabezado con estadio y competiciones, «Completando partidos… n/N», Próximos y Disputados del más reciente al más viejo).
- **`core/text/text_normalizer.dart`**: minúsculas, sin acentos; apóstrofos y puntos se quitan («Newell's» → «newells»); el resto de los signos separa palabras.
- **`core/sync/`**: `SyncPriority.team` (P2) y `cancel_token.dart` (`CancelToken`, `SyncCancelled`). Ver DATA_STRATEGY.
- **`MatchRepository`** suma `syncRound` (actualiza una ronda vencida sin emitirla; acepta prioridad y `CancelToken`), `storedRound` y `storedTeamMatches` (lecturas locales). `prefetchRound` usa `syncRound`.
- **`StageLabeler.describe`**: «fase · etapa» de un partido (la usan el Inicio y la ficha).
- **`matchDayItems(newestFirst:)`**: días del más reciente al más viejo (Disputados).
- **App**: `AppLifecycleListener` pausa la cola P2 al ocultarse la app (`onHide`) y la reanuda al volver (`onShow`).

## Estado de implementación (Fase 8, 12/10/2026)

- **Feature `favorites`** (`favorites → matches` solo por `TeamRef`):
  - `domain`: `FavoriteTeam` (`teamId`, nombre, escudo, `addedAt`), `FavoritesRepository` (`watchAll`, `contains`, `save`, `remove`; sin `DataResult`: los datos son solo locales y no vencen), `ToggleFavorite` (consulta lo guardado, no la pantalla: dos toques seguidos agregan y quitan).
  - `data`: `FavoriteRecord` (store `favorites`, clave `idTeam`, `v: 1`), `FavoritesRepositoryImpl` (`onSnapshots` de sembast: la lista se actualiza sola; orden por nombre normalizado, sin acentos).
  - `presentation`: `FavoritesBloc` **global** (creado en `app.dart` arriba del router; `FavoritesSubscribed` `restartable` y `FavoriteToggled` `sequential` en handlers separados, para que la suscripción abierta no bloquee los toques), `FavoriteButton` (estrella con el color del tema; aviso con «Deshacer»), `FavoritesPage` (`/favoritos`: vacía con «Buscar equipo»; lista con estrella para quitar).
- **Rutas**: `/favoritos/:teamId` (ficha anidada en Favoritos: «atrás» vuelve a la lista). El constructor de la ficha es compartido con `/equipos/:teamId`.
- **Estrella** en la barra de la ficha y en cada resultado del buscador (reemplaza la flecha): `teams → favorites`, solo en presentación.
- **«Tus equipos» en el Inicio** (`home → favorites`):
  - `WatchFavoriteTeams` (stream): favoritos × partidos guardados de esos equipos → próximo (en juego o por jugarse) y último disputado de cada uno. Sin red; se recalcula al cambiar los favoritos y cada vez que se guardan partidos.
  - `HomeFavoritesBloc` (aparte del `HomeBloc`, `restartable`): `Loading`, `Loaded(teams)`.
  - Sección entre los accesos y «Hoy»: el equipo (abre su ficha en Favoritos) y las tarjetas «Próximo · día» y «Último · día» con «competición · fase · etapa»; sin partidos guardados lo dice; sin favoritos explica cómo agregarlos.
- **Reutilización**: `MatchGrouping.isPlayed` (regla disputado/próximo, antes privada de la ficha) y `competitions/domain/services/stored_match_labeler.dart` (`StoredMatchLabeler`, antes `_RoundPhases` de `WatchTeamDetail`).
- **`MatchRepository.watchStoredTeamsMatches`** (+ `MatchLocalDataSource.watchByTeams`): partidos guardados de varios equipos, reactivo, sin red.
- **Tests**: en `testWidgets`, las llamadas directas a sembast van en `outsideFakeAsync` (`tester.runAsync`): sembast usa temporizadores que el reloj falso no avanza.

