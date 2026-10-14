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
`/` Inicio · `/competiciones/:leagueId?temporada=&fase=&ronda=` · `/equipos?q=` · `/equipos/:teamId` · `/partidos/:eventId` · `/favoritos` · `/ajustes` (Fase 12) · `/diagnostico` (debug).

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
- `lib/app/`: `app.dart` (MaterialApp.router, tema M3 claro/oscuro según el `SettingsBloc` global, `es_AR`), `di/app_dependencies.dart` (composition root), `router/app_router.dart` (`AppRoutes`, `StatefulShellRoute.indexedStack`), `shell/adaptive_shell.dart` (`NavigationBar` < 600 px, `NavigationRail` 600–1199 px, riel extendido ≥ 1200 px), `theme/app_theme.dart`.
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

- `shared/presentation/`: `MatchLabels` (días en español, horario D5, estados, descripción accesible), `failureMessage`, `TeamBadge` (imagen del `BadgeImageResolver`: disco en Android, fallback `<img>` en Web; iniciales si falla), `MatchStatusChip`, `MatchCard` (incluye marcador y horario; reemplaza a `ScoreBox`/`KickoffText` separados), `matchDayItems`/`DayHeader`, `EmptyView`, `ErrorView`, `StaleDataBanner`.
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

## Estado de implementación (Fase 9, 12/10/2026)

- **Anchos** (`shared/presentation/layout/breakpoints.dart`, `Breakpoints`): compacto < 600 px (navegación inferior), mediano 600–1199 px (riel), amplio ≥ 1200 px (riel extendido, buscador en la barra, Inicio en 2 columnas, fixture con panel). Contenido hasta 1200 px en el diseño amplio; las listas simples (buscador, favoritos, detalle) siguen en 720–900 px. Se decide por el ancho de la ventana, no del contenido.
- **Inicio en 2 columnas**: Hoy y Próximos a la izquierda; accesos, «Tus equipos» y Recientes a la derecha. En una columna, el orden de siempre.
- **Panel de detalle** (fixture, diseño amplio): tocar un partido lo abre al lado (`MatchDetailPanel`, mismo `MatchDetailBloc` y contenido que `MatchDetailPage`) y lo resalta (`MatchCard.selected`, `matchDayItems(selectedId:)`); «Abrir en pantalla completa» lleva a `/partidos/:id`. La selección es estado local de la pantalla (no va a la URL).
- **Buscador en la barra** (`app/shell/top_bar_team_search.dart`, `TopBarTeamSearch`): en el diseño amplio es un campo en Inicio, Competiciones y Favoritos; al confirmar abre `/equipos?q=`. La página del buscador lleva `ValueKey(q)` para que una búsqueda nueva reemplace a la anterior. En `app/shell` y no en `teams` para no crear un ciclo `teams ↔ favorites`.
- **Shell**: `AdaptiveShell` es `StatefulWidget`; al cambiar de sección (por el menú o por un enlace) quita el aviso abierto, al final del frame.
- **Avisos**: `FavoriteButton` usa `persist: false` (en este Flutter un `SnackBar` con acción queda fijo por defecto). `showAlreadyUpToDate` (`shared/presentation/widgets/refresh_feedback.dart`): tras un refresco manual que no cambió la hora de descarga ni dio error, avisa «Ya está actualizado: los datos son de las HH:mm.» (Inicio, fixture y detalle).
- **429** (`core/network/rate_limit_status.dart`, `RateLimitStatus`, implementado por `RateLimiter`): `pausedUntil` y un stream de pausas. `RateLimitNotice` (`app/shell/rate_limit_notice.dart`) envuelve toda la app desde `MaterialApp.router.builder` y muestra arriba «TheSportsDB pidió esperar por el límite de consultas. Se sigue a las HH:mm.» mientras dure la pausa; la estructura no cambia al mostrarlo (el contenido conserva su estado). Desde la Fase 16 también avisa las esperas de 3 s o más por el tope propio (`throttles`).
- **Inicio**: espera a «Tus equipos» antes de mostrarse; `HomeFavoritesUnavailable` si la base local falla (lo dice y muestra el resto).
- **Fixture**: `FixtureEmpty.isRefreshing` (refrescar una etapa vacía ahora tiene principio y fin); un error al refrescar una etapa vacía ya consultada la deja vacía con el aviso de datos guardados, en vez de pantalla de error.
- **Accesibilidad**: `EmptyView` se desplaza si no entra (texto grande); el selector de temporada se ajusta al ancho. `Semantics(selected:)` en la tarjeta resaltada y encabezado del panel.
- **Tests**: `test/helpers/recorded_app.dart` (`pumpApp`: la app completa con respuestas grabadas, reloj que avanza con `pump`, respuestas reemplazables); `test/app/responsive_layout_test.dart`, `accessibility_test.dart`, `error_states_test.dart`.

