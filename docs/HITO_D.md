# Hito D — Plan Maestro: Copa Libertadores, Copa Sudamericana y selector por categorías

> **Aprobado por el usuario el 14/10/2026, con ajustes** (corte temprano solo con evidencia, D7 sin depender de las finales 2026, reglamentos oficiales). Se trabaja por fases: tarea por tarea dentro de cada fase y aprobación antes de la siguiente. Sin commits ni PR (los hace el usuario).
>
> **Estado:** Fases D1, D2 y D3 terminadas y aprobadas (14 y 15/10/2026). Fase D4 terminada (15/10/2026), esperando aprobación para D5. Resultados en «Resultado de la Fase D1» … «… D4» (§10).

## Contexto
La app cubre el fútbol argentino (Primera, Nacional, B Metro, C, Copa Argentina) con fixture, tablas, calendario, llaves, fichas y favoritos sobre la API gratuita de TheSportsDB. El usuario quiere sumar **Copa Libertadores y Copa Sudamericana completas** (no solo los partidos de equipos argentinos) y ordenar el selector de competiciones en **cuatro categorías**. Hoy la Sudamericana solo aparece como «Otras competiciones» en la ficha de un equipo.

El desafío es el formato: fases previas, grupos y eliminatorias de ida y vuelta, con códigos de ronda que cambian entre temporadas, grupos que la API informa a medias y penales incompletos. El plan reutiliza el catálogo, `PhaseResolver`, tablas por zonas, el cuadro de la Fase 19.1 y `SyncScheduler` sin crear un sistema paralelo. No suma peticiones al Inicio y no muestra nada sin evidencia.

Decisiones del usuario ya tomadas: **Federal A fuera del Hito D (anotado)**, **selector mixto según el ancho**, **búsqueda de extranjeros con arranque bajo demanda**.

## 1. Estado real de la implementación existente

### 1.1 Catálogo (`lib/features/competitions/domain/catalog/competition_catalog.dart`)
- `CompetitionDefinition` (L170): `id, name, shortName, format (league|cup), rules, standingsBySeason (año → StandingsFormat), showInHome, inTeamIndex`; derivados `standingsFor`, `bracketRounds` (L207), `phases` (L217), `expectedMinimumMatches` (L226).
- `CompetitionRules` **sealed** (L58) con 3 variantes: `SplitSeasonLeagueRules` (Primera), `SingleTableLeagueRules` (Nacional, B Metro, C), `KnockoutCupRules` (Copa: `CupRound{code,label,matches,verified}`, fijos para toda temporada).
- Entradas: 4406, 4616, 4500, 5215, 5524. **Federal A (5523) no está** (V8/D19: la API mezcla etapas en la numeración). `all` en L549, `byId` L557, `supportedSeasons` = actual + anterior (D10).
- Temporada: `Season(int year)`, solo `^\d{4}$`. Sudamericana ya está grabada como `"2026"` (`test/fixtures/api/lookupleague_4724.json`, `eventsnext_135156.json` con `intRound "150"`, `strGroup ""`).
- **No hay categorías**: la UI recorre `CompetitionCatalog.all` como lista plana en `presentation/widgets/fixture_controls.dart:46` (ChoiceChips horizontales) y `home/presentation/pages/home_page.dart:459` (ActionChips). También la usan búsqueda de equipos (`team_search_page.dart:142,209`), diagnóstico y los casos de uso por defecto.

### 1.2 Fases y etapas (`competitions/domain/`)
- `PhaseKey { apertura, clausura, regular, unica, undetermined }`; `StageKind { regular, knockout }` — **no existe «grupos» ni «fase previa»**.
- `Stage { competitionId, season, phase, apiRound, kind, label, order }`: una etapa = una ronda de la API.
- `PhaseResolver.classifyRound` (`services/phase_resolver.dart`): switch por las 3 reglas. Copa → siempre `(unica, knockout)`. `_enforceOneMatchPerTeam` (L157) invalida rondas donde un equipo juega dos veces (rompería una ronda con ida y vuelta si no se excluye).
- `RoundNavigator.stagesFor`, `StageLabeler` («Fecha N», etiqueta de copa, «Ronda N»), `bracketRounds`, `phases`, `expectedMinimumMatches`: hacen `switch` sobre las reglas → **una 4.ª variante obliga (en compilación) a cubrir cada switch**. `CompleteRounds.seasonRounds` (L180) no hace switch: pasa por `stagesFor`.
- ⚠ `expectedMinimumMatches(int apiRound)` y `StageLabeler.label/describe` **no reciben temporada**; para las copas el significado de una `r` cambia por temporada.
- ⚠ `FixtureRoute._phaseNames` (`fixture_route.dart:21`) es un mapa constante usado con `!` (L130): un `PhaseKey` nuevo compila y **se cae en Web** al armar la URL.
- `_enforceOneMatchPerTeam` solo mira partidos `regular`: las series (`knockout`) no lo disparan.
- `WatchStageMatches` (L57) clasifica la ronda entera y filtra por `(phase, kind)` de la etapa: el mismo mecanismo separará Fase 1 de Fecha 1 en `r=1`.

### 1.3 Tablas (`competitions/domain/standings/`, `catalog/standings_format.dart`)
- `StandingsFormat` sealed: `NoStandings`, `ZonedStandingsFormat` (sealed) → `LeagueZonesWithAnnual` (Primera), `LeagueZones` (Nacional). Zonas = `Map<PhaseKey, Map<String, Set<int idTeam>>>`, `interzonalsPerTeam`, `RegulationSource`.
- `TeamStats`/`StatsAccumulator` (dedupe por `idEvent`), `TieBreaker` con `goalDifference, goalsFor, headToHead (recursivo en subgrupos), fairPlay/drawOfLots (no computables → posición compartida)`.
- `StandingsTable`, `StandingsCoverage` («Fechas consultadas X de Y», «Partidos sin sumar»), `ZoneValidator`, `_zoneTable` reutilizable; `WatchStandings._build` (L181) hace switch por formato.
- **Faltan** para CONMEBOL: criterio «goles como visitante» (2025) y el directo **sin recursión** (2026).

### 1.4 Llaves (Fase 19.1: `domain/knockout/knockout_bracket.dart`, `matches/domain/services/tie_outcome.dart`)
- **Solo partido único**: `BracketRound{label, apiRound, matches}`, `BracketSlot{match, outcome, qualified, linkedToNext}`, `TieOutcome.of(Match)` mira un solo partido (resultado → penales con `PEN` → aparece en ronda posterior). El pie dice «Cada llave se juega a un partido» (`bracket_panel.dart:243`).
- El constructor ordena hacia atrás desde la final por equipos, une solo con evidencia, deja `unplaced` y `pairingUnknown`. `forSeason` (L158) filtra por `PhaseResolver` (solo `knockout`).
- Consumidores: `WatchKnockoutBracket`, `GetMatchDetail` (L62, «avanza» en detalle), `MatchCard` (L38, «Avanza X» solo con penales).

### 1.5 Partido (`matches/domain/entities/match.dart`, `data/models/event_dto.dart`)
- `Match{id, competitionId, season, apiRound, home, away, kickoff, status, score, penalties, …, membership}`. **Sin grupo ni etapa** (decisión de Fase 2: la fase no se guarda).
- **`strGroup` no se parsea** (V8: ningún evento de las ligas argentinas lo trae; solo `lookuptable`).
- `MatchStatusMapper`: FT/AET/PEN/live/PST/CANC/…; `penalties` solo con `PEN` y ambos `…ScoreExtra`.

### 1.6 Rutas y pantalla Competiciones
- go_router con `StatefulShellRoute.indexedStack` (`lib/app/router/app_router.dart`); `/competiciones` y `/competiciones/:leagueId` (hermana, `ValueKey(uri)`).
- URL (`presentation/routing/fixture_route.dart`): `?temporada=&fase=&ronda=&etapa=eliminatoria`, `vista=tabla&tabla=apertura-a`, `vista=calendario&mes=2026-10`, `vista=llaves&llave=apertura`. `parse` cae en Primera si el id no está en el catálogo.
- La selección no se persiste: la mantiene la rama del `indexedStack`; en Web, `_updateUrl` (`competitions_page.dart:326`) reemplaza la URL en cada cambio y la recarga la vuelve a leer; `_restoreUrl` (L334).
- Vistas: `_ViewSelector` (`competitions_page.dart:537`), `SegmentedButton` con las 4 vistas **siempre visibles**; cada panel muestra «Sin tabla»/«Sin cuadro de llaves» si no aplica.
- BLoCs: `CompetitionFixtureBloc` (restartable, prefetch de la etapa siguiente), `StandingsBloc`, `CalendarBloc`, `BracketBloc` (Paused/Resumed aparte).
- Navegación de rondas: `StageNavigator` (prev/next + `DropdownButton<Stage>`), temporada `DropdownButton<Season>`, chips de fase si `phases.length > 1`.
- Layout: `AdaptiveShell` (barra < 600, riel 600–1199, riel extendido ≥ 1200); en ≥ 1200 el Fixture tiene panel de detalle de 440 px.

### 1.7 Datos y sincronización
- `MatchRepository` (`matches/domain/repositories/match_repository.dart`) / impl: claves `round:<id>:<s>:<r>`, `event:<id>`; `eventsround` → `EventMapper` → `RoundMergePolicy.merge` (dedupe por `idEvent`, aunque cambie de ronda) → `QueryMetadata{fetchedAt, cacheClass, quality}`.
- `SyncScheduler` (`core/sync/sync_scheduler.dart`): une trabajos en vuelo por clave, P0/P1/P2 (P2 10/min, de a uno, en pausa con la app oculta), `CancelToken`.
- `CacheClass` (live 2 min … closed 30 d), `RoundCachePolicy.classify`, `QueryMetadataStore`. `TheSportsDbClient` + `RateLimiter` 25/min, pausa 60 s ante 429, `RateLimitNotice`.
- `CompleteRounds`: `seasonRounds` = unión de etapas del navegador; clasifica missing/fresh/stale/settled/historic; P2; progreso; se corta ante error; `fetch:false` para el calendario.
- Punteros de liga: `eventsnextleague` + `eventspastleague` (`competition_repository_impl.dart:80`).

