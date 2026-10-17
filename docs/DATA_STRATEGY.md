# Estrategia de datos: carga incremental, caché, merge y sincronización

> Generado desde el Plan Maestro v2 (aprobado el 11/10/2026). Las referencias «§N» apuntan a secciones de [PLAN.md](PLAN.md).

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
Stores: `events` (key `idEvent`), `teams`, `competitions`, `query_meta` (`"round:4406:2026:12"`, `"next:4406"`…), `favorites` (key `idTeam`, Fase 8), `settings` (registro `app`, Fase 16). ~1.200 eventos/temporada ≈ 0,6 MB.

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

## Estado de implementación (Fase 7, 12/10/2026) — Equipos y P2

**Índice de equipos (§5.7)**
- Se arma con los partidos guardados (store `events`, sin reconstruir cada partido): no hay un índice aparte que mantener sincronizado.
- Bootstrap (`EnsureTeamIndex`, P1): primera etapa de cada competición del catálogo (Primera fecha 1 = 30 equipos, Nacional fecha 1 = 36, Copa 32avos = 64) → 81 equipos en 2026. 3 peticiones en frío; esas rondas suelen estar cerradas (TTL 30 días).
- Competiciones de cada equipo: las de su temporada más reciente guardada (un equipo que jugó la Copa 2025 pero no la 2026 no la muestra).
- Respaldo en línea: solo sin coincidencias locales, con ≥ 3 letras y con el índice ya cargado; `searchteams` filtrado a `strCountry = Argentina` y `strSport = Soccer`.

**Ficha del equipo (P2)** — `WatchTeamDetail`
1. Emite lo guardado enseguida.
2. `lookupteam` (P0, TTL 7 días) + bootstrap del índice (P1): con la fecha 1 / 32avos de la temporada se sabe en qué competiciones juega (sin depender de `idLeague…` de la API, que puede estar desactualizado).
3. Todas las rondas de la temporada de esas competiciones (Boca: 17 de Primera + 6 de Copa = 23), **de a una** con P2: de la última a la primera, alternando competiciones. Las vigentes no generan peticiones (las del Inicio ya están).
4. Un error detiene la descarga (las siguientes fallarían igual) y se avisa «No se pudieron completar los partidos (n/N)» con «Reintentar».
5. Refresco manual: fuerza con P0 solo las rondas con partidos del equipo sin terminar entre ayer y +7 días; el resto respeta la vigencia (no se gastan 23 peticiones).

**`SyncScheduler`**
- P2: cupo de **10 inicios por minuto** (ventana deslizante; `Clock`/`Delay` inyectables), **de a uno** (siempre queda lugar para P0/P1) y **en pausa con la app oculta** (`pause`/`resume`; P0/P1 siguen). Un P2 en cola pedido como P0 sube de prioridad y no espera el cupo.
- `CancelToken` por dueño: al cancelar se descartan los trabajos **en cola** que solo esperaba ese dueño (`SyncCancelled`); un trabajo compartido con otro (p. ej. una ronda que también pidió el Inicio) sigue; uno en curso termina y sus datos se guardan.

**Medido**: Boca en frío = 25 peticiones (1 + 3 + 21 P2 en tandas de 10 a los 0, 60 y 120 s); en caliente = 0. En la tablet: al salir de la ficha con 8 rondas pendientes, 0 peticiones en los 80 s siguientes; con la app en segundo plano, 0 peticiones aun con cupo libre, y al volver siguió sola.

---

## Estado de implementación (Fase 8, 12/10/2026) — Favoritos

- Store `favorites` (clave `idTeam`): `teamId`, nombre, escudo y `addedAt` de cuando se agregó; no vence ni se sincroniza con la API. Archivo en Android, IndexedDB en Web (cada plataforma tiene los suyos).
- «Tus equipos» del Inicio: **0 peticiones**. Lee los partidos guardados de los favoritos con una consulta reactiva de sembast (`onSnapshots` sobre `events`, filtrada por `teamIds`); se actualiza cuando el Inicio, un fixture o una ficha guardan partidos. Cubre lo que ya cargan el Inicio (ronda actual y siguiente de cada competición) y las fichas abiertas; un favorito sin partidos guardados lo indica y la ficha completa el resto (P2).
- Próximo: en juego o sin jugar desde hoy (un `NS` de un día pasado cuenta como disputado y se muestra «Resultado pendiente»). Último: el disputado más reciente.

---

## Estado de implementación (Fase 9, 12/10/2026) — Estabilización