## Estado de implementación (Fase 10.1, 12/10/2026)

- **URL del fixture en Web**: la ubicación del router es la que abrió la pantalla y no sigue los cambios de competición, fase o etapa (esos se informan al navegador con `SystemNavigator.routeInformationUpdated`). Al volver de un partido (`push`) o de otra sección, el router informaba su ubicación y se perdía la etapa. `_CompetitionsViewState` escucha al `routerDelegate` (solo en Web) y, si `router.state.uri` (incluye lo abierto con `push`) es del fixture sin la etapa (`FixtureRoute.urlToRestore`), repone la de la etapa al final del frame, solo si la pantalla sigue siendo la ruta actual (si el router abrió otra competición, no la pisa).
- **Ficha en una sección oculta**: `TeamDetailPage` escucha `TickerMode.getValuesNotifier` (go_router apaga el `TickerMode` de las secciones inactivas) y manda `TeamDetailPaused`/`TeamDetailResumed`. La pausa tiene su propio handler (sin `restartable`): solo cancela el `CancelToken` y la carga en curso termina sola; al volver, `TeamDetailResumed` (un `TeamDetailLoadEvent`, `restartable`) sigue con lo que falta si la descarga había quedado a medias. Pasar la pausa por `restartable` dejaba los eventos siguientes esperando la cancelación de la carga.
- **«Ya está actualizado» en la ficha**: `MatchRepository.syncRound` devuelve si consultó la red; `WatchTeamDetail` cuenta las consultas de la carga (`TeamSyncProgress.fetched`, incluye `lookupteam`). Tras un refresco con 0 consultas y sin errores, la ficha avisa «Ya está actualizado.» (`showAlreadyUpToDate` sin hora).
- **Tests**: `test/app/team_detail_visibility_test.dart` (ficha oculta: sin peticiones; al volver sigue; refrescar con la descarga en curso no la cuelga); `pumpApp(requests:)` registra las peticiones.

## Estado de implementación (Fase 12, 12/10/2026)

- **`SyncProgress`** pasa a `lib/core/sync/sync_progress.dart` (antes `TeamSyncProgress` en `teams`): lo usan la ficha del equipo y `CompleteRounds`.
- **`MatchRepository`** suma `roundCacheState`, `storedSeason`, `storedSeasons` (resumen por competición y temporada, con `orphaned` y `removed`) y `deleteSeason`. `QueryMetadataStore.delete(prefix:, keys:)`. `MatchLocalDataSource.season`, `seasonSummaries` (sin reconstruir cada partido) y `deleteSeason`.
- **`CompleteRounds`** (`competitions/domain/usecases/complete_rounds.dart`) emite `SeasonCompletion` (`competitions/domain/entities/season_completion.dart`): partidos guardados de la temporada, estado de cada ronda (`RoundCompletionStatus`: falta, vencida, vigente, cerrada, histórica, descargada) y `SyncProgress`. La regla por ronda es `CompleteRounds.classify` (pura, con tests). `WatchTeamDetail` no cambia (su presupuesto sigue en 25).
- **Feature `settings`** (nueva): `domain/entities/stored_season.dart`, `domain/usecases/stored_seasons.dart` (`GetStoredSeasons`, `DeleteStoredSeasons`: la temporada actual o posterior no se puede borrar), `presentation/bloc/stored_data_bloc.dart` (`StoredDataStarted`, `StoredDataToggled`, `StoredDataDeleteRequested`; `StoredDataUnavailable` si falla la base local) y `presentation/pages/settings_page.dart`. La Fase 16 le suma el tema (ver abajo).
- **Rutas**: `/ajustes` fuera del shell (pantalla completa con «atrás»; por enlace directo, «Ir al inicio», como el partido). Acceso: engranaje «Ajustes» en la barra del Inicio.
- **`/diagnostico` → «Historial»**: `HistoryProbeBloc` (inicio con `restartable`; cancelar en su propio handler, como pide `CLAUDE.md`) y `HistoryProbeSection`: competición y temporada, «Completar temporada», «Forzar vencidas», «Cancelar», estado por ronda, temporadas guardadas y estado de la limpieza automática.
- **Tests**: `test/features/competitions/complete_rounds_test.dart` (presupuestos, reglas, cancelación, error), `test/features/settings/stored_seasons_test.dart` (vigencia, temporadas, borrado, favoritos intactos), `test/features/settings/settings_page_test.dart` (`bloc_test` y pantalla), `test/features/diagnostics/history_probe_bloc_test.dart`; Ajustes en `responsive_layout_test.dart` (4 anchos) y en `accessibility_test.dart` (pautas y texto al 200 %).