### 1.8 Equipos, favoritos, Inicio
- Índice: `storedTeams` = equipos de **todos** los eventos guardados (de cualquier liga) + bootstrap `EnsureTeamIndex` (r1 Primera, r1 Nacional, r64 Copa = 3 peticiones). ⚠ Guardar rondas de Libertadores mete clubes extranjeros al índice.
- Búsqueda: índice local; si no hay resultado y ≥ 3 letras, `searchteams.php` filtrando `strCountry == 'Argentina'` (`team_dto.dart:45`).
- Ficha (`WatchTeamDetail`): `lookupteam` + punteros `eventsnext/eventslast` + bootstrap + `_plan` P2 de todas las rondas de las competiciones del catálogo donde el equipo tiene partidos guardados (Boca en frío = 27). `_otherCompetitions` (L218) = punteros fuera del catálogo → «Otras competiciones». ⚠ Boca grabado: `eventsnext_135156.json` = Sudamericana r150 2026 vs Vasco; al entrar 4724 al catálogo se rompen `team_detail_sync_test.dart:142`, `watch_team_detail_test.dart:88`, `team_detail_page_test.dart:225`, `team_detail_layout_test.dart:44`.
- Favoritos locales; «Tus equipos» solo lee lo guardado (0 peticiones).
- `GetHomeFeed`: solo `showInHome` (≤ 12 en frío). `home_request_budget_test.dart:92` afirma `CompetitionCatalog.all` con 5 entradas; `competition_catalog_test.dart:15` la lista exacta de ids; `competitions_page_test.dart:143` cuenta `ChoiceChip`s; `selectCompetition` (`test/helpers/recorded_app.dart:114`) busca chips por `shortName` (Copa Argentina = `'Copa'`, ambiguo con las nuevas copas).

### 1.9 Fixtures de prueba
- `test/fixtures/api/` plano + `snapshot_20261012/`; `README.md` con tabla (consulta, HTTP, registros, hora UTC, SHA-256). Grabación manual con `curl` (~17/min), sin script. Hay `lookupleague_4724.json`; **nada de rondas de 4724 ni de Libertadores**.
- Helpers: `recorded_api.dart` (`recordedFixtureFor(Uri)`), `recorded_app.dart` (`pumpApp` a las 17:00 ART del 11/10/2026), `fixtures.dart`.

### 1.10 Docs
- HITO_C: Fases 11–18 ✅; 19.1 ✅ (esperando aprobación); **19.2 pendiente** (Reducido de Nacional, playoffs del Clausura, final de Copa 2026; nov–dic 2026); 19.3 pendiente (reglamento 2027).
- D8: Sudamericana hoy solo aparece como «Otras competiciones (información parcial)» en la ficha de equipo. D19: Federal A fuera.

## 2. Investigación de Libertadores y Sudamericana en TheSportsDB

Relevamiento del 14/10/2026 (~125 GET a la clave `123`) y, en D1, **58 respuestas grabadas** en `test/fixtures/api/` (V16–V21 de `docs/API.md`; detalle por etapa, grupos y series en `docs/evidence/d1_grupos_y_etapas.md`).

### 2.1 Identificadores y temporadas
| idLeague | strLeague | strCountry | strCurrentSeason | Temporadas |
|---|---|---|---|---|
| **4501** ✅ | Copa Libertadores | Worldwide | 2026 | `"2025"`, `"2026"` (formato `YYYY`, compatible con `Season`) |
| **4724** ✅ | Copa Sudamericana | Worldwide | 2026 | ídem |

`search_all_seasons` corta en 5 (2018–2022 / 2020–2024): no sirve. Se consulta `s=` directo.

### 2.2 Códigos de ronda verificados (`eventsround.php?id=&r=&s=`)
Se probaron r = 0–8, 16, 32, 64, 100, 125, 150, 160, 170, 180, 200, 300, 400, 500. Los conteos coinciden con el formato real (sin truncamiento visible) y ningún `idEvent` aparece en dos rondas.

| r | Lib 2025 | Lib 2026 | Sud 2025 | Sud 2026 |
|---|---|---|---|---|
| 400 | Fases 1+2+3 (30, feb–mar) | — | Primera fase (16, mar) | — |
| 1 | Grupos F1 (16) | **Fase 1 (6, feb) + Grupos F1 (16, abr)** | Grupos F1 (16) | **Primera fase (16, mar) + Grupos F1 (16, abr)** |
| 2 | Grupos F2 (16; 1 `WO`) | **Fase 2 (16, feb) + Grupos F2 (16)** | Grupos F2 | Grupos F2 |
| 3 | Grupos F3 | **Fase 3 (8, mar) + Grupos F3 (16)** | Grupos F3 | Grupos F3 |
| 4–6 | Grupos F4–F6 | Grupos F4–F6 (1 `AWD`) | Grupos F4–F6 | Grupos F4–F6 |
| 160 | — | — | **Playoffs** (16) | — |
| 32 | — | — | — | **Playoffs** (16) |
| 16 | Octavos (16 = 8 series) | Octavos (16) | Octavos (16) | Octavos (16) |
| 125 | Cuartos (8) | Cuartos (8) | Cuartos (8) | Cuartos (8) |
| 150 | Semis (4) | Semis (4, NS) | Semis (4) | Semis (4, una en vivo hoy) |
| 200 | Final única (1) | vacía (aún no cargada) | Final única (1) | vacía |

### 2.3 Hallazgos de datos
1. **Los códigos cambian entre temporadas** (previas: `400` en 2025, mezcladas en `1/2/3` en 2026; playoffs Sud: `160` en 2025, `32` en 2026). → Formato **por temporada** en el catálogo; nada se reutiliza de Copa Argentina.
2. **En 2026 las previas y los grupos comparten código**: solo se separan por **fecha** (feb–mar vs abr–may). Es el mismo problema que Apertura/Clausura en Primera → ventanas de fechas en el catálogo.
3. **`strGroup` no es confiable**: Lib 2026 solo lo trae en `r=2`; Lib 2025 y Sud (ambas) en todas las fechas de grupos. Siempre 2 partidos por grupo por fecha. → Grupos con `idTeam` en el catálogo, validados contra los grabados (y contra `strGroup` cuando exista).
4. **Ida y vuelta en la misma `r`**, sin id de serie: se emparejan por el par de `idTeam`. A veces la «ida» no es la de fecha esperada (Santa Fe–River). Final a partido único (`r=200`).
5. **Penales**:
   - **2025: sin información** (todo `FT`, extras `null`, incluso en series definidas por penales).
   - **2026**: `PEN` presente; Libertadores trae la tanda en `intHome/AwayScoreExtra`; **Sudamericana a veces `PEN` con extras `null`** (6 en `r=1`, Atlético Mineiro–Santos en `r=125`).
   - En una vuelta `PEN`, `intHomeScore/intAwayScore` es el resultado del partido (puede no ser empate: lo empatado es el **global**). U. Católica (ECU)–Juventud Las Piedras `3-4` con tanda `3-4` es **correcto** (verificado en D1: ida 0-1, global 4-4, Juventud ganó 4-3 los penales).
   - Sin `AET` en ninguna temporada.
   - **Evidencia de avance** (D1): el único de los dos que juega un partido posterior **de la misma competición y temporada** (no solo la ronda siguiente: en 2025 las previas avanzan dentro de la misma `r=400`). Resuelve todas las series empatadas sin tanda salvo la **final de la Sudamericana 2025** (Lanús 0-0 Atlético Mineiro, `FT`): sin dato del campeón.
6. **Estados**: `WO` (Colo-Colo 0-3 Fortaleza, Lib 2025) y `AWD` (Medellín 0-3 Flamengo, Lib 2026) → ya mapeados a `finished` por `MatchStatusMapper`.
7. **Horarios**: `strTimestamp` UTC (regla vigente). Un evento en vivo trajo `strTime "22:00"` sin segundos; `strTimeLocal` a veces vacío (no es fuente).
8. **Punteros de liga**: `eventsnextleague`/`eventspastleague` devuelven 1 evento cada uno (el «pasado» puede estar en vivo).
9. **`eventsseason`** truncado (5–15 eventos) y sin `strGroup` ni extras → no se usa.
10. **`lookuptable`** para 4501/4724: HTTP 200 con cuerpo vacío → **no hay tabla de la API**; se calcula localmente.
11. `lookupevent` funciona (trae `strGroup`, extras, más campos). `strCountry` del evento = país de la sede (no del equipo).
12. Equipos argentinos presentes en ambas copas (River, Boca, Estudiantes, Racing, Vélez, Lanús, Central, Platense, Independiente Rivadavia, Tigre, Barracas, Riestra…).

### 2.4 Reglamentos CONMEBOL — ✅ verificados con los textos oficiales (D1)

Fuente: Manuales de Clubes oficiales de CONMEBOL (texto en `docs/evidence/d1_reglamentos_conmebol.txt`; enlaces en `docs/API.md`, V20).

| Temporada | Desempate de grupos (Libertadores y Sudamericana) | Calculable con la API |
|---|---|---|
| **2026** (Lib 2.4.2 · Sud 2.4.3) | 1) entre los empatados, solo sus partidos de grupos: i) puntos, ii) DG, iii) GF · 2) DG total · 3) GF total · 4) menos rojas · 5) menos amarillas · 6) sorteo. «Una vez aplicado un criterio, no se regresará a los anteriores» → **sin re-aplicar** el directo al subgrupo (a diferencia de Primera). | 1–3 sí; 4–6 no → «posición compartida» |
| **2025** (Lib 2.4.2 · Sud 2.4.3) | 1) DG · 2) GF · 3) GF como visitante · 4) Ranking de Clubes CONMEBOL al 16/12/2024 · 5) sorteo. **Sin enfrentamiento directo.** | 1–3 sí; 4–5 no → «posición compartida» |