- **Pausa por 429**: el `RateLimiter` expone la pausa (`RateLimitStatus`); mientras dura, la app avisa arriba hasta qué hora y las consultas siguen solas al terminar. La consulta que recibió el 429 falla con `RateLimitFailure` (la pantalla lo muestra con «Reintentar»); las demás esperan en la cola. Sin peticiones nuevas.
- **Refresco manual dentro de los 30 s**: no consulta la red (regla de §5.5) y ahora lo dice («Ya está actualizado»). Se detecta en la pantalla comparando la hora de descarga antes y después (Inicio: la de cada competición).
- Sin cambios en TTL, prioridades ni presupuestos (Inicio ≤ 12 en frío, 0 en caliente; tests de presupuesto sin cambios).

## Estado de implementación (Fase 10.1, 12/10/2026)

- **P2 con la ficha oculta**: si se cambia de sección sin cerrar la ficha, se cancela su descarga (como al cerrarla: como mucho termina la petición en curso) y, al volver, sigue solo con las rondas que faltan (las ya descargadas están vigentes). Tablet: 0 peticiones en 98 s con la ficha de Chacarita oculta a 25/36; al volver pidió las 4 que faltaban (y la ronda en juego, vencida).
- `syncRound` informa si consultó la red: la ficha lo usa para decir «Ya está actualizado».
- ~~**Pendiente**: la espera por el tope propio de 25/min no se avisa en pantalla~~ → resuelto en la Fase 16 (esperas de 3 s o más).

---

## Estado de implementación (Fase 3, 11/10/2026)

- **Persistencia**: sembast (`lib/core/storage/`). Android: archivo en el directorio de soporte de la app; Web: IndexedDB. Si no se puede abrir (p. ej. modo privado), la app usa una base en memoria y sigue funcionando sin guardar entre sesiones.
- **Stores**: `events` (partidos por `idEvent`, formato `MatchRecord` con todo lo que produce el merge), `competitions`, `schedule_pointers`, `query_meta`.
- **Vigencia**: `CacheClass` (TTL de §5.5) + `RoundCachePolicy`. Ajuste: un partido sin cerrar de los últimos 2 días cuenta como «hoy» (10 min), para que el resultado llegue pronto.
- **Repositorios**: `MatchRepositoryImpl` (rondas y partido) y `CompetitionRepositoryImpl` (liga y próximo/último partido), ambos stale-while-revalidate: caché inmediata, refresco al vencer, caché + `refreshError` si falla, `Failure` solo si no hay nada guardado.
- **`SyncScheduler`** (Hito A): cola P0/P1, deduplicación por clave, máx. 2 trabajos simultáneos, un P1 sube a P0 si se pide como visible. `prefetchRound` usa P1.
- **Pendiente (P3, post-MVP)**: la verificación con `lookupevent` de los partidos `orphaned` o faltantes antiguos; por ahora solo se registra en el log.

### Validación en dispositivos (evidencia en `docs/evidence/f3_*`)
| Prueba | Android (tablet) | Web (Chrome en la tablet) |
|---|---|---|
| Primera consulta | RED, 1 petición | RED |
| Repetida dentro del TTL | CACHÉ, 0 peticiones | CACHÉ, sin refresco |
| Modo avión + forzar | CACHÉ + `Failed host lookup` (2 reintentos) | CACHÉ + `Failed to fetch` (sin reintentos) |
| Reinicio sin red | CACHÉ desde el archivo | CACHÉ desde IndexedDB (recarga de página) |

Hallazgo: en Android, sin red y tras reiniciar, los escudos no se ven (`Image.network` no guarda en disco). `TeamBadge` mostrará iniciales; la caché de escudos en disco sigue en el backlog post-MVP. → Resuelto en la Fase 16 (`DiskBadgeImages`).

## Estado de implementación (Fase 6, 11/10/2026) — Inicio

**Qué consulta el Inicio** (`GetHomeFeed`), por competición del catálogo:
1. Próximo y último partido (`eventsnextleague` + `eventspastleague`, TTL 30 min).
2. Como mucho **2 rondas**: la del último partido y la de la etapa siguiente (con `RoundNavigator`); si no hay último o no hay etapa siguiente, la del próximo partido. Cubre la fecha en curso (próximo y último en la misma ronda), el cambio de fecha y la copa (códigos no consecutivos).
3. Los partidos de los punteros se muestran aunque su ronda no se cargue (p. ej. un reprogramado de una fecha anterior, como el de la fecha 11 de Primera del 14/10).

