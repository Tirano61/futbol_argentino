# CLAUDE.md — Fútbol Argentino

App Flutter (Android + Web) de uso personal para consultar partidos del fútbol argentino con datos de TheSportsDB. Sin login, sin backend propio, sin servicios pagos.

## Documentación
- `docs/PLAN.md` — plan maestro v2 y roadmap por fases/tareas (fuente de verdad).
- `docs/ARCHITECTURE.md` — estructura DDD, modelo de dominio, pantallas, BLoC.
- `docs/API.md` — endpoints verificados, topes de la clave gratuita, hallazgos de datos.
- `docs/DATA_STRATEGY.md` — carga por rondas, TTL, merge, sincronización incremental.
- `docs/DECISIONS.md` — decisiones y alternativas.
- `docs/HITO_C.md` — plan detallado del Hito C v3 (Fases 11–19, post-MVP).

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
- Con `restartable`, un evento que solo cancela (p. ej. pausar) va en su propio handler: si pasa por `restartable`, los eventos siguientes esperan a que termine la cancelación de la carga en curso. Tampoco reemplazar una carga en curso solo para releer lo guardado (en los widget tests la cola quedó trabada): anotarlo y releer al terminar (`CalendarBloc`).
- `domain/` es Dart puro: sin imports de `flutter`, `http` ni `sembast`.
- Sin HTTP en widgets, sin lógica de negocio en presentation, sin DTO/JSON en pantallas.
- El parsing de JSON vive en los DTO (`fromJson`); mappers DTO → entidad.
- Repositorios devuelven `DataResult<T>` / `Stream<DataResult<T>>` y traducen errores a `Failure`.
- DI: composition root manual (`lib/app/di/app_dependencies.dart`) + `RepositoryProvider`. Sin `get_it`.
- Textos de UI en español rioplatense. Evitar sobreingeniería.