- **Contraste con los datos**: con la regla de cada temporada, el orden calculado coincide con quién jugó la etapa siguiente en los **32 grupos** (0 diferencias). La regla 2026 reproduce los dos casos de la prensa con la tabla parcial: Grupo D al 30/04 (U. Católica 1.º, Boca 2.º pese a mejor DG) y Grupo G al 05/05 (LDU, Lanús, Mirassol); con la regla 2025 los dos órdenes salen distintos. Re-aplicar o no el directo no cambia ningún orden real.
- **Eliminatorias** (previas de Libertadores, playoffs, octavos, cuartos, semis; Lib 2.4.3 · Sud 2.4.4): DG del global y, si persiste, penales (sin alargue, sin gol de visitante). **Primera fase de la Sudamericana** (partido único; Sud 2.4.2): penales. **Final** (Lib 2.4.4 · Sud 2.4.5): alargue y penales.
- **Formato**: Libertadores: Fases 1–3 (ida y vuelta) → 32 en 8 grupos → 1.º y 2.º a octavos; 3.º a los playoffs de la Sudamericana; los 4 perdedores de la Fase 3, a los grupos de la Sudamericana. Sudamericana: Primera fase (32 equipos de 8 países, cruces nacionales a partido único) → 8 grupos → 1.º a octavos; 2.º a los playoffs contra los 3.º de Libertadores (ida y vuelta) → octavos, cuartos, semis → final única.

## 3. Limitaciones técnicas

| # | Limitación | Consecuencia / alternativa (sin servicios pagos) |
|---|---|---|
| L1 | Sin tabla de la API (`lookuptable` vacío) | Tabla calculada localmente con los partidos de grupos (como Nacional). Lo no calculable (tarjetas, ranking, sorteo) → «posición compartida». |
| L2 | `strGroup` incompleto en Lib 2026 | Grupos (`idTeam`) en el catálogo por temporada, validados en tests contra los grabados. Sin grupos verificados → sin tabla. |
| L3 | Previas y grupos comparten `r` en 2026 | Ventanas de fechas por etapa en el catálogo; partido fuera de toda ventana → `undetermined` (no se adivina). |
| L4 | Penales 2025 inexistentes; Sud 2026 a veces `PEN` sin tanda | «Avanza X» solo con evidencia: global, tanda consistente o el único que juega después en la misma competición y temporada. Si no, «Global 2-2 · sin dato de la definición» (caso real: final Sudamericana 2025, sin campeón determinable). |
| L5 | Sin id de serie | Emparejar por par de `idTeam` dentro de la misma `r`. Más de 2 partidos con el mismo par → «sin ubicar». |
| L6 | Final 2026 aún no cargada (Sud 21/11, Lib 28/11 a confirmar) | Cuadros y finales se prueban con las temporadas 2025 completas y verificadas. Las finales 2026 son una **tarea posterior separada** (D-F), fuera del cierre del hito. |
| L7 | `eventsseason` truncado, `search_all_seasons` cortado | Solo `eventsround` (sin paginación). Temporadas = actual + anterior (D10). |
| L8 | `searchteams` devuelve 1 resultado y hoy filtra «Argentina» | Equipos extranjeros solo desde partidos guardados (+ arranque opcional, ver §8). |
| L9 | Equipos que vienen de otra copa (3.º de Lib → playoffs Sud; perdedores de Fase 3 Lib → grupos Sud) | Se informa como texto; no se vincula entre competiciones. |
| L10 | Reglamentos | ✅ Resuelto en D1: los cuatro textos oficiales (2025 y 2026) están verificados. Una temporada futura sin texto oficial verificado queda sin tabla. |
| L11 | Grabaciones posteriores al reloj de los tests (`pumpApp` = 11/10/2026) | Parámetro `now:` en `pumpApp`/`RecordedApi` para los tests continentales (ver §11). |

## 4. Organización definitiva del selector

### 4.1 Categorías (en el catálogo, única fuente de verdad)
`enum CompetitionCategory { firstDivision('Primera División'), promotion('Ascenso'), nationalCup('Copas nacionales'), internationalCup('Copas internacionales') }` + campo obligatorio `category` en `CompetitionDefinition` + `CompetitionCatalog.byCategory` (orden del enum, y dentro el orden de `all`).

| Categoría | Competiciones |
|---|---|
| Primera División | Liga Profesional (4406) |
| Ascenso | Primera Nacional (4616), Primera B Metropolitana (5215), Primera C (5524). **Federal A (5523): fuera del Hito D por decisión del usuario** (queda anotado en DECISIONS/API como pendiente con relevamiento propio, V8) |
| Copas nacionales | Copa Argentina (4500) |
| Copas internacionales | Copa Libertadores (4501), Copa Sudamericana (4724) |

Una categoría vacía no se muestra. `shortName` de Copa Argentina pasa de «Copa» a «Copa Argentina» (evita la ambigüedad con las copas nuevas).

### 4.2 Comportamiento
- Un widget `CompetitionPicker` (`presentation/widgets/competition_picker.dart`, dentro de `FixtureSelectors`, conserva `competitionSelectorKey`), de dos niveles: **categoría → competición**. La categoría **se deriva** de la competición seleccionada (no es estado propio ni parámetro de URL).
- **Diseño mixto (decidido)**:
  - **< 600 px**: un botón con «Categoría · Competición ▾» que abre una hoja inferior (`showModalBottomSheet`) con las competiciones agrupadas por categoría (encabezados de sección, la actual marcada). Una sola fila de alto.
  - **≥ 600 px**: dos filas de `ChoiceChip`s (categorías; debajo, las competiciones de la categoría, oculta si tiene una sola). En ≥ 1200 px, las dos en la misma línea si entran.
- Tocar una categoría (≥ 600) selecciona su última competición usada en la sesión (o la primera) y despacha **un solo** `FixtureCompetitionChanged(id)`: se carga solo esa competición. En la hoja (< 600) se elige directamente la competición.
- URLs sin cambios (`/competiciones/<id>?…`): los enlaces existentes, la recarga en Web y `_updateUrl/_restoreUrl` siguen igual. Copas nuevas: `/competiciones/4501?temporada=2026&fase=grupos&ronda=3`.
- **Vistas disponibles**: `_ViewSelector` muestra solo las que aplican, **por competición** (no por temporada, para que el selector no salte al cambiar de año): getters de dominio `hasStandings` (algún formato ≠ `NoStandings`) y `hasBracket` (`bracketRounds` no vacío); Fixture y Calendario siempre. En el listener de `competitions_page.dart` (L378) se verifica antes de cargar; un `vista=` no disponible cae en Fixture y corrige la URL. Si una temporada concreta no tiene formato, el panel sigue mostrando «Sin tabla» (como hoy). Cambia a B Metro/C (dejan de mostrar el segmento Tabla).
- Inicio: los chips de competiciones (`home_page.dart:455`) se agrupan por categoría (solo presentación, 0 peticiones).
- Diseño por ancho: ver decisión pendiente (§11).

## 5. Modelo de competición internacional

Sin sistema paralelo: es una **4.ª variante de `CompetitionRules`**, y cada `switch` existente (PhaseResolver, RoundNavigator, StageLabeler, `bracketRounds`, `phases`, `expectedMinimumMatches`, `CompleteRounds.seasonRounds`) gana un caso. Las reglas argentinas no se tocan.