Ventana: de ayer a +7 días en día argentino. Presupuesto: 3 × 2 punteros + ≤ 6 rondas = **≤ 12 en frío**; con todo vigente, **0**. Prioridad P1 (contexto); el refresco manual va con P0 e ignora la vigencia (mínimo 30 s por clave). Durante un refresco cada competición conserva lo que mostraba hasta terminar.

Límite conocido: si una fecha intermedia entra en la ventana (p. ej. jornada entre semana), puede quedar fuera hasta que pase a ser la del último partido.

### Validación en dispositivos (evidencia en `docs/evidence/f6_*`)
| Prueba | Android (tablet) | Web |
|---|---|---|
| Frío (datos borrados / perfil nuevo) | 12 peticiones (6 punteros + 6 rondas) | 12 (Chrome escritorio) |
| Caliente dentro del TTL | 0 (reapertura de la app, 2 veces) | 0 (hot restart, misma IndexedDB) |
| Vencida la vigencia de las rondas en juego (2 min) | — | 2 (solo Primera 12 y Nacional 33) |
| «Actualizar» | 12, prioridad P0 | — |
| Modo avión + «Actualizar» | datos guardados + aviso, la lista no se vacía | — |
| Chrome en la tablet (release) | — | Inicio con escudos; acceso a Copa actualiza la URL |


## Estado de implementación (Fase 12, 12/10/2026) — Historial a pedido, conservación y limpieza manual

**Vigencia por ronda** — `MatchRepository.roundCacheState` (sin red): `missing` / `fresh` / `stale`, más `isClosed` (clase `closed` al descargarla: todo terminado hace > 48 h) e `isComplete` (última respuesta `complete`). `storedSeason(competición, temporada)`: los partidos visibles de todas las rondas guardadas.

**`CompleteRounds`** (`competitions/domain/usecases/`): completa a pedido las rondas de una temporada (por defecto, todas sus etapas según `RoundNavigator`; se le puede pasar una lista, p. ej. las fechas regulares 1–16). Mismo patrón que la ficha del equipo: emite lo guardado enseguida y después una vez por ronda, con `SyncProgress`; P2 (10 por minuto, de a una, en pausa con la app oculta); `CancelToken`; un error detiene la descarga. Por ronda:

| Estado | Condición | ¿Se pide? |
|---|---|---|
| falta | sin `query_meta` | sí |
| vigente | dentro de su TTL | **nunca** (tampoco con refresco manual) |
| cerrada | vencida, `isClosed`, respuesta completa y todo con estado final (terminado **con resultado**, cancelado o abandonado) | no; solo con refresco manual |
| histórica | temporada anterior al año argentino, vencida, respuesta completa y todo con estado final (un postergado también cuenta como final) | no; solo con refresco manual |
| vencida | el resto (partidos sin jugar o sin resultado, respuesta parcial o vacía) | sí |

**Presupuesto** (test `complete_rounds_test.dart`, JSON del 11/10/2026): en frío Primera 2026 = 17 (fechas 1–16 + ronda 0 de eliminatorias del Apertura; las 1–16 solas = 16), Nacional 2026 = 36, Copa 2026 = 6, Primera 2025 = 16. En caliente = 0. Primera 2025 a los 60 días = 0 (histórica). Primera 2026 a los 31 días = 6 (la 11 por un partido reprogramado al 14/10, la 12 en juego y la 13–16; la 0 y la 1–10 quedan «cerradas»). Ninguna pantalla de uso lo llama todavía: lo usarán las tablas (Fase 13) y el calendario (Fase 18). Se prueba desde «Historial» en `/diagnostico`.

**Conservación**: los partidos de temporadas anteriores quedan en la base; no hay purga automática por temporada.

**Limpieza manual** (`/ajustes` → «Datos guardados»): temporadas guardadas por competición, con la cantidad de partidos; la actual (o una posterior) no se puede borrar (regla en el dominio, `DeleteStoredSeasons`, además de la pantalla). `deleteSeason` borra primero las consultas `round:<competición>:<temporada>:*` y `event:<id>` de `query_meta` y después los partidos: si se corta en el medio, quedan partidos sin consulta registrada (se vuelven a pedir), nunca una ronda «vigente» sin partidos. No toca `favorites`, `teams`, `competitions` ni `schedule_pointers`. Lo borrado se vuelve a descargar si se abre.