## Datos clave de TheSportsDB
- Base: `https://www.thesportsdb.com/api/v1/json/123/` (clave en `--dart-define=TSDB_API_KEY`, por defecto `123`).
- Ligas: Primera División `4406`, Primera Nacional `4616`, Copa Argentina `4500`, Primera B Metropolitana `5215`, Primera C `5524`, Copa Libertadores `4501`, Copa Sudamericana `4724`. Federal A (`5523`) no entra sin un relevamiento propio (V8).
- Copas internacionales (D23, Hito D en `docs/HITO_D.md`): `ContinentalCupRules` con etapas **por temporada** (ronda + ventana de días argentinos; los códigos cambian entre años y en 2026 las previas comparten `r=1–3` con los grupos). Fases `qualifying`/`groups`/`knockoutStage` (URL `previa`/`grupos`/`eliminatorias`). Sin ventana → `undetermined`; etapa sin datos (final 2026) sin ventana → «inferido» si es la única de su ronda. Fuera del Inicio y del índice; Tabla en D4, Llaves en D5; la ficha de equipo no las sincroniza hasta D6 (sus punteros siguen en «Otras competiciones» hasta que se guarda la ronda). Tests con las grabaciones de D1: `pumpApp(now: continentalRecordingTime)`; presupuestos en `test/app/continental_budget_test.dart`.
- Marcas del catálogo: `showInHome` (Inicio) e `inTeamIndex` (bootstrap del índice). B Metro y Primera C van sin las dos y sin tabla (`NoStandings`).
- Categorías (D22): `CompetitionCategory` obligatoria en cada entrada; `CompetitionCatalog.byCategory` omite las vacías. Selector `CompetitionPicker` (< 600 botón + hoja en el navegador raíz; ≥ 600 chips categoría → competición). Las vistas Tabla/Llaves se ofrecen solo si `hasStandings`/`hasBracket`; un `vista=` no disponible abre el Fixture. En tests, `selectCompetition(tester, shortName)` deriva la categoría.
- Límite: 30 peticiones/minuto (HTTP 429). Sin paginación. Fuente principal: `eventsround.php?id=&r=&s=`.
- Primera: cada `r` (1..16) trae **Apertura y Clausura juntos**; `r=0` = eliminatorias; `r=16` incluye octavos. La fase se resuelve con el catálogo por temporada (`PhaseResolver`); si no hay evidencia → `undetermined`.
- Copa: rondas `64, 32, 16, 125 (cuartos), 150 (semis), 200 (final)` (V2 validada con la final 2025).
- Inicio (`GetHomeFeed`): por competición con `showInHome`, punteros + ≤ 2 rondas (último partido + etapa siguiente) → ≤ 12 peticiones en frío, 0 en caliente. No agregar consultas ni competiciones al Inicio sin revisar ese presupuesto (test `home_request_budget_test.dart`).
- Equipos: índice local derivado de los partidos guardados + bootstrap de la primera etapa de cada competición con `inTeamIndex` (3 peticiones). Ficha: `lookupteam` + punteros del equipo (`eventsnext`/`eventslast`, TTL 30 min, store `team_pointers`; D8) + rondas de la temporada con P2 (Boca en frío = 27 peticiones, en caliente 0; test `team_detail_sync_test.dart`). Los punteros de competiciones fuera del catálogo se muestran en «Otras competiciones (información parcial)», sin detalle; nunca se guardan en `events`.
- Favoritos: solo locales (store `favorites`, `FavoritesBloc` global). «Tus equipos» del Inicio lee lo guardado: 0 peticiones (tests `watch_favorite_teams_test.dart`, `home_page_test.dart`).
- Historial (`CompleteRounds`, P2): nunca pide lo vigente; las rondas cerradas y las de temporadas anteriores terminadas no se vuelven a pedir salvo refresco manual. Primera 2026 completa = 17 (fechas 1–16 + ronda 0), Nacional 36, Copa 6; en caliente 0 (test `complete_rounds_test.dart`).
- Datos guardados (`/ajustes`): borrado manual por temporada; la actual no se puede borrar; favoritos intactos. Sin purga automática de temporadas; la de `removed` verificados está pospuesta (falta la verificación con `lookupevent`).
- Tablas (`competitions/domain/standings/`, formato en el catálogo con `StandingsFormat`): Primera 2026 = Tabla Anual (art. 24, **sin enfrentamiento directo**) + zonas A/B por torneo (art. 9/10 y 15/16, con enfrentamiento directo); Fair Play y sorteo no se calculan → «posición compartida». La app no define descensos. Solo rondas 1–16 (16 peticiones en frío, 0 en caliente). Nacional 2026 (`LeagueZones`) = una tabla por zona A/B de 18, interzonales incluidos, desempate art. 112 del R.G. puntos 1 a 3 (DG, GF, enfrentamiento directo; **sin Fair Play ni sorteo**); rondas 1–36 (36 en frío, 0 en caliente). Copa y temporadas sin formato verificado: sin tabla.
- Identificadores: `idEvent` (partidos, deduplicación), `idTeam` (equipos), `idLeague`.
- Calendario mensual (D20): vista «Calendario» de Competiciones; lee solo lo guardado (0 peticiones al abrirse) y «Completar» usa `CompleteRounds` (P2) solo si se pide. No sumar fuentes ni descargas automáticas sin revisar el presupuesto (`test/app/calendar_budget_test.dart`).
- Llaves (D21): vista «Llaves» de Competiciones; rondas del cuadro en el catálogo (`bracketRounds`: Primera 16 y 0, Copa sus 6). Carga como la Tabla (P2): Primera en frío = 2, Copa = 6, en caliente 0 (`test/app/bracket_budget_test.dart`). Las llaves se ordenan por los equipos de cada partido y se unen solo con evidencia; quién avanza (`TieOutcome`): resultado, tanda (`intHomeScoreExtra`/`intAwayScoreExtra`, solo con `PEN`) o el equipo que juega la ronda siguiente; sin evidencia no se dice. Nacional sin cuadro hasta la Fase 19.2.
- En vivo (D11): `MatchGrouping.isLive` (la misma regla que la clase `live` de `RoundCachePolicy`). `LiveAutoRefresh` avisa cada 2 min 5 s solo con la pantalla visible (`TickerMode`), la app en primer plano y partidos en vivo; el aviso (`…LiveTick`) es una carga **sin forzar** (la vigencia decide). No avisar con la pantalla cargando: en un BLoC `restartable` cancelaría la carga. Presupuesto en `test/app/live_refresh_test.dart`.
- Compartir y calendario: siempre por `ExternalActions` (`core/platform`, inyectado; en tests uno falso). `IcsBuilder` en `core/calendar` (Dart puro). Solo se agenda un partido programado que no empezó; hora sin confirmar → día completo. Android, día completo: de medianoche a medianoche **de Argentina** (Google Calendar toma la zona del dispositivo y el fin exclusivo).