```dart
// domain/entities/phase.dart — PhaseKey gana 3 valores (URL: previa, grupos, eliminatorias)
qualifying('Fases previas'), groups('Fase de grupos'), knockoutStage('Eliminatorias')
// (knockoutStage y no knockout: evita confundirlo con StageKind.knockout)

// catalog/competition_catalog.dart
final class ContinentalCupRules extends CompetitionRules {
  final Map<int, ContinentalSeason> seasons;           // año → formato verificado
  final List<BracketRound> bracket;                    // Octavos→Final, con legs (D5)
}
final class ContinentalSeason {
  final List<ContinentalStage> stages;                 // en orden cronológico
  List<ContinentalStage> preliminarySeries;            // Sud: Playoffs (Llaves, D5)
}
final class ContinentalStage {
  final PhaseKey phase;          // qualifying | groups | knockoutStage
  final String label;            // «Fase 1», «Fecha 3», «Playoffs», «Octavos de final»…
  final int apiRound;            // 400, 1..6, 160/32, 16, 125, 150, 200
  final int legs;                // 1 o 2
  final int expectedMatches;     // partidos esperados (calidad de respuesta)
  final CalendarDay from, to;    // ventana obligatoria
  final bool verified;
  StageKind get kind;            // derivado: groups → regular; el resto → knockout
}
```
- **Refactor previo sin cambio de comportamiento** (primera tarea de D3): `expectedMinimumMatches(Season, int)` y `StageLabeler.label/describe` con `Season` (≈ 11 llamadas: `watch_stage_matches`, `complete_rounds`, `refresh_recent_rounds`, `get_home_feed`, `watch_team_detail`, `ensure_team_index`, `round_navigator`, `get_match_detail`, `stored_match_labeler`, `watch_competition_calendar`). `FixtureRoute`: `switch` exhaustivo en lugar del mapa + test de ida y vuelta sobre `PhaseKey.values`.
- Invariantes del catálogo (test): por temporada, `(phase, apiRound, kind)` único; etapas con la misma `apiRound` con ventanas disjuntas; cada partido grabado cae en **exactamente una** etapa (como `competition_catalog_test.dart:61` para Primera).
- URL: `parse` deja `kind` nulo si no viene `etapa`, y `_open` (`competition_fixture_bloc.dart:137`) toma la etapa de esa ronda en la fase (`fase=previa&ronda=1` funciona sin `etapa=`).
- `ResolveCurrentStage`: si el puntero no cae en ninguna etapa (postergado), usa la etapa cuya ventana contiene hoy, o la última que empezó (no la Fase 1 de febrero).
- Textos no exhaustivos a tocar a mano: `bracket_panel.dart:112,163`, `zone_validator.dart:32`, `standings_panel.dart:86`, `get_match_detail.dart:69`.
- **Ejemplo Lib 2026**: `qualifying` Fase 1 (r1, feb, 2 legs, 6), Fase 2 (r2, feb, 2, 16), Fase 3 (r3, mar, 2, 8) · `groups` Fecha 1–6 (r1–6, 7/4–29/5, 1 leg, 16) · `knockout` Octavos (16, 2, 16), Cuartos (125, 2, 8), Semis (150, 2, 4), Final (200, 1, 1).
- **2025**: previas en una sola etapa `r400` («Fases previas» Lib / «Primera fase» Sud), para no tener dos etapas con la misma identidad `(phase, apiRound, kind)` (`Stage` ignora la etiqueta). Sud: Playoffs = `r160` (2025) / `r32` (2026).
- **`PhaseResolver`**: un partido de la ronda r → la etapa de esa temporada con `apiRound == r` cuya ventana contiene su día argentino. Ninguna o más de una → `undetermined`. Temporada sin formato → todo `undetermined` (sin inferencia). `_enforceOneMatchPerTeam` queda igual (solo actúa sobre `regular` = grupos, donde sí es una buena verificación).
- **`expectedMinimumMatches(r)`** = suma de `matches` de las etapas con esa `r` (Lib 2026 r1 = 22, r2 = 32, r3 = 24) → `quality` detecta respuestas parciales.
- `RoundNavigator.stagesFor` = las etapas de la temporada; `StageLabeler` usa `label`. Chips de fase: Fases previas · Fase de grupos · Eliminatorias.
- **`Match` no cambia**: ni grupo ni etapa se guardan (decisión de Fase 2); se derivan del catálogo. `strGroup` se lee solo en tests de validación.
- Catálogo: `showInHome: false`, `inTeamIndex: false`, `category: internationalCup`, `format: cup`.

## 6. Grupos y tablas

- Nuevo `GroupStage extends ZonedStandingsFormat` (`catalog/standings_format.dart`): `groups: Map<String, Set<int>>` (A–H, 4 `idTeam` c/u), `regularRounds: [1..6]`, `interzonalsPerTeam: 0`, `tieBreak`, `tieBreakArticle`, `regulation`. `zonesByTournament => {PhaseKey.groups: groups}`. Reutiliza `_zoneTable`, `TeamStats`, `StandingsTable`, `StandingsCoverage`, `ZoneValidator` y `StandingsPanel` (chips «Grupo A»…«Grupo H», clave `tabla=grupo-a`).
- `GroupTableBuilder` (clave `grupo-a`, título corto «Grupo A») sobre `_zoneTable`; `zoneNoun` ('zona'/'grupo') para los textos; el torneo se nombra solo si `tournaments.length > 1`.
- `ZoneValidator` con `interzonalsPerTeam: 0` = verificación fuerte (un cruce entre grupos es error). Invalidez **por grupo** (`invalidZones`) solo para `GroupStage`; Primera y Nacional mantienen la regla global.
- `TieBreakCriterion` (`tie_breaker.dart`), cambio mínimo:
  - `HeadToHeadCriterion({reapply = true})` + `static const headToHeadOnce`: sin re-aplicación, los bloques que siguen empatados pasan al criterio siguiente en vez de recursar (2026).
  - `AwayGoalsForCriterion` («goles a favor como visitante», calculado desde los partidos; `TeamStats` no cambia) — 2025.
  - `UnavailableCriterion(label)` no calculable (tarjetas rojas/amarillas, ranking CONMEBOL) junto a `fairPlay`/`drawOfLots`; `StandingsNotes.shared` lo toma solo.
- `standingsBySeason`: Lib/Sud **2026** = directo (sin re-aplicar) → DG → GF → tarjetas → sorteo; **2025** = DG → GF → goles de visitante → (no calculables). ✅ **Verificados en D1** con los Manuales de Clubes oficiales y con los datos (32 grupos y los casos de la prensa; §2.4). Para 2025, el 4.º criterio (Ranking CONMEBOL) y el sorteo no son calculables → «posición compartida».
- Solo partidos de grupos (las previas de r1–3 en 2026 quedan fuera por `PhaseResolver`). Cobertura: «Fechas consultadas X de 6» + «Partidos sin sumar». `WO`/`AWD` cuentan con el resultado oficial.
- Nunca «oficial» si `ZoneValidator` detecta inconsistencias: sin tabla de ese grupo + aviso.

## 7. Eliminatorias y series de ida y vuelta

**Lo que falta hoy**: `KnockoutBracketBuilder` y `TieOutcome` asumen partido único. Peor: en una vuelta `PEN` 1-0 (global empatado) `TieOutcome.of` daría ganador al que ganó el partido → **incorrecto** para series.

Cambios mínimos:
1. `KnockoutTie` (entidad, `matches/domain`): `legs: List<Match>` (1 o 2, por fecha), `teams`, `aggregate: Score?` (solo si todas las piernas terminaron; con el orden de equipos de la ida), `isComplete`.
2. `TiePairing.pair(matches, legs)` (servicio): agrupa por par no ordenado de `idTeam` dentro de la ronda; > `legs` partidos con el mismo par, o pares incompletos sin la otra pierna programada → se muestran como pendientes/sin ubicar.
3. `TieOutcome.ofTie(tie, laterMatches)`; `TieOutcome.of(match)` delega con una pierna y **conserva exactamente** la lógica actual (Primera y Copa Argentina sin cambios). Para `legs == 2`: global distinto → `aggregate` (fuente nueva); global igual → tanda de la vuelta si es `PEN` con extras y tanda no empatada; si no → `laterMatch`: el único de los dos que juega **cualquier partido posterior de la misma competición y temporada** (D1: en 2025 las previas avanzan dentro de la misma `r=400`, y las previas avanzan a la fase de grupos); si no → `null`. **Dato contradictorio** (`PEN` con global distinto): no se usa ni el global ni la tanda; solo la aparición posterior, o nada. En los datos grabados no hay ningún caso (el de U. Católica resultó correcto).
4. `BracketRound` gana `legs` (por defecto 1); `matches` sigue significando **llaves** (el test de mitades `knockout_bracket_test.dart:23` se mantiene). El constructor arma las llaves **después** de `_splitByTeam` (Primera r0) y antes de recortar/ordenar; `_order` usa `tie.involvesTeam`. `BracketSlot.tie` + `Match? get match => tie?.legs.first` (compatibilidad).
5. Llaves continentales = **árbol Octavos → Final** (`forSeason` ya filtra por las rondas del cuadro) + **Sud: «Playoffs» como lista de series** (`KnockoutSeries.forStages`). Las previas (Lib Fases 1–3, Sud Primera fase) se ven **solo en el Fixture**, agrupadas por serie. Presupuesto: Lib 4, Sud 5.
6. `CompetitionDefinition.bracketPhases` (split → sus fases, copa → [unica], continental → [knockoutStage]) para los chips de `bracket_panel.dart:112` y `bracketUri` (sin `llave=` si hay una sola).
7. UI: tarjeta de serie con «Ida»/«Vuelta», «Global X–Y», «Avanza X (global/penales/juega la ronda siguiente)»; pie según `legs`. `GetMatchDetail._advancement`: con `legs == 2` empareja la ronda ya filtrada por etapa y usa `ofTie` con los partidos guardados de etapas posteriores; `MatchDetail.tie` nuevo. `MatchCard` no cambia (muestra «Avanza» solo con tanda).
8. Las rondas del cuadro continental entran al catálogo **recién en D5**, junto con la lógica de series (antes darían «Avanza» incorrectos).

## 8. Equipos, favoritos y calendario

- **Identidad**: `idTeam` y `idEvent` como hoy; los partidos internacionales van al store `events` existente (dedupe por `idEvent`), sin stores nuevos.
- **Ficha de equipo**:
  - **D3 (obligatorio al sumar 4724 al catálogo)**: `_otherCompetitions` (`watch_team_detail.dart:218`) lista los punteros cuyo `idEvent` no está entre los partidos guardados del equipo, **sea o no del catálogo**. Así el puntero de Boca a la Sudamericana no desaparece; deja de listarse solo cuando esa ronda se guarda. Tests de Boca siguen verdes.
  - **D6 (plan completo)**: una copa internacional entra al `_plan` si el equipo tiene partidos guardados en ella **o** un puntero es de esa copa. Primero la ronda del puntero (P1, resultado visible enseguida); después las rondas de la temporada en orden cronológico (P2, cancelable, con progreso).
  - **Límite superior (sin adivinar)**: solo etapas que ya empezaron (ventana con `from ≤ hoy`) y, si hay puntero «próximo» del equipo en esa copa, hasta su etapa. Las etapas futuras se piden cuando se vuelven vigentes (incremental, bajo demanda).
  - **La ausencia nunca corta.** Que el equipo no esté en una ronda no prueba nada: puede haber cambio de fase, semanas sin partidos, clasificación directa a octavos (1.º de grupo en la Sudamericana se saltea los Playoffs) o ingreso desde otra copa (3.º de Libertadores → Playoffs de la Sudamericana; perdedores de la Fase 3 de Libertadores → grupos de la Sudamericana).
  - **Corte temprano solo con evidencia suficiente** de que no quedan partidos relevantes en **esa** copa (se evalúa con lo ya guardado, sin peticiones):
    1. **Serie perdida con evidencia**: `TieOutcome.ofTie` (D5) da ganador al rival en una serie completa de previas o de eliminatorias.
    2. **Eliminado en grupos con evidencia**: tabla del grupo completa (6 fechas, todos los partidos terminados, grupo válido) y una posición **no compartida** fuera de toda clasificación de esa copa (Lib: 4.º; Sud: 3.º o 4.º). Si la posición es compartida y cruza la línea de clasificación → no hay evidencia.
    3. **Competición terminada**: la final de la temporada está terminada.
  - Sin evidencia: se sigue de forma incremental dentro del límite superior. Las rondas guardadas cerradas no se vuelven a pedir (0 en caliente).
  - La continuidad en **otra** copa (Lib → Sud) no se infiere: esa copa entra al plan por sus propios punteros o partidos guardados.