**Limpieza automática**: pospuesta. Solo borraría partidos `removed` verificados con `lookupevent` hace más de 30 días, y esa verificación no existe (los `orphaned` solo se registran en el log). Hoy ningún partido llega a `removed`; «Historial» muestra por temporada los `orphaned` y los `removed`.

**Hallazgos con datos reales (tablet, 12/10/2026)**:
- Copa 2025 en la API: los octavos (r16) traen 4 de 8 partidos (`partial`) y cuartos y semifinales están vacíos. Esas rondas no quedan «históricas» y se vuelven a pedir al completar esa temporada si venció su TTL (15 min y 24 h): hasta 3 peticiones por vez.
- Nacional 2025: 620 partidos en 34 rondas.

## Estado de implementación (Fase 13, 12/10/2026) — Tablas

- **Qué cuenta**: partidos de la temporada, rondas 1–16, etapa regular según `PhaseResolver` y del torneo de la tabla; solo terminados **con resultado**; cada `idEvent` una vez. La ronda 0 nunca se pide para las tablas; los octavos de la ronda 16 se excluyen por fase. Los sin fase determinada no se suman y se listan en la cobertura.
- **Presupuesto** (tests `watch_standings_test.dart` y `standings_budget_test.dart`): Primera 2026 en frío = 16 (P2, 10 por minuto); en caliente = 0; refresco manual = las fechas con partidos sin terminar de ayer y hoy (P0) + las vencidas cerradas (`CompleteRounds(forceRefresh)`), nunca las vigentes. Copa, Primera 2025 y Nacional 2025: 0 (sin formato). Nacional 2026: ver Fase 14.
- La vista Tabla descarga solo mientras se ve: pasar a Fixture u ocultar la sección cancela las fechas pendientes; al volver sigue con las que faltan.

## Estado de implementación (Fase 14, 12/10/2026) — Tablas de Nacional

- **Qué cuenta**: partidos de 2026 de las rondas 1–36 (todas regulares según el catálogo), terminados con resultado, cada `idEvent` una vez. Cada zona suma los partidos de sus equipos, **interzonales incluidos** (rondas 7 y 25: un rival de la otra zona, ida y vuelta). Un interzonal aparece en la cobertura de las dos zonas y suma una vez a cada equipo.
- **Presupuesto** (tests `watch_standings_test.dart` y `standings_budget_test.dart`): en frío = 36 (P2, 10 por minuto, ~4 min); en caliente = 0. Si una fecha con partidos en juego (vigencia corta) vence mientras espera su turno, la tabla la vuelve a pedir: no es una fecha vigente. Tablet (12/10): con lo guardado, abrir la tabla = 0 peticiones; el refresco manual pidió solo la fecha 33 (partido en juego).

## Estado de implementación (Fase 15, 12/10/2026) — Más competiciones y D8

- **Inicio**: sigue con Primera, Nacional y Copa (`showInHome`): en frío 12, en caliente 0, aunque el catálogo tenga 5 competiciones (test `home_request_budget_test.dart`). Sumar una competición al Inicio cuesta hasta 4 peticiones en frío (2 punteros + 2 rondas): revisar el presupuesto antes.
- **Índice de equipos**: sigue con 3 peticiones en frío (`inTeamIndex`). B Metro y Primera C no se bajan para el índice; sus equipos aparecen al guardar partidos de esas competiciones.
- **Fixture de B Metro / Primera C**: como cualquier liga de una fase: `lookupleague` + 2 punteros + la fecha + la siguiente (precarga P1). Primera C 2026 no tiene cantidad de fechas en el catálogo: la última conocida sale de los punteros y lo guardado. Las temporadas 2025 de las dos quedan sin fechas (sin dato verificado; B Metro 2025 mezcla dos torneos en la numeración).
- **Ficha (D8)**: `eventsnext` + `eventslast` (2 peticiones, P1, vigencia 30 min, store `team_pointers`). **Boca en frío = 27** (25 + 2), en caliente 0; a los 31 minutos, solo los 2 punteros (test `team_detail_sync_test.dart`). Un equipo de B Metro (p. ej. Flandria) completa las 42 fechas de su temporada con P2 (~4–5 min en frío).
- **Tablet (12/10)**: Inicio en release = solo 4406/4616/4500; B Metro = `lookupleague` + punteros + fechas 40 y 41; Primera C = fecha 32; ficha de Boca con lo guardado = los 2 punteros + 1 fecha vencida.

## Estado de implementación (Fase 16, 13/10/2026) — Ajustes, aviso de espera y escudos en disco