## Estado de implementación (Fase 13, 12/10/2026) — Tablas de Primera 2026

- **Dominio común** (`competitions/domain/standings/`, Dart puro):
  - `team_stats.dart`: `TeamStats` (PJ, PG, PE, PP, GF, GC, DG, Pts) y `StatsAccumulator` (suma cada partido terminado **con resultado** una vez por `idEvent`).
  - `tie_breaker.dart`: `TieBreakCriterion` sealed (`goalDifference`, `goalsFor`, `headToHead`, `fairPlay` y `drawOfLots`, estos dos no calculables), `TieBreaker` (después de los puntos; el enfrentamiento directo arma una mini tabla de puntos, DG y GF entre los empatados y se repite con los que siguen empatados) y `StandingsRow` (`isShared` = posición compartida, mismo número).
  - `standings_table.dart`: `StandingsTable` (clave, título, filas, `StandingsCoverage`, notas del reglamento, `sharedNote`), `UncountedMatch` con `UncountedReason`.
  - `regular_season_matches.dart`: `RegularSeasonMatches.classify` resuelve la fase ronda por ronda con `PhaseResolver` (deduplica con `MatchGrouping.dedupe`); solo etapas regulares de las rondas 1–16; los indeterminados quedan aparte y figuran en la cobertura.
  - `table_builders.dart`: `ZoneTableBuilder` (filas: los 15 de la zona; partidos del torneo, interzonales incluidos; h2h solo de ese torneo), `AnnualTableBuilder` (calculada directo con los partidos regulares de los dos torneos, sin eliminatorias, sin h2h) y `StandingsNotes`.
  - `zone_validator.dart`: equipo sin zona (o en dos), o más cruces con la otra zona que `interzonalsPerTeam` → sin tablas por zona («zonas no verificadas»); la anual sigue.