## Responsive y accesibilidad
- Anchos en `Breakpoints` (`lib/shared/presentation/layout/breakpoints.dart`): < 600 navegación inferior · 600–1199 riel · ≥ 1200 escritorio (riel extendido, buscador en la barra, Inicio en 2 columnas, fixture con panel de detalle, contenido hasta 1200 px). La tablet a densidad 160 da 800 px en vertical y 1280 px en horizontal (escritorio).
- Tests de layout y accesibilidad de la app completa con `pumpApp` (`test/helpers/recorded_app.dart`): 360/768/1280/1920 px, pautas `meetsGuideline` y texto al 200 %. Un desborde falla el test.
- Un `SnackBar` con acción queda fijo por defecto en este Flutter: usar `persist: false`.
- `CompetitionPicker`: desde 600 px usa chips de categoría solo si entran en una línea (mide su ancho); si no (fixture con panel de detalle a 1280 px, texto grande), el botón con la hoja. Con la fuente de los tests (14 px por letra) casi nunca entran: los tests que dependen de anchos reales cargan Roboto con `setUpAll(loadRealFonts)` (`test/helpers/real_fonts.dart`).

## Paquetes nativos
- Después de agregar un plugin, `flutter clean` antes del build Web: la compilación puede reutilizar un `web_plugin_registrant.dart` viejo y el plugin da `MissingPluginException` (visto con `share_plus`).
- `add_2_calendar` fijado en 3.0.1 (la 3.1.x requiere un AGP/Kotlin más nuevo). `cached_network_image` solo en Android: en Web falla por CORS.
- Grabaciones nuevas que repiten una consulta ya grabada: en una carpeta de instantánea (`test/fixtures/api/snapshot_AAAAMMDD/`), nunca pisando los archivos que usan los tests.

## Escudos
- Siempre mediante `TeamBadge`, que pide la imagen al `BadgeImageResolver` de la app (`BadgeImages`, `lib/shared/presentation/widgets/badge_image_resolver.dart`): Android = `CachedNetworkImageProvider` (caché en disco `team_badges`); Web = `NetworkImage(..., webHtmlElementStrategy: WebHtmlElementStrategy.fallback)`: `r2.thesportsdb.com` no envía CORS y en Web la carga normal falla (validado en T0.2).
- Los tests de la app completa pasan `badgeImages: const NetworkBadgeImages()` a `AppDependencies.create`: la caché en disco necesita `path_provider` (en tests da `MissingPluginException`).
- La `Image` lleva `key: ValueKey(url)`: en Web, el `<img>` del fallback no cambia si una imagen montada recibe otra URL (las filas de una tabla que se reordena quedaban con el escudo de otro equipo).
- Variantes de tamaño: `/tiny` (listas), `/small` (fichas).

## Horarios
- Mostrar siempre en `America/Argentina/Buenos_Aires` = UTC−3 fijo. Nunca usar la zona del dispositivo.
- `strTimestamp` es UTC sin zona. `strTimeLocal` no es fuente (es inconsistente).
- Hora `00:00` UTC sin corroboración → «Horario por confirmar» (regla conservadora D5).
- Formatos: fecha `dd/MM/yyyy`, hora `HH:mm`.