- **Ajustes**: store `settings`, un registro `app` (`{v, theme}`); sin red ni vigencia. No entra en «Datos guardados» y el borrado por temporada no lo toca.
- **Aviso de espera**: el `RateLimiter` (25/min) informa en `RateLimitStatus.throttles` cada espera de 3 s o más; la app lo avisa arriba mientras dura (la pausa por 429 tiene prioridad). No cambia el tope, la cola ni los presupuestos. Tablet: «Actualizar» en el Inicio + fechas de B Metro sin guardar, una por segundo = 25 peticiones; la 26.ª esperó con el aviso y siguió sola, sin 429.
- **Escudos en disco (Android)**: `CachedNetworkImageProvider` con la caché `team_badges` (`flutter_cache_manager`: hasta 600 archivos, se borra lo que no se usa en 60 días; ~150 equipos × `/tiny` y `/small`). Las descargas de escudos no pasan por `TheSportsDbClient` (son imágenes de `r2.thesportsdb.com`, no consultas de la API) y no cuentan en el tope. Web sigue con el `<img>` del navegador y su caché. Tablet: con la caché llena, sin red y tras cerrar la app, el Inicio y el fixture muestran los escudos.

## Estado de implementación (Fase 17, 13/10/2026) — Auto-refresco en vivo (D11)

- **Regla**: un partido está «en vivo» si la API lo da en juego (`1H`, `HT`, `2H`…) o si empezó hace menos de 3 h y no terminó (`MatchGrouping.isLive`, la misma regla que la clase `live` de `RoundCachePolicy`).
- **Aviso**: cada 2 min 5 s (vigencia `live` + 5 s), solo con la pantalla visible y la app en primer plano, y solo si lo que muestra la pantalla tiene un partido en vivo. El aviso es una carga normal: el repositorio consulta solo lo vencido. Al volver a la pantalla (otra sección, la app en segundo plano) se pone al día una vez.
- **Presupuesto por aviso** (tests con la grabación del 11/10/2026 a las 17:00, con partidos en juego en la fecha 12 de Primera y la 33 de Nacional): Inicio = 2 (las fechas en juego; punteros y demás fechas siguen vigentes); fixture de Nacional = 1; detalle de un partido en juego = 1 (`lookupevent`; si la ronda se acaba de actualizar desde el fixture, 0); ficha de Boca = 1 (P2); con la pantalla oculta o tapada = 0. Sin partidos en vivo = 0.
- **Tope**: con todo abierto a la vez (Inicio, fixture con panel y una ficha) son unas pocas consultas cada 2 min, lejos de las 25/min.
- **Tablet** (13/10, sin partidos en juego): 5 min con el Inicio abierto = 0 consultas. El refresco con partidos en juego reales queda por verificar en el próximo partido (14/10, Sarmiento–River, 19:00).
- Compartir y agregar al calendario no hacen consultas: usan el partido ya cargado.

## Estado de implementación (Fase 18, 13/10/2026) — Calendario mensual

- **Fuente**: solo los partidos guardados de la temporada (`storedSeason`), agrupados por día argentino. Sin consultas nuevas en la API: el calendario no usa `eventsday` ni otra fuente.
- **Al abrirse**: 0 peticiones. `CompleteRounds(fetch: false)` informa qué rondas faltan o vencieron (sin red); si hay alguna, la vista lo avisa con «Completar».
- **A pedido**: «Completar» = `CompleteRounds` con P2 (10/min, de a una, en pausa con la app oculta o la vista sin verse; cancelable). Mismas reglas que el historial: nunca pide una ronda vigente; las cerradas y las de temporadas terminadas no se vuelven a pedir salvo con «Actualizar» (refresco manual, igual que en las tablas).
- **Presupuesto** (tests con JSON reales del 11/10/2026): Primera 2026 en frío = 17 (fechas 1–16 + ronda 0), Nacional = 36, Copa = 6; en caliente = 0. En la app completa, después del Inicio y del fixture: 15 (las fechas 12 y 13 ya guardadas). Cambiar de competición con el calendario abierto = solo lo que pide el fixture de fondo.
- **Tablet** (13/10): abrir el calendario de Primera, B Metro, Primera C y Copa = 0 peticiones del calendario; «Actualizar» con todo al día = 0; B Metro «Completar» = 18 (fechas 1–17 y 42), sin repetir.

## Estado de implementación (Fase 19.1, 13/10/2026) — Llaves