- **Catálogo**: `catalog/standings_format.dart` (`StandingsFormat` sealed: `NoStandings`, `LeagueZonesWithAnnual`) y `CompetitionDefinition.standingsBySeason` / `standingsFor(season)`. Primera 2026: zonas aprobadas (V12) con `idTeam`, desempates art. 10/16 y 24.3, artículos citados y el link del reglamento. Copa, Nacional y Primera 2025: `NoStandings`.
- **`WatchStandings`** (`domain/usecases/watch_standings.dart`): lo guardado + `CompleteRounds` de las rondas 1–16 (P2); recalcula con cada ronda y emite `StandingsView` (tablas, `zoneIssues`, `SyncProgress`). Refresco manual: primero fuerza con P0 las fechas con partidos sin terminar de ayer y hoy; después `CompleteRounds(forceRefresh)`.
- **Presentación**:
  - `StandingsBloc` (`restartable` para `Started`/`RefreshRequested`; `Paused` y `Resumed` en handlers propios, porque un evento que pasa por `restartable` cancela la carga en curso aunque no haya nada que retomar; `StandingsLoaded.isRefreshing` marca el refresco, porque si todo estaba al día la emisión final es idéntica a la anterior y `flutter_bloc` no la reemite).
  - `CompetitionsPage`: «Fixture | Tabla» (`SegmentedButton`); en la vista Tabla no se elige fase; la tabla descarga solo mientras se ve (pausa al pasar a Fixture o con la sección oculta, `TickerMode`).
  - `widgets/standings_panel.dart`: selector de tablas, avance «Fechas consultadas N de 16», tabla con columnas según `Breakpoints` (< 600: PJ, DG, Pts; 600–1199: + PG, PE, PP; ≥ 1200: + GF, GC), filas de 48 px con etiqueta accesible completa; tocar un equipo abre su ficha (`/equipos/:id`); cobertura con «Partidos sin sumar (n)» y notas del reglamento siempre visibles.
  - URL: `?vista=tabla&tabla=anual|apertura-a|apertura-b|clausura-a|clausura-b` (`FixtureRoute.parseView`, `parseTable`, `tableUri`); `urlToRestore` ahora recibe la URL objetivo (etapa o tabla).
- **Tests**: `test/features/competitions/standings/` (constructores con JSON reales 2026 y 2025, contraste con `lookuptable`, validador, `TieBreaker` con estadísticas armadas, `WatchStandings` con presupuesto), `presentation/standings_view_test.dart`, `standings_bloc_test.dart`, `test/app/standings_budget_test.dart`; Tabla en `responsive_layout_test.dart` (4 anchos) y `accessibility_test.dart` (pautas y 200 %). Helper `openTable` en `recorded_app.dart` (deja pasar los 2 min del cupo P2).

## Estado de implementación (Fase 14, 12/10/2026) — Tablas de Primera Nacional 2026

- **Catálogo** (`catalog/standings_format.dart`): `ZonedStandingsFormat` (sealed, dentro de `StandingsFormat`) reúne lo que comparten los formatos por zona: `zonesByTournament`, `regularRounds`, `interzonalsPerTeam`, `regulation`, `tournaments`. Lo implementan `LeagueZonesWithAnnual` (Primera) y **`LeagueZones`** (Nacional: `zones` zona → `idTeam`, `tieBreak`, `tableArticle`, `tieBreakArticle`, `relegationNote`; un solo torneo, `PhaseKey.regular`). `primeraNacional.standingsBySeason = {2026: …}`: zonas aprobadas (V14), rondas 1–36, 2 interzonales por equipo, desempate [DG, GF, enfrentamiento directo] (art. 112 del R.G., puntos 1 a 3; V15), Boletín 6823 como reglamento. Nacional 2025: sin formato.
- **Constructores** (`standings/table_builders.dart`): `LeagueZoneTableBuilder` (clave `zona-a`/`zona-b`, título «Posiciones 2026 · Zona A», selector «Zona A»; suma todos los partidos regulares de la temporada de cada equipo de la zona, interzonales incluidos; h2h con los partidos del torneo). `ZoneTableBuilder` y `LeagueZoneTableBuilder` usan el mismo cálculo privado (`_zoneTable`). `StandingsNotes.tieBreak(criteria, source:)` cita de dónde salen los criterios.
- **`ZoneValidator`** recibe cualquier `ZonedStandingsFormat`; en una liga de un solo torneo los mensajes no nombran el torneo («Ferro Carril Oeste no tiene zona.»).
- **`WatchStandings`**: acepta cualquier `ZonedStandingsFormat` y arma las tablas según el formato (Primera: anual + zonas; Nacional: zonas). Con las zonas sin verificar, Nacional queda sin tablas (`tables` vacía, `zoneIssues` con el motivo).
- **Presentación**: `CompetitionsPage` guarda la tabla elegida como `String?` (`null` = la primera de la competición) y la vuelve a `null` al cambiar de competición; `FixtureRoute.tableUri` omite `tabla` si es `null`. `StandingsPanel` muestra «Zonas no verificadas» si hay partidos pero ninguna tabla. `TeamBadge` (compartido) pone `key: ValueKey(url)` a la imagen (en Web, el `<img>` del modo fallback no cambiaba al cambiar la URL).
- **Tests**: `standings/nacional_tables_test.dart` (JSON reales r1–r36: 648 partidos, 34 + 2 interzonales por equipo en las rondas 7 y 25, 18 filas por zona, PJ = 2 × sumados, contraste con `lookuptable` usando `snapshot_20261012/`, caso real de desempate por DG, validador), `tie_breaker_test.dart` (regla de Nacional sin Fair Play ni sorteo), `watch_standings_test.dart` (36 en frío, 0 en caliente, zonas sin verificar), `standings_view_test.dart` (Zona A por defecto, URL, cambio de competición, «Zonas no verificadas»), `standings_budget_test.dart`, `responsive_layout_test.dart` y `accessibility_test.dart` (helper `openNacionalTable`), `test/shared/widgets_test.dart` (escudo con otra URL = otra imagen).