- **Búsqueda (decidido: arranque bajo demanda)**: el índice local ya incluye a cualquier equipo de un partido guardado. Si la búsqueda local no encuentra nada, se ofrece «Buscar también en copas internacionales»: pide la **Fecha 1 de grupos** de la temporada actual de cada copa (2 peticiones P1, una sola vez; etapa explícita, no `EnsureTeamIndex.firstRound`, que tomaría la Fase 1 previa) y relanza la búsqueda. El fallback online (`team_dto.dart:45`) acepta además equipos cuyos `idLeague…` incluyan 4501/4724.
- **Inicio / favoritos**: `showInHome: false` (0 peticiones nuevas; `home_request_budget_test` intacto salvo el conteo de `all`). «Tus equipos» lee lo guardado: muestra partidos de copas internacionales si ya están guardados (0 peticiones). Un favorito **no** dispara sincronización de la copa.
- **Calendario**: sin cambios de diseño; «Completar» usa `CompleteRounds` con las rondas únicas de la temporada.

## 9. Consumo y sincronización

Unidad incremental: **la ronda de la API** (`eventsround`), como hoy: es la única que existe; las etapas que comparten `r` se resuelven al leer. Todo por `SyncScheduler` (P0 visible, P1 contexto, P2 fondo con progreso y cancelación), `QueryMetadataStore`, `RoundCachePolicy` (una ronda de previas de febrero + grupos de mayo queda `closed` en octubre: 0 peticiones en caliente).

| Operación | Frío | Caliente |
|---|---|---|
| Abrir Fixture de una copa (lookupleague + 2 punteros + ronda + prefetch) | ≤ 5 | 0 |
| Cambiar de categoría | solo la competición elegida (≤ 5) | 0 |
| Tabla de grupos (r1–6) | 6 | 0 |
| Llaves Lib (16, 125, 150, 200) / Sud (+ playoffs) | 4 / 5 | 0 |
| Calendario «Completar» Lib/Sud 2026 | 10 / 11 (2025: 11 / 12) | 0 |
| Ficha de equipo, por copa internacional | ≤ etapas ya empezadas (máx. 10–12; menos con corte por evidencia) (P2) | 0 |
| Inicio | +0 | 0 |
| Arranque de búsqueda (bajo demanda, decidido) | 2 (Fecha 1 de grupos de cada copa) | 0 |

Respuestas parciales: `expectedMinimumMatches` por etapa → `quality` → `retrySoon`. Sin red: stale-while-revalidate (sin cambios).

## 10. Roadmap por fases

Orden: D1 → D2 → D3 → D4 → D5 → D6 → D7. Al terminar cada fase: `flutter analyze` sin issues, tests verdes, Android (`SOP10X2501001122`) + Chrome si hay UI, docs actualizadas, informe y **espera de aprobación**. Sin commits ni PR (los hace el usuario). D2 va antes de D3 a propósito: con las vistas ocultas por competición, D3 puede sumar las copas sin mostrar Tabla/Llaves hasta D4/D5.

### D1 — Investigación, grabaciones y reglamentos (sin código de `lib/`)
- **Objetivo**: datos reales grabados y formatos verificados que sostengan todo el hito.
- **Dependencias**: aprobación de este plan.
- **Tareas**:
  1. Copiar este plan a `docs/HITO_D.md`.
  2. Grabar con `curl` (≈ 17/min, byte a byte, sin editar) en `test/fixtures/api/`: `lookupleague_4501`; `eventsnextleague_/eventspastleague_` 4501 y 4724; `eventsround_4501_r{400,1–6,16,125,150,200}_s2025`, `…_r{1–6,16,125,150,200}_s2026`; `eventsround_4724_r{400,1–6,160,16,125,150,200}_s2025`, `…_r{1–6,32,16,125,150,200}_s2026`; `lookupevent` de casos testigo (`PEN` sin tanda Sud, U. Católica–Juventud, `WO`, `AWD`); `lookuptable_4501_s2026` (vacío). Registrar en `test/fixtures/api/README.md`.
  3. Con un script en el scratchpad (fuera del repo): ventanas de cada etapa, conteos, grupos por `idTeam` cruzados con `strGroup`, pares de series y casos de penales.
  4. Reglamentos **oficiales CONMEBOL** (reglamento del torneo / Manual de Clubes) de Libertadores y Sudamericana **2025 y 2026**: texto, artículo e inciso de los criterios de desempate de grupos (orden exacto, alcance del directo y si se re-aplica), alargue/penales y final. Se registran en `docs/API.md` con URL y fecha de consulta. Lo que no se encuentre en una fuente oficial queda **«pendiente»** y no se implementa (esa temporada, sin tabla). Validación contra casos reales: Grupo G de Lib 2026 y «¿Por qué Boca aparece segundo?».
  5. Verificar el resultado real de U. Católica–Juventud Las Piedras (`PEN` 3-4 / 3-4) para documentar el caso.
  6. Docs: `docs/API.md` V16+ (ids, códigos por temporada, `strGroup`, penales, `WO`/`AWD`, `lookuptable` vacío, `eventsseason` truncado); `docs/DECISIONS.md` D22+ (modelo continental, categorías, series, Federal A fuera); `docs/DATA_STRATEGY.md` (presupuestos).
- **Archivos**: `test/fixtures/api/*`, `test/fixtures/api/README.md`, `docs/*`.
- **Dominio**: ninguno. **Riesgos**: reglamento 2025 inaccesible (→ L10), semis 2026 en curso (las grabaciones de 150 cambian: se graban igual y se re-graban en D7 en instantánea).
- **Consultas**: ≈ 55 (manuales, una sola vez).
- **Aceptación**: tablas de rondas/etapas/ventanas/grupos por temporada en `docs/API.md`, desempates con fuente oficial CONMEBOL citada o marcados «pendiente», fixtures registrados.
- **Pruebas**: `flutter test` sigue verde (no se toca `lib/`).
- **Resultado**: base de datos reales y reglas firmes para D3–D6.

#### Resultado de la Fase D1 (14/10/2026)
1. ✅ Plan copiado a `docs/HITO_D.md`.
2. ✅ **58 respuestas reales grabadas** (HTTP 200 todas): `lookupleague_4501`; punteros de liga de 4501 y 4724; 44 `eventsround` (Lib 2025: 11, Lib 2026: 10, Sud 2025: 12, Sud 2026: 11; las finales 2026 vuelven vacías); `lookuptable` de ambas (cuerpo vacío); 7 `lookupevent` testigo (`PEN` con y sin tanda, U. Católica–Juventud, grupo con `strGroup`, `WO`, `AWD`). Registradas en `test/fixtures/api/README.md` con SHA-256. Ningún archivo existente se tocó.
3. ✅ Análisis (scripts fuera del repo): ventanas reales por etapa, 32 grupos con `idTeam` (8×4, todos contra todos), series y casos sin dato → `docs/evidence/d1_grupos_y_etapas.md`.
4. ✅ **Reglamentos oficiales** de CONMEBOL 2025 y 2026 de las dos copas encontrados y transcriptos (`docs/evidence/d1_reglamentos_conmebol.txt`); contraste con los datos sin diferencias (§2.4).
5. ✅ U. Católica–Juventud: dato correcto (no es una anomalía).
6. ✅ Docs: `API.md` (V16–V21), `DECISIONS.md` (D22–D27 + registro), `DATA_STRATEGY.md` (plan de datos y presupuestos), este documento.

**Cambios al plan que salen de D1** (ya incorporados arriba):
- Evidencia «juega después» = cualquier partido posterior de la misma competición y temporada (§7.3).
- Final de la Sudamericana 2025 sin campeón determinable con la API (L4): se mostrará «sin dato de la definición».
- Reglamentos 2025 y 2026 verificados: las cuatro temporadas tendrán tabla de grupos en D4.
- Ventanas observadas (hora argentina) para el catálogo de D3: Lib 2026 Fase 1 03–12/02, Fase 2 17–26/02, Fase 3 03–12/03, grupos 07/04–28/05; Sud 2026 Primera fase 03–05/03, grupos 07/04–28/05; 2025: previas Lib 04/02–13/03, Sud 04–06/03, grupos 01/04–29/05 (resto en la evidencia).

**Validación**: `flutter analyze` y `flutter test` sin cambios en `lib/` ni en tests (solo fixtures nuevos y docs).

### D2 — Categorías y selector
- **Objetivo**: selector categoría → competición responsive, vistas según la competición, sin cambiar URLs.
- **Dependencias**: D1 (solo docs). Sin copas nuevas todavía (la categoría internacional no se muestra, está vacía).
- **Tareas**:
  1. `CompetitionCategory` + `category` + `byCategory` en `competition_catalog.dart`; `shortName` «Copa Argentina».
  2. `competition_picker.dart`: < 600 botón + hoja inferior agrupada; ≥ 600 dos filas de chips (una línea en ≥ 1200); recuerda la última competición por categoría en la sesión.
  3. `hasStandings`/`hasBracket`; `_ViewSelector` solo con vistas disponibles; fallback de `vista=` a Fixture con corrección de URL (`competitions_page.dart`).
  4. Chips del Inicio agrupados por categoría (`home_page.dart:455`).
  5. Helper `selectCompetition` (`test/helpers/recorded_app.dart:114`) por categoría + competición; reemplazar `'Copa'` por `'Copa Argentina'` en los tests.