- **Fuente**: las rondas de eliminación del catálogo (`bracketRounds`): Primera = 16 y 0; Copa = 64, 32, 16, 125, 150 y 200. Sin consultas nuevas en la API.
- **Al abrirse**: como la Tabla, `CompleteRounds` (P2) completa las rondas que faltan o vencieron (nunca las vigentes; las cerradas y las de temporadas terminadas, solo con «Actualizar»).
- **Presupuesto** (tests con JSON reales del 11/10/2026): Primera en frío = 2, Copa = 6, Nacional = 0 (sin cuadro); en caliente = 0. En la app completa, ninguna ronda se pide dos veces en la sesión.
- **Tanda de penales**: llega con la ronda (no hace falta otra consulta). Los partidos guardados antes de la Fase 19.1 la reciben cuando su ronda vence o al actualizar el partido desde su detalle (1 petición, `lookupevent`).
- **Tablet** (13/10): abrir las llaves de Primera y Copa = 0 peticiones (ya guardadas); «Actualizar» con las rondas vigentes = 0.

## Hito D — Plan de datos de Libertadores y Sudamericana (Fase D1, 14/10/2026)

Relevamiento con datos reales (`docs/API.md`, V16–V21): las reglas y los presupuestos que fijan los tests de D3–D6. **Implementado en D3 (15/10/2026)**: la ronda como unidad, la calidad por suma de etapas y los presupuestos del Fixture (≤ 5 / 0, `test/app/continental_budget_test.dart`: liga, 2 punteros, la ronda y la etapa siguiente), «cambiar de categoría» y «Completar» (10 / 11 / 11 / 12 en frío y 0 en caliente, `complete_rounds_test.dart` y `watch_competition_calendar_test.dart`). Inicio sin cambios (`home_request_budget_test.dart`). La ficha de un equipo pide las rondas de las copas desde D6 (ver la tabla). **Hito D cerrado en D7 (17/10/2026) sin consultas nuevas**: todos los presupuestos de esta sección siguen fijados por sus tests.

- **Unidad incremental: la ronda de la API** (`eventsround`), como en las competiciones argentinas. Es la única que existe sin paginación; las etapas que comparten ronda (previas y grupos en 2026) se separan al leer, con las ventanas del catálogo. No se usan `eventsseason` (truncado) ni `lookuptable` (vacío).
- **Rondas por temporada** (únicas, para «Completar»): Libertadores 2025 = 11 (`400`, `1–6`, `16`, `125`, `150`, `200`), 2026 = 10 (`1–6`, `16`, `125`, `150`, `200`); Sudamericana 2025 = 12 (`400`, `1–6`, `160`, `16`, `125`, `150`, `200`), 2026 = 11 (`1–6`, `32`, `16`, `125`, `150`, `200`).
- **Calidad de respuesta**: partidos esperados por ronda = suma de sus etapas (Libertadores 2026: `r=1` 22, `r=2` 32, `r=3` 24); menos → `retrySoon`.
- **Vigencia**: las mismas clases de `RoundCachePolicy`. Una ronda con previas de febrero y grupos de mayo queda `closed` y no se vuelve a pedir.
- **Presupuestos planificados** (frío / caliente):

| Operación | Frío | Caliente |
|---|---|---|
| Abrir el Fixture de una copa (liga + 2 punteros + ronda + siguiente) | ≤ 5 | 0 |
| Cambiar de categoría | solo la competición elegida | 0 |
| Tabla de grupos (`r=1–6`) — verificado en D4 (`standings_budget_test`) | 6 | 0 |
| Llaves: Libertadores (`16`, `125`, `150`, `200`) / Sudamericana (+ playoffs) — verificado en D5 (`watch_knockout_bracket_test`, `bracket_budget_test`) | 4 / 5 | 0 |
| Calendario «Completar» Libertadores / Sudamericana 2026 (2025) | 10 / 11 (11 / 12) | 0 |
| Ficha de un equipo, por copa (solo etapas ya empezadas; corte solo con evidencia) — verificado en D6 (`team_detail_sync_test`, `team_detail_continental_test`): Boca 27 → **37** (+10 de la Sudamericana), Rosario Central 6, Racing 5 | ≤ 10–12 (1 P1 + P2) | 0 |
| Arranque de búsqueda de equipos extranjeros (bajo demanda) — verificado en D6 (`team_search_continental_test`) | 2 | 0 |
| Inicio y «Tus equipos» | +0 | 0 |