## Estado de implementación (Fase 15, 12/10/2026) — Más competiciones y otras competiciones del equipo (D8)

- **Catálogo**: `CompetitionDefinition.showInHome` e `inTeamIndex` (por defecto `true`). Entradas nuevas `primeraBMetropolitana` (5215, «B Metro», `SingleTableLeagueRules(matchesPerRound: 11, regularRoundsBySeason: {2026: 42})`) y `primeraC` (5524, «Primera C», 14 por fecha, sin cantidad de fechas), las dos con `showInHome: false`, `inTeamIndex: false` y sin `standingsBySeason` (→ `NoStandings`, «Sin tabla»). Federal A (5523) sigue afuera (V8). `CompetitionCatalog.all` = 5 competiciones.
- **Marcas**: `GetHomeFeed` recorre solo las `showInHome` y `EnsureTeamIndex` solo las `inTeamIndex` (filtran el catálogo recibido, así los tests pueden pasar otro). El resto de los usos (fixture, ficha, «Tus equipos», Ajustes, etiquetas) sigue con el catálogo completo: los equipos de B Metro y C entran al buscador cuando hay partidos guardados (p. ej. tras abrir su fixture) y su ficha baja sus fechas con P2.
- **Selector de competición** (`FixtureSelectors`): `ChoiceChip`s en una fila con desplazamiento horizontal (`competitionSelectorKey`) en lugar del `SegmentedButton`: 5 segmentos no entran a 360 px y, si los chips bajan de renglón, la cabecera fija del fixture desborda con texto al 200 %.
- **D8** (`teams`): entidad `TeamPointers` (próximo y último, `Match?`), `TeamRemoteDataSource.fetchNextEvent`/`fetchLastEvent` (`eventsnext` clave `events`, `eventslast` clave `results`), `TeamRepository.getTeamPointers(teamId, {forceRefresh, priority = P1})` con store propio `team_pointers` (no van a `events`: no alimentan fixtures, índice ni temporadas guardadas), clave `teamPointers:<id>` y vigencia `CacheClass.pointers` (30 min). Descarta un partido que no sea del equipo pedido. `TeamRepositoryImpl` comparte un `_cached` para `getTeam` y `getTeamPointers`.
- **Ficha**: `WatchTeamDetail` pide los punteros junto con `lookupteam` (P1; P0 en un refresco manual) y arma `TeamDetail.otherCompetitions`: los punteros de competiciones fuera del catálogo, sin repetir, con el nombre de la API (`strLeague`) y la etiqueta «Próximo partido» / «Último partido». Si fallan sin nada guardado, la ficha sigue sin la sección. Cuentan en `progress.fetched` (aviso «Ya está actualizado»). La página agrega «Otras competiciones (información parcial)» al final, con su nota, agrupada por día y **sin `onTap`** (no hay detalle).
- **Tests**: `competition_catalog_test.dart` (marcas, `NoStandings`, partidos por fecha y equipos según los JSON reales, 42 fechas de B Metro), `new_competitions_test.dart` (app completa: el Inicio no consulta 5215/5524; B Metro abre en la fecha 40 sin tabla; Primera C en la 32), `home_request_budget_test.dart` (12 con el catálogo de 5), `team_repository_impl_test.dart` (punteros: 2 peticiones, 30 min, local/visitante, no se guardan con los partidos, sin red), `watch_team_detail_test.dart` y `team_detail_sync_test.dart` (Boca en frío 27, Sudamericana como otra competición, en caliente 0, a los 31 min solo los punteros), `team_detail_page_test.dart` y `team_detail_layout_test.dart` (sección, día, sin detalle; 360/768/1280/1920 px, pautas y texto al 200 %). Helpers: `selectCompetition`, `homeCompetitions`, `recordedLastMatch`, `test/helpers/accessibility.dart`.