## Mantenimiento periódico
- Cada semestre: actualizar en `CompetitionCatalog` (`lib/features/competitions/domain/catalog/competition_catalog.dart`) las ventanas de Primera **a partir de datos reales grabados** en `test/fixtures/api/`. Pendiente: cierre y eliminatorias del Clausura 2026 (hoy «en curso»), temporada 2027.
- Al cerrar una ventana, el test `competition_catalog_test.dart` verifica que cada partido grabado caiga en un solo torneo.
- Revisar los pendientes V2–V7 y V15 de `docs/API.md` cuando haya datos nuevos.
- Cada temporada: zonas con `idTeam` y reglamento (desempates) de Primera y de Nacional, verificados contra los partidos grabados (ver V12/V14 en `docs/API.md`), cargados en `standingsBySeason` del catálogo; el test `table_builders_test.dart` los valida con `ZoneValidator`.

## Comandos
- `flutter analyze` · `flutter test`
- `flutter run -d SOP10X2501001122` (tablet) · `flutter run -d chrome`
- Web release con diagnóstico: `flutter build web --dart-define=DIAGNOSTICS=true`; probar en la tablet con `adb reverse tcp:8080 tcp:8080` y `http://localhost:8080/`.
- La pantalla de diagnóstico está en `/diagnostico` (botón 🐞 en Inicio, solo en debug o con `DIAGNOSTICS=true`).
- Sin API (caída de TheSportsDB): `tool/recorded_app/main.dart` arma la app con las respuestas grabadas (base en memoria, reloj de la grabación de D1, banda «DATOS GRABADOS»). Android: `adb push test/fixtures/api/. /sdcard/Android/data/com.example.futbol_argentino/files/fixtures/` + `chmod 755` de esa carpeta, y `flutter build apk --release -t tool/recorded_app/main.dart`. Web: `flutter build web --release -t tool/recorded_app/main.dart` y copiar los JSON a `build/web/fixtures/`. Reinstalar después el APK normal y borrar `build/web/fixtures/`.

## Inspección de datos (Windows)
- Al revisar JSON con Python desde un pipe, decodificar explícitamente como UTF-8 (`sys.stdin.buffer.read().decode('utf-8')`): por defecto usa cp1252 y simula «mojibake» que la API no tiene.

## Datos locales
- sembast: archivo en Android, IndexedDB en Web (`lib/core/storage/local_database.dart`). Tests: `newDatabaseFactoryMemory()`.
- Ajustes (tema): store `settings`, `SettingsBloc` global; `main` los lee antes de `runApp` para que el tema no parpadee.
- Los repositorios son stale-while-revalidate; los TTL están en `CacheClass`. Todo refresco pasa por `SyncScheduler` (P0 visible, P1 contexto, P2 equipo: 10/min, de a uno, en pausa con la app oculta, cancelable con `CancelToken`).
- Cuidado con `whenComplete(() => map.remove(key))`: si devuelve el Future quitado, `whenComplete` lo espera y se bloquea. Usar cuerpo de bloque.

## Contrato de red y errores
- Todo HTTP pasa por `TheSportsDbClient.getJson` (rate limiter 25/min, timeout 15 s, reintentos solo transitorios).
- Data lanza `ApiException`; los repositorios lo convierten con `toFailure()`. Presentation solo ve `Failure` y `DataResult`.
- Los tests de red usan `MockClient` + `FakeClock` (`test/helpers/`) y JSON reales de `test/fixtures/api/`.
- En `testWidgets`, toda llamada directa a sembast va dentro de `outsideFakeAsync` (`test/helpers/favorites.dart`, usa `tester.runAsync`); si no, el test se cuelga.
- `tester.pageBack()` busca «Back»: con la app en español, tocar `find.byTooltip('Atrás')`. Con la vista de 6000 px de alto, «deslizar para actualizar» necesita un arrastre largo (≥ 25 % del alto).
- Con la app completa, el cierre del stream de la carga inicial del Inicio se agenda fuera de `FakeAsync`: antes de otro evento al `HomeBloc` (`droppable`), `await tester.runAsync(() => Future<void>.delayed(Duration.zero))`; si no, se descarta.
- Durante una pausa por 429, o una espera de 3 s o más por el tope propio (25/min), la app muestra `RateLimitNotice`; `pumpAndSettle` avanza el tiempo mientras gire un indicador de carga (puede pasar de largo la pausa).