- **Archivos**: `competition_catalog.dart`, `fixture_controls.dart`, nuevo `competition_picker.dart`, `competitions_page.dart`, `home_page.dart`, helpers de test.
- **Dominio**: `CompetitionCategory`, `CompetitionDefinition.category`, `hasStandings`, `hasBracket`.
- **Riesgos**: muchos tests dependen de la fila de chips; accesibilidad al 200 % en 360 px; foco y lectura de la hoja inferior.
- **Consultas**: 0 nuevas; cambiar de categoría = solo la competición elegida.
- **Aceptación**: links viejos y recarga en Web funcionan; B Metro/C sin segmento Tabla; Nacional sin Llaves; sin desbordes en 360/768/1280/1920.
- **Pruebas**: `competition_catalog_test` (categorías, orden), `competitions_page_test` (selector, fallback `vista=tabla`), nuevo `competition_picker_test` (hoja < 600, chips ≥ 600), `new_competitions_test`, `bracket_view_test`, `home_page_test`, `accessibility_test`, `responsive_layout_test`, presupuestos (`calendar_budget_test`, `bracket_budget_test`) intactos.
- **Resultado**: selector nuevo con las 5 competiciones actuales.

#### Resultado de la Fase D2 (15/10/2026)
1. ✅ `CompetitionCategory` (4 valores con `label`), `CompetitionDefinition.category`, `CompetitionCatalog.byCategory` (orden del enum, sin categorías vacías), `hasStandings`/`hasBracket`; `shortName` «Copa Argentina».
2. ✅ `CompetitionPicker`: < 600 px botón «Categoría · Competición ▾» + hoja agrupada; 600–1199 dos filas de chips; ≥ 1200 en una línea si entran; memoria de la última competición por categoría; una sola carga por toque.
3. ✅ Vistas por competición (`CompetitionsView.isAvailableFor`): Primera 4; Nacional sin Llaves; Copa Argentina sin Tabla; B Metro y C solo Fixture y Calendario. `vista=` no disponible → Fixture (vista inicial y al cambiar de competición) y la URL de Web pasa a la del Fixture.
4. ✅ Inicio: accesos agrupados por categoría (en teléfonos, una fila con desplazamiento por categoría).
5. ✅ Helper `selectCompetition` por categoría + competición (la categoría se deriva del nombre corto); `'Copa'` → `'Copa Argentina'` en los tests.

**Ajustes respecto del plan** (registrados en `DECISIONS.md`): una categoría con una sola competición se nombra por la competición en el botón; la hoja usa el navegador raíz (en el de la sección quedaba detrás de la barra inferior: visto en la tablet); la memoria por categoría vive mientras viva la pantalla; Copa Argentina también pierde «Tabla».

**Validación**: `flutter analyze` sin issues; `flutter test` 694 verdes (nuevos: `competition_picker_test`, tests de categorías y vistas, la hoja sobre la barra inferior). Presupuestos (`home_request_budget_test`, `calendar_budget_test`, `bracket_budget_test`, `standings_budget_test`) sin cambios. Tablet `SOP10X2501001122` (APK release): horizontal 1280 (una línea), vertical 800 (dos filas), densidad 320 = 400 px (botón y hoja); Tabla → B Metro vuelve al Fixture; memoria Ascenso → B Metro. Web release en el Chrome de la tablet: enlace viejo `vista=tabla&tabla=apertura-a` abre la tabla; `/competiciones/5215?vista=tabla` abre el Fixture y corrige la URL; Tabla → «Copas nacionales» deja la URL del Fixture de la Copa. TheSportsDB respondía muy lento durante la prueba (timeouts; 20 s por consulta desde la PC).

**Pendiente observado (previo a D2, fuera de alcance)**: en ~400 px el selector de vistas de Primera (4 segmentos, desde la Fase 19.1) parte «Calendario» en dos renglones; no desborda.

### D3 — Integración básica de Libertadores y Sudamericana
- **Objetivo**: fixture por fases/etapas, temporadas 2025–2026, resultados, detalle y calendario de ambas copas.
- **Dependencias**: D1 (fixtures, ventanas), D2 (categorías y vistas ocultas).
- **Tareas**:
  1. Refactor sin cambio de comportamiento: `Season` en `expectedMinimumMatches` y `StageLabeler`; `FixtureRoute` con `switch` exhaustivo + test de ida y vuelta.
  2. `PhaseKey.qualifying/groups/knockoutStage` (URL `previa/grupos/eliminatorias`); `kind` nulo en `parse`/`_open`.
  3. `ContinentalCupRules`/`ContinentalSeason`/`ContinentalStage` y los casos en `phase_resolver.dart`, `round_navigator.dart`, `stage_labeler.dart`, `bracketRounds` (vacío en D3), `phases`, `expectedMinimumMatches`.
  4. Entradas 4501 y 4724 (`internationalCup`, `showInHome: false`, `inTeamIndex: false`, sin tabla ni cuadro), con etapas 2025 y 2026 de D1.
  5. `_otherCompetitions` por `idEvent` no guardado (`watch_team_detail.dart:218`); `match_detail_test.dart:59` usa 5523 como «fuera del catálogo».
  6. `ResolveCurrentStage`: fallback por fecha.
  7. Textos: «Fase de grupos · Fecha 3», «Eliminatorias · Octavos de final» en tarjetas, detalle (`match_detail_texts.dart`) y calendario.
  8. `pumpApp`/`RecordedApi` con `now:` opcional.
- **Archivos**: `competition_catalog.dart`, `entities/phase.dart`, `services/{phase_resolver,round_navigator,stage_labeler}.dart`, `usecases/{resolve_current_stage,watch_stage_matches,complete_rounds,refresh_recent_rounds,watch_competition_calendar}.dart`, `routing/fixture_route.dart`, `bloc/competition_fixture_bloc.dart`, `teams/domain/usecases/watch_team_detail.dart`, `match_detail/...`, `home/.../get_home_feed.dart`, `stored_match_labeler.dart`.
- **Dominio**: 3 `PhaseKey`, `ContinentalCupRules` y afines, firmas con `Season`.
- **Riesgos**: regresiones por las firmas (11 llamadas); URL de Web (solo se ejecuta fuera de los widget tests → test unitario); ventanas mal cortadas (→ test «cada partido en una etapa»).
- **Consultas**: abrir el Fixture de una copa ≤ 5 en frío, 0 en caliente; «Completar» calendario Lib/Sud 2026 = 10/11 (2025 = 11/12).
- **Aceptación**: Lib 2026 `r=1` muestra 6 partidos en «Fases previas · Fase 1» y 16 en «Fase de grupos · Fecha 1»; series de previas visibles como partidos; Inicio sin cambios; Boca conserva su puntero a la Sudamericana.
- **Pruebas**: `competition_catalog_test` (invariantes de etapas, cada partido grabado en una sola etapa, conteos), `phase_resolver_test`, `round_navigator_test`, `competition_fixture_bloc_test`, `fixture_route_test`, `complete_rounds_test` (10/11/11/12, 0 en caliente), `watch_competition_calendar_test`, `match_detail_test`, `team_detail_sync_test`, nuevo `test/app/continental_budget_test.dart`, `home_request_budget_test` (7 competiciones, mismas peticiones), toda la suite argentina.
- **Resultado**: ambas copas navegables (fixture, calendario, detalle) desde «Copas internacionales».

#### Resultado de la Fase D3 (15/10/2026)
1. ✅ Refactor sin cambio de comportamiento: `expectedMinimumMatches(Season, int)`, `StageLabeler.label(definition, season, phase, apiRound, kind)` y `describe(definition, season, …)` (11 llamadas); `FixtureRoute.phaseName`/`parsePhase` con `switch` exhaustivo.
2. ✅ `PhaseKey.qualifying/groups/knockoutStage` (URL `previa/grupos/eliminatorias`); `FixtureOpened.kind` nulo sin `etapa` (`fase=previa&ronda=1` abre la Fase 1).
3. ✅ `ContinentalCupRules`/`ContinentalSeason`/`ContinentalStage` y sus casos en `PhaseResolver`, `RoundNavigator`, `StageLabeler`, `bracketRounds` (vacío), `phases` y `expectedMinimumMatches`.
4. ✅ Entradas 4501 («Libertadores») y 4724 («Sudamericana»): `internationalCup`, fuera del Inicio y del índice, sin tabla ni cuadro; temporadas 2025 y 2026 con las etapas y ventanas de D1. **Los 622 partidos grabados de las cuatro temporadas caen cada uno en exactamente una etapa**, con la cantidad esperada por etapa.
5. ✅ «Otras competiciones» de la ficha por partido no guardado: Boca conserva su puntero a la Sudamericana; `match_detail_test` usa un partido real del Federal A (5523) como «fuera del catálogo».
6. ✅ `ResolveCurrentStage(…, today:)` + `RoundNavigator.stageOnDay`: sin puntero, la etapa vigente o la última que empezó (el 11/10/2026, Cuartos; no la Fase 1 de febrero).
7. ✅ Textos «Fases previas · Fase 1», «Fase de grupos · Fecha 3», «Eliminatorias · Octavos de final» en detalle, compartir, calendario y ficha (vía `StageLabeler.describe`, sin código nuevo de pantalla).
8. ✅ `pumpApp(now:)` + `continentalRecordingTime` (`RecordedApi` ya recibe su reloj).

**Ajustes respecto del plan** (detalle en `DECISIONS.md`, registro del 15/10/2026): `StageLabeler` recibe también la fase; las fechas de grupos usan la ventana de toda la fase; la final 2026 va sin ventana (`verified: false`, «inferida») y las semifinales 2026 «en curso»; «Otras competiciones» se limita a las competiciones que la ficha no sincroniza (fuera del catálogo o copas); la ficha no sincroniza las copas hasta D6; el respaldo por fecha solo actúa en las copas.