## Estado de implementación (Fase 16, 13/10/2026) — Ajustes, tema, aviso de espera y escudos en disco

- **Ajustes** (`settings`): `domain/entities/app_settings.dart` (`AppSettings`, `ThemePreference` = `system`/`light`/`dark`; Dart puro), `domain/repositories/settings_repository.dart` (`read`, `watch`, `saveTheme`; sin `DataResult`, como favoritos: datos solo locales), `data/models/settings_record.dart` (un valor desconocido vuelve a `system`), `data/repositories/settings_repository_impl.dart` (store `settings`, registro `app`; `saveTheme` en una transacción que conserva el resto), `presentation/bloc/settings_bloc.dart` (**global**, en `app.dart` junto a `FavoritesBloc`; `SettingsSubscribed` `restartable` y `ThemePreferenceChanged` `sequential` en handlers separados; `SettingsLoading` / `SettingsLoaded`).
- **Tema sin parpadeo**: `main` lee los ajustes (timeout 2 s) y los pasa a `FutbolArgentinoApp.initialSettings`; el `SettingsBloc` arranca ya en `SettingsLoaded`. `MaterialApp.router` está bajo un `BlocSelector` del tema (`AppTheme.modeFor`). En `/ajustes`, sección «Tema» con `RadioGroup` + `RadioListTile` antes de «Datos guardados».
- **Aviso de espera** (`core/network`): `RateLimitStatus` suma `throttledUntil` y `throttles`; `RateLimiter` los emite cuando una consulta debe esperar `throttleNoticeThreshold` (3 s) o más por el tope propio. `RateLimitNotice` sigue las dos esperas por separado (cada una con su temporizador): si hay pausa por 429, muestra esa; si no, «Muchas consultas seguidas: para no pasar el límite de TheSportsDB, se sigue en menos de un minuto.» (`secondaryContainer`).
- **Escudos** (`shared/presentation/widgets/badge_image_resolver.dart`): `BadgeImageResolver.imageFor(url)` con `NetworkBadgeImages` (red, `WebHtmlElementStrategy.fallback`) y `DiskBadgeImages` (`CachedNetworkImageProvider` con un `CacheManager` propio `team_badges`, creado con el primer escudo). `AppDependencies.create(badgeImages:)` elige por plataforma (`forPlatform`: Web → red, resto → disco); `app.dart` lo publica con el `InheritedWidget` `BadgeImages` y `TeamBadge` usa `Image(image: BadgeImages.of(context).imageFor(...))`. Sin `BadgeImages` arriba (widgets sueltos en tests) usa la red. Los tests de app pasan `NetworkBadgeImages` (la caché real necesita `path_provider`).
- **Tests**: `test/features/settings/settings_test.dart` (repositorio: predeterminado, persistencia al reabrir, cambios, valor desconocido; `bloc_test`; app completa: «Oscuro» oscurece toda la app), `settings_page_test.dart` (con el `SettingsBloc`), `test/core/network/rate_limiter_test.dart` (solo esperas ≥ 3 s; `throttledUntil` mientras dura), `test/app/rate_limit_notice_test.dart` (aviso con un `RateLimiter` real sobre el tiempo de `pump`, prioridad del 429, contraste en claro y oscuro), `test/shared/badge_image_resolver_test.dart` (red con fallback, disco con su caché, `forPlatform`, `TeamBadge` pide `/tiny` y `/small` al resolver).

## Estado de implementación (Fase 17, 13/10/2026) — Compartir, agregar al calendario y auto-refresco en vivo

