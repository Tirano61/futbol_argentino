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

Hallazgo: en Android, sin red y tras reiniciar, los escudos no se ven (`Image.network` no guarda en disco). `TeamBadge` mostrará iniciales; la caché de escudos en disco sigue en el backlog post-MVP.

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