**Ajustes pedidos en la revisión** (15/10/2026):
1. **Selector en horizontal**: a 1280 px con el panel de detalle «Copas internacionales» quedaba cortado. Los chips de categoría se usan solo si entran en una línea; si no, el botón con la hoja (un renglón, áreas de 48 px). La hoja toma el alto de su contenido y abre con la competición actual a la vista (en horizontal, a 9/16 de la pantalla, las copas quedaban afuera). Encontrado en la misma prueba: en teléfonos con texto al 200 % las tres fases de las copas ocupaban un renglón cada una → una fila con desplazamiento (solo < 600 px).
2. **Inicio en teléfonos**: con texto al 200 % «Tus equipos» queda debajo de la primera pantalla; se llega desplazando, sin desbordes y con las pautas (`accessibility_test`; visto en la tablet a 400 px).
3. **Caída de TheSportsDB** (HTTP 522 de Cloudflare y ~20 s por consulta el 15/10/2026): sin cambios en el timeout (15 s), los reintentos ni la sincronización.
4. **Pruebas sin red**: herramienta `tool/recorded_app/` (respuestas grabadas, base en memoria, reloj de la grabación, banda «DATOS GRABADOS»).

**Validación**: `flutter analyze` sin issues; `flutter test` **744 verdes** (694 + 50 nuevos). Presupuestos: Fixture de una copa en frío = liga + 2 punteros + ronda + siguiente = **5**, en caliente **0**; «Completar» Lib/Sud 2026 = **10/11**, 2025 = **11/12**, en caliente 0; Inicio sin cambios (12 en frío, solo 4406/4616/4500).

**Dispositivos con datos grabados** (tablet `SOP10X2501001122`, APK release de `tool/recorded_app`; Web release servida en 8080 y abierta en el Chrome de la tablet con `adb reverse`):
- Android, horizontal 1280: Inicio con «Copas internacionales» (12 consultas, las del presupuesto); Libertadores = exactamente 5 consultas; selector como botón, hoja con las 7 competiciones sin desplazar; Sudamericana 2026: Primera fase (con «Final (penales)»), Fecha 1 sin consultas nuevas (ronda 1 ya guardada), detalle «Fase de grupos · Fecha 1» en el panel; Calendario: 0 consultas al abrir, «Completar» = las 7 rondas que faltaban, «Eliminatorias · Octavos de final» en agosto; temporada 2025 abre en la Final (Lanús 0-0 Atlético Mineiro, sin «Avanza») y Playoffs de octavos en la ronda 160.
- Android, vertical 800: chips enteros (cuatro categorías + copas), selección conservada al girar.
- Teléfono (densidad 320 = 400 px) con texto al 200 %: Inicio, hoja que se desplaza y fixture de copa con las fases en una fila.
- Web: enlace `…/4501?temporada=2026&fase=grupos&ronda=3` → Fecha 3 de grupos; cambiar a «Fases previas» actualiza la URL (`fase=previa&ronda=1&etapa=eliminatoria`) y la recarga la conserva; `4724?vista=tabla` → Fixture con la URL corregida; `4724?fase=previa&ronda=1` sin `etapa` → Primera fase; enlace viejo de Primera `fase=apertura&ronda=16` → Fecha 16 (no los octavos).

**Pendiente con la API real** (cuando TheSportsDB vuelva a responder en menos de 15 s): tablet y Chrome contra la red — recarga de URLs, navegación entre competiciones y caché entre sesiones (cerrar y reabrir: 0 consultas en caliente).

### D4 — Fase de grupos y tablas
- **Objetivo**: tablas de los grupos A–H con desempates CONMEBOL por temporada y cobertura.
- **Dependencias**: D3; reglamentos de D1.
- **Tareas**:
  1. `tie_breaker.dart`: `headToHeadOnce`, `AwayGoalsForCriterion`, `UnavailableCriterion`.
  2. `GroupStage` + `zoneNoun` en `standings_format.dart`.
  3. `GroupTableBuilder` en `table_builders.dart`; invalidez por grupo en `zone_validator.dart`.
  4. Caso `GroupStage` en `watch_standings.dart`.
  5. Grupos con `idTeam` en `standingsBySeason` **solo para las temporadas con reglamento oficial verificado en D1**; las demás quedan sin tabla.
  6. Textos de `standings_panel.dart` («Grupo A», banner de zonas, mensaje de copa).
- **Dominio**: `GroupStage`, 3 criterios nuevos, `ZoneValidation.invalidZones`.
- **Riesgos**: interpretación de «no se regresará a los anteriores» (→ test con el Grupo G real); grupos mal cargados (→ `ZoneValidator` + `strGroup`).
- **Consultas**: 6 en frío (r1–6), 0 en caliente; las previas de r1–3 no cuentan.
- **Aceptación**: 8 tablas por copa 2026 que coinciden con las oficiales salvo posiciones compartidas marcadas; «Fechas consultadas X de 6»; `WO`/`AWD` sumados.
- **Pruebas**: `tie_breaker_test` (con re-aplicación vs sin ella en triple empate; goles de visitante), `table_builders_test` (grupos grabados con `ZoneValidator`, Grupo G Lib 2026), `watch_standings_test`, `standings_view_test`, `standings_budget_test`, regresión de Primera/Nacional.
- **Resultado**: vista «Tabla» disponible para ambas copas.

#### Resultado de la Fase D4 (15/10/2026)
1. ✅ `tie_breaker.dart`: `HeadToHeadCriterion(reapply:)` + `TieBreakCriterion.headToHeadOnce` (los que siguen empatados después de la mini tabla pasan al criterio siguiente), `AwayGoalsForCriterion` (goles como visitante en todos los partidos de la tabla) y `UnavailableCriterion(label)` (tarjetas, Ranking CONMEBOL: posición compartida).
2. ✅ `GroupStage` (`standings_format.dart`): `groups`, `regularRounds` 1–6, `interzonalsPerTeam` 0, `tieBreak`, `pointsArticle`, `tieBreakArticle`, `qualificationNote`, `regulation`; `ZonedStandingsFormat.zoneNoun` («zona»/«grupo»).
3. ✅ `GroupTableBuilder` (clave `grupo-a`, «Fase de grupos 2026 · Grupo A», chip «Grupo A») sobre `_zoneTable`. `ZoneValidation.invalidZones`: en una fase de grupos se ocultan solo los grupos involucrados; Primera y Nacional siguen con la regla global.
4. ✅ `WatchStandings`: caso `GroupStage` (cada grupo válido; `StandingsView.zoneNoun`).
5. ✅ Catálogo: grupos con `idTeam` de las **cuatro** temporadas (Lib/Sud 2025 y 2026, todas con reglamento oficial verificado en D1), generados desde `docs/evidence/d1_grupos_y_etapas.md`. 2025: DG → GF → goles de visitante → Ranking CONMEBOL (no calculable) → sorteo. 2026: directo una sola vez → DG → GF → tarjetas rojas y amarillas (no calculables) → sorteo. Manuales de Clubes citados (2.4.1 puntos; 2.4.2 Lib / 2.4.3 Sud desempates).
6. ✅ Textos: «Grupos no verificados» (vacío y aviso), «Sin tabla» de una copa internacional sin grupos verificados en la temporada («Todavía no hay grupos verificados…»), nota de clasificación por copa, posición compartida «se define por menos tarjetas rojas, menos tarjetas amarillas o sorteo (no disponible)».

**Verificación con datos reales** (`group_tables_test.dart`): en las 4 temporadas, 96 partidos de grupos (las previas de `r=1–3` 2026 quedan afuera), 0 inconsistencias del validador, `strGroup` coincide con el catálogo en los 16 + 96 × 3 partidos que lo traen, 8 tablas completas de 4 × 6 PJ, y **el orden calculado coincide en los 32 grupos con la etapa que jugó después cada equipo** (octavos / playoffs / afuera), sin posiciones compartidas en la línea de clasificación. Casos de la prensa con la tabla parcial: Grupo D al 30/04 (U. Católica 1.º, Boca 2.º pese a mejor DG) y Grupo G al 05/05 (LDU, Lanús, Mirassol); con la regla 2025 los dos salen distintos; re-aplicar el directo no cambia ninguno (la diferencia se prueba con un triple empate armado en `tie_breaker_test`). `WO` (Lib 2025) y `AWD` (Lib 2026) suman con su resultado.

**Ajustes respecto del plan** (en `DECISIONS.md`): nota de clasificación en cada grupo (texto del formato oficial; la app no marca posiciones); la invalidez por grupo marca los dos grupos de un partido cruzado y el del rival de un equipo sin grupo; el mensaje «Sin tabla» se elige por las reglas (eliminación directa vs. copa internacional), no por `format`.

**Validación**: `flutter analyze` sin issues; `flutter test` **789 verdes** (744 + 45 nuevos). Presupuestos: Tabla de una copa en frío = **6** (fechas 1–6), en caliente **0** (`watch_standings_test`, `standings_budget_test`: Libertadores 6, después Sudamericana 5 del fixture + 6 de la tabla, cada consulta una vez); resto de los presupuestos sin cambios. Layout sin desbordes a 360/768/1280/1920 y pautas + texto al 200 % en 360 px con la tabla de grupos.