- **Calendario** (`core/calendar/`, Dart puro): `CalendarEvent` (`uid`, `title`, `description`, `location`) con `CalendarEventTime` sealed = `TimedEvent(startUtc, endUtc)` / `AllDayEvent(CalendarDay)`. `IcsBuilder.build(event, stampUtc:)`: VCALENDAR con un VEVENT, horas en UTC (`…Z`), día completo con `VALUE=DATE` y fin exclusivo, texto escapado (`\ ; , 
`), líneas plegadas a 75 bytes UTF-8 y CRLF.
- **Acciones externas** (`core/platform/`): `ExternalActions` (`share(text, subject:)` → `ShareOutcome` `shared`/`dismissed`/`copied`/`failed`; `addToCalendar(event, fileName:)` → `CalendarOutcome` `opened`/`downloaded`/`failed`) y `PlatformExternalActions`: `share_plus` sin la alternativa `mailto:` (si falla, `Clipboard`); Android con `add_2_calendar` (`androidEvent`: con hora, instantes UTC y zona `America/Argentina/Buenos_Aires`; día completo, de medianoche a medianoche de Argentina), Web con `downloadTextFile` (movido desde `diagnostics`). `AppDependencies.create(externalActions:)` y `RepositoryProvider<ExternalActions>` en `app.dart`.
- **Detalle del partido** (`match_detail/presentation/formatters/match_detail_texts.dart`): `MatchDetailTexts.share` (equipos o resultado, «Competición · Fase · Etapa», día y hora de Argentina o «Horario por confirmar» / «Final · día» / «En juego · actualizado a las HH:mm», estadio y «Horarios de Argentina · Datos de TheSportsDB»), `calendarEvent(detail, now)` (`null` si no está programado, no tiene fecha o ya empezó; con hora, 2 h; sin hora confirmada, día completo con la aclaración en la descripción), `calendarFileName`, y `phaseAndStage` (antes privado de la página). En `_DetailBody`, `_ShareActions`: «Compartir» y «Agregar al calendario» (o «… (todo el día)») con avisos `SnackBar` de copiado, descarga o error; igual en la pantalla y en el panel de escritorio.
- **En vivo (D11)**: `MatchGrouping.isLive(m, now)` (en juego según la API, o empezado hace < 3 h sin terminar) y `anyLive`; `RoundCachePolicy` usa la misma regla para la clase `live`. `LiveAutoRefresh` (`shared/presentation/widgets/live_auto_refresh.dart`): `Timer.periodic` de `CacheClass.live.ttl + 5 s` que corre solo con `TickerMode` encendido y la app visible (`AppLifecycleListener`); en cada aviso evalúa `hasLiveMatches()` y llama a `onTick`; al volver a verse se pone al día una vez. Eventos nuevos: `HomeLiveTick`, `FixtureLiveTick` (solo con la etapa cargada), `MatchDetailLiveTick`, `TeamDetailLiveTick` (todos cargan sin forzar). Pantallas: Inicio (partidos de las competiciones, sin «Tus equipos»), fixture (solo la vista «Fixture»), detalle (pantalla y panel) y ficha (próximos y disputados, sin «Otras competiciones»). `hasLiveMatches` devuelve `false` mientras la pantalla carga.
- **Tests**: `test/core/calendar/ics_builder_test.dart` (formato, día completo, escape, plegado UTF-8), `android_calendar_event_test.dart`, `test/features/match_detail/match_detail_texts_test.dart` (textos y eventos con partidos reales: terminado, en juego, programado, 00:00 UTC), `match_detail_actions_test.dart` (pantalla con un `ExternalActions` falso: compartir, copiado, descarga del `.ics`, día completo, terminado sin calendario, texto al 200 %), `test/features/matches/domain/match_grouping_test.dart` (`isLive`), `test/shared/live_auto_refresh_test.dart` (intervalo, sin partidos en vivo, oculta, segundo plano, cierre), `test/app/live_refresh_test.dart` (app completa: peticiones por aviso en Inicio, fixture y detalle; 0 con el Inicio oculto) y en `team_detail_sync_test.dart` (aviso en la ficha de Boca = 1 petición).