**Dispositivos con datos grabados** (TheSportsDB respondía en ~20 s por consulta, por encima del timeout de 15 s: tablet `SOP10X2501001122` con el APK release de `tool/recorded_app`, y Web release grabada en el Chrome de la tablet con `adb reverse`):
- Android, horizontal 1280: Libertadores → «Tabla» = exactamente 6 consultas (`r=1–6`); Grupo A y Grupo G iguales a D1 (`d4_android_horizontal_grupo_a.png`, `…_grupo_g.png`); Sudamericana desde la Tabla = 5 del fixture + 6 de la tabla; Sudamericana 2025 con su regla (goles de visitante, 2.4.3; `d4_android_sudamericana_2025.png`).
- Teléfono emulado (400 px, texto al 200 %): sin desbordes; la tabla se alcanza desplazando.
- Web, vertical 800: el enlace `…/4501?temporada=2026&vista=tabla&tabla=grupo-g` abre el Grupo G (`d4_web_tablet_url_grupo_g.png`); elegir el Grupo D y recargar conserva el Grupo D.
- APK normal reinstalado y `build/web/fixtures` borrado al terminar.

**Pendientes observados (previos a D4, también en Primera; fuera de alcance)**: en ~400 px con texto al 200 %, los chips de tabla se apilan (8 grupos = 4 renglones; Primera, 5) y la tabla queda debajo de la primera pantalla; el selector de vistas corta «Calendario» (la fila se desplaza). Una fila de chips con desplazamiento en < 600 px, como las fases en D3, lo resolvería. **Pendiente con la API real**: repetir la prueba contra TheSportsDB cuando responda en menos de 15 s.

### D5 — Series de ida y vuelta y cuadro
- **Objetivo**: series con global, penales y «Avanza X» con evidencia; árbol Octavos → Final; Playoffs de la Sudamericana.
- **Dependencias**: D3 (la tarea 1 puede empezar en paralelo a D4).
- **Tareas**:
  1. `matches/domain/entities/knockout_tie.dart`, `services/tie_pairing.dart`, `TieOutcome.ofTie` + fuente `aggregate`.
  2. `BracketRound.legs`, `BracketSlot.tie` en `knockout_bracket.dart`; series antes de ordenar.
  3. Catálogo: `bracket` continental, `preliminarySeries` (Sud Playoffs), `bracketPhases`.
  4. `watch_knockout_bracket.dart` con las series previas; `bracket_panel.dart` (tarjeta de serie, pie, chips, `bracketUri`).
  5. Fixture: previas y eliminatorias agrupadas por serie (Ida/Vuelta/Global).
  6. `get_match_detail.dart` + `MatchDetail.tie`: «Global» y «Avanza» en el detalle.
- **Dominio**: `KnockoutTie`, `TiePairing`, `TieOutcomeSource.aggregate`, `BracketRound.legs`.
- **Riesgos**: cambiar `BracketSlot` sin romper Primera/Copa (→ `match` de compatibilidad + regresión); penales incompletos (→ solo evidencia).
- **Consultas**: Llaves Lib 4, Sud 5 en frío, 0 en caliente.
- **Aceptación**: Lib 2025 árbol completo hasta la final Palmeiras 0-1 Flamengo; series 2025 empatadas sin `PEN` → «Avanza X (juega la ronda siguiente)»; Lib 2026 octavos con tandas; Sud `PEN` sin tanda → evidencia posterior o «sin dato»; Primera y Copa Argentina idénticas.
- **Pruebas**: `tie_outcome_test` (regresión de partido único, global, `PEN` con/sin tanda, `PEN` contradictorio), nuevo `tie_pairing_test`, `knockout_bracket_test`, `watch_knockout_bracket_test`, `bracket_view_test`, `match_detail_test`, `bracket_budget_test`.
- **Resultado**: vista «Llaves» de ambas copas.

### D6 — Equipos, búsqueda, favoritos y rendimiento
- **Objetivo**: ficha con las copas internacionales, extranjeros encontrables, presupuestos acotados.
- **Dependencias**: D3 (D5 para el corte por eliminación con series).
- **Tareas**:
  1. `_plan` de `watch_team_detail.dart`: ronda del puntero en P1, luego cronológico P2 hasta el límite superior (etapas ya empezadas / etapa del puntero «próximo»). Corte temprano **solo con evidencia** (§8: serie perdida, eliminado en grupos sin posición compartida, final terminada); la ausencia en una ronda no corta.
  2. Arranque bajo demanda en `TeamSearchBloc` + caso de uso (Fecha 1 de grupos de cada copa, 2 peticiones, una vez); acción «Buscar también en copas internacionales».
  3. Fallback online: acepta `leagueIds` con 4501/4724 (`team_dto.dart:45`).
  4. Ficha de equipo extranjero (solo las copas del catálogo + «Otras competiciones»).
- **Dominio**: caso de uso de arranque continental; servicio de evidencia de eliminación (`ContinentalExitEvidence`, Dart puro, sobre lo guardado).
- **Riesgos**: presupuesto de Boca (hoy 27); orden de alternancia; cortar de más (→ solo con evidencia, tests de casos negativos); equipos extranjeros sin `strCountry`.
- **Consultas**: ficha Boca en frío = 27 + etapas ya empezadas de Sud 2026 (menos las cortadas con evidencia; a medir y fijar en el test); arranque búsqueda 2; Inicio y «Tus equipos» 0.
- **Aceptación**: la ficha de Boca muestra Primera, Copa Argentina y Sudamericana; un favorito no dispara sincronización de copas; buscar «Flamengo» encuentra el club tras el arranque; ningún corte sin evidencia.
- **Pruebas**: `team_detail_sync_test` (nuevo total, alternancia, límite superior); tests del corte con datos reales: serie perdida (corta), eliminado en grupos sin compartir (corta), 1.º de grupo Sud ausente en Playoffs (**no** corta), 3.º de Lib que entra en Playoffs Sud (**no** corta), posición compartida en la línea (**no** corta), semanas sin partidos entre fases (**no** corta); `watch_team_detail_test`, `team_detail_page_test`, `team_detail_layout_test`, `team_search_bloc_test`, `watch_favorite_teams_test` (0), `home_request_budget_test` (sin cambios).
- **Resultado**: integración completa con equipos y favoritos.

### D7 — Estabilización (cierre técnico, **sin depender de las finales 2026**)
- **Objetivo**: cerrar el hito con pruebas en dispositivos, regresión y docs, usando las temporadas históricas completas y verificadas.
- **Dependencias**: D1–D6.
- **Tareas**:
  1. Cuadros y finales probados con **2025 completo** (Lib: final Palmeiras 0-1 Flamengo; Sud: final Lanús–Atlético Mineiro) y con las etapas 2026 ya jugadas; la final 2026 vacía se muestra como pendiente (sin «Avanza»).
  2. Pasada en tablet (vertical/horizontal), Chrome y Web release (`DIAGNOSTICS=true`) a 360–1920 px.
  3. Regresión completa de la suite argentina (Primera, Nacional, B Metro, C, Copa Argentina, tablas, cuadros, ficha, favoritos, calendario, caché, rutas Web).
  4. Docs: `CLAUDE.md` (datos de las copas, presupuestos, mantenimiento: ventanas, grupos y reglamento continental cada temporada), `PLAN.md`, `ARCHITECTURE.md`, `DATA_STRATEGY.md`, `API.md`, `DECISIONS.md`, `HITO_D.md`.
- **Riesgos**: superposición con la Fase 19.2 (nov–dic).
- **Consultas**: 0 nuevas (se usan las grabaciones de D1).
- **Aceptación**: `flutter analyze` sin issues, suite completa verde, sin desbordes, Android y Web validados, docs al día.
- **Pruebas**: regresión completa (`flutter test`) + layout/accesibilidad + presupuestos.
- **Resultado**: Hito D cerrado.

### D-F — Finales 2026 (tarea posterior, separada del hito)
- **Cuándo**: cuando la API tenga las semis y finales 2026 (Sud 21/11, Lib ~28/11), con aprobación propia.
- **Tareas**: grabar en `test/fixtures/api/snapshot_2026MMDD/` (≈ 10 peticiones, sin pisar los archivos de los tests), cerrar las ventanas 2026 en el catálogo, tests de las finales 2026 (cuadro completo, «Avanza»/campeón con evidencia), actualizar `docs/API.md`.

## 11. Decisiones (aprobadas por el usuario el 14/10/2026)

1. **Reloj de los tests continentales**: `now:` en `pumpApp`/`RecordedApi`.
2. **Temporadas sin reglamento oficial verificado** → sin tabla.
3. **Vistas por competición**: solo las compatibles (B Metro y C sin segmento «Tabla»).
4. **`shortName` de Copa Argentina** → «Copa Argentina».
5. **Fases previas en el Fixture**; en Llaves, árbol desde octavos + Playoffs de la Sudamericana.
6. **Federal A** fuera de este hito (registrado en `DECISIONS.md`).
7. **D6**: corte temprano solo con evidencia; la ausencia en una ronda nunca corta.
8. **D7** no depende de las finales 2026; las finales van en la tarea posterior D-F.
9. **Reglamentos**: solo desde fuentes oficiales CONMEBOL 2025/2026; lo demás, «pendiente».
10. Sin commits ni PR (los hace el usuario). Se avanza tarea por tarea dentro de cada fase y se espera aprobación entre fases. Orden respecto de la Fase 19.2: a definir cuando llegue (D-F y 19.2 coinciden en nov–dic).

## Verificación
- Cada fase: `flutter analyze` sin issues y `flutter test` verde (suite argentina incluida, como regresión).
- Presupuestos fijados en tests: `home_request_budget_test` (Inicio sin cambios), `continental_budget_test` (Fixture ≤ 5 / 0), `complete_rounds_test` (10/11/11/12 / 0), `standings_budget_test` (6 / 0), `bracket_budget_test` (4 y 5 / 0), `team_detail_sync_test` (nuevo total de Boca).
- Datos: solo JSON reales grabados; tests de catálogo con «cada partido grabado en exactamente una etapa» y `ZoneValidator` sobre los grupos.
- Manual: tablet `SOP10X2501001122` (vertical 800 px y horizontal 1280 px) y Chrome (`flutter run -d chrome`, recarga con URL de copa y vista); Web release con `adb reverse tcp:8080 tcp:8080`.