## Estado de implementación (Fase 18, 13/10/2026) — Calendario mensual

- **Dominio**: `CalendarMonth` (`core/time/calendar_month.dart`, Dart puro: `yyyy-MM`, largo, `addMonths`, `weeks` de lunes a domingo). `MonthCalendar` (`competitions/domain/calendar/month_calendar.dart`): `of(month, matches)` agrupa por `Kickoff.argentinaDay` con `MatchGrouping.byArgentinaDay` (deduplicado y ordenado como en el resto de la app); `defaultDay(today)` (en el mes de hoy: hoy, el próximo o el último con partidos; en otro mes, el primero); `undated` («Fecha por confirmar», fuera de todo mes); `monthsWithMatches`, `initialMonth` (el de hoy si cae dentro de la temporada guardada; si no, el más cercano con partidos; sin partidos, el de hoy o el último/primero del año de la temporada) y `navigableRange`.
- **Caso de uso** `WatchCompetitionCalendar` (`domain/usecases/watch_competition_calendar.dart`) → `Stream<CompetitionCalendar>` (partidos guardados, `labels` = fase y etapa por `idEvent`, `roundsTotal`, `roundsStored`, `roundsPending`, `SyncProgress`). Usa `CompleteRounds` con el nuevo `fetch: false` (una emisión, sin red: lo guardado y el estado de cada ronda) salvo con `download` o `forceRefresh`. Los rótulos salen de `PhaseResolver.classifyRound` por ronda guardada + `StageLabeler.describe` (sin red). `RefreshRecentRounds` (nuevo, extraído de `WatchStandings`) fuerza con P0 las rondas con partidos sin terminar de ayer y hoy; lo usan las tablas y el calendario.
- **Presentación**: `CalendarBloc` (`Started` / `CompletionRequested` / `RefreshRequested` y `_Continued` / `_Reloaded` por `restartable`; `Paused` / `Resumed` en handlers propios). `Resumed` sigue una descarga pausada; si no, vuelve a leer lo guardado; si llega durante una carga, la relectura se hace al terminarla (cortar la lectura en curso dejaba trabada la cola de `restartable` en los tests con `FakeAsync`). `CalendarPanel` (`widgets/calendar_panel.dart`): aviso de cobertura o avance (`InfoBanner`, ahora compartido con la Tabla), «‹ Mes ›», grilla de 7 columnas (celdas de 56 px, solo los días con partidos se pueden tocar; etiqueta accesible «Domingo 11/10/2026, hoy: 5 partidos»), chip «Fecha por confirmar (N)» si hay partidos sin fecha, y los partidos del día con `matchDayItems`; ≥ 1200 px, grilla a la izquierda (480 px) y partidos a la derecha; el partido se abre en su pantalla.
- **Página**: `CompetitionsView.calendar`, `FixtureRoute.calendarUri`/`parseMonth` (`vista=calendario&mes=2026-10`); el mes vive en la página (vuelve a `null` al cambiar de competición o temporada). El listener del fixture también reacciona a un `fetchedAt` nuevo de la etapa mientras se ve el calendario (manda `CalendarResumed`: relee lo guardado). Selector `Fixture · Tabla · Calendario`: sin íconos en teléfonos; con texto agrandado (escala > 1,3) se desplaza en horizontal.
- **Tests**: `test/core/time/calendar_month_test.dart`, `test/features/competitions/domain/month_calendar_test.dart` (Primera 2026 real: 495 partidos en 10 meses, junio vacío, día por defecto, mes inicial), `watch_competition_calendar_test.dart` (repositorios reales: 0 al abrir, 17/36/6 en frío, 0 en caliente, sin red, rótulos), `presentation/calendar_bloc_test.dart`, `presentation/calendar_view_test.dart` (grilla, días, meses, URL, «Completar» con P2, Copa, escritorio, fixture de fondo), `test/app/calendar_budget_test.dart` (app completa) y el calendario en `responsive_layout_test.dart` y `accessibility_test.dart` (pautas y texto al 200 %). Helper `openView` en `recorded_app.dart`.
