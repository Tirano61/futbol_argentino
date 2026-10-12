# TheSportsDB — endpoints, parámetros y limitaciones

> Generado desde el Plan Maestro v2 (aprobado el 11/10/2026). Las referencias «§N» apuntan a secciones de [PLAN.md](PLAN.md).

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


## Resultado T0.2 — escudos en Flutter Web (11/10/2026)

Prueba: el mismo escudo real (Boca Juniors, `…/team/badge/bm7krb1775741582.png`) en sus variantes original, `/tiny` y `/small`, cargado con `Image.network` y las estrategias `WebHtmlElementStrategy.never` (por defecto) y `.fallback`. Build web release (CanvasKit) servido en `localhost:8080`.

| Entorno | `never` (por defecto) | `fallback` (`<img>`) |
|---|---|---|
| Android nativo (tablet SKY PAD10MAX, Android 14) | ✅ 3/3 | ✅ 3/3 (la estrategia no aplica en nativo) |
| Chrome 154 escritorio (Windows, headless) | ❌ 3/3 — `HTTP request failed, statusCode: 0` | ✅ 3/3 |
| Chrome en la tablet (Web móvil) | ❌ 3/3 — `HTTP request failed, statusCode: 0` | ✅ 3/3 |

Error real de la consola de Chrome:
`Access to XMLHttpRequest at 'https://r2.thesportsdb.com/images/media/team/badge/bm7krb1775741582.png' from origin 'http://127.0.0.1:8080' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.`

**Conclusión**: en Web los escudos **solo** se ven con `webHtmlElementStrategy: WebHtmlElementStrategy.fallback`. Todo escudo de la app pasa por el widget `TeamBadge`, que la aplica siempre.
Limitación conocida del modo `<img>`: la imagen no admite efectos que lean píxeles (filtros de color, shaders); no se necesitan.

Evidencia: `docs/evidence/t0_2_android_nativo.jpg`, `t0_2_web_chrome_escritorio.png`, `t0_2_web_chrome_tablet.jpg`, `t0_2_web_chrome_consola.txt`.

## Fixtures reales (T0.3)
18 respuestas reales grabadas el 11/10/2026 en `test/fixtures/api/` (índice, HTTP, cantidades y hash en `test/fixtures/api/README.md`).

## Hallazgos de la Fase 2 (11/10/2026, 34 respuestas reales más)

- **Primera 2026, Apertura**: 22/01–24/05. La **fecha 9 completa se jugó del 2 al 4 de mayo**; octavos (ronda 16) 9–10/05; ronda 0 (cuartos, semis, final) 12–24/05. Una división fija por meses ubicaría mal la fecha 9.
- **Primera 2026, Clausura**: desde el 23/07; programado hasta el 08/11 (fecha 16). Eliminatorias aún sin datos.
- **Primera 2025**: Apertura 23/01–04/05, Clausura 11/07–17/11. **La API no tiene las eliminatorias de 2025** (r=0 vacía, r=16 solo 15 partidos).
- **Fechas repartidas**: hay fechas con partidos postergados semanas después (2025 Clausura fecha 6: 22/08 y 24/10).
- **Primera Nacional 2026**: 36 fechas de 18 partidos (r=37 vacía).
- **Horarios `00:00` UTC**: en los datos grabados hay 42 casos con `strTimeLocal = 21:00` (corroborados) y 7 sin corroborar (`strTimeLocal` 16:00, 18:00, 19:00, 19:30, 19:45 o vacío).
- **`strTime` sin segundos** (`"20:00"`) en 16 eventos.

## Hallazgos de la Fase 7 (12/10/2026, 6 respuestas reales más)

- **`searchteams.php?t=`** (1 resultado con la clave gratuita): `t=River` → River-PI (Brasil); `t=River Plate` → River Plate; `t=Boca` → Boca Unidos (Federal A). El espacio como `+` o `%20` da la misma respuesta (verificado por hash) y no distingue mayúsculas. Por eso es solo un respaldo: el índice local encuentra «river» y «boca» sin red.
- **`lookupteam`** trae `strStadium`, `strLocation` y `idLeague…idLeague7` (Boca: 4406, 5428, 4500, 4724). La app no usa esas ligas para decidir qué rondas descargar: las competiciones salen de los partidos guardados.
- **Copa Argentina 2026**: 16avos (`r=32`, 16 partidos, abr–jul) y octavos (`r=16`, 8, ago–sep) grabados. Boca aparece en 32avos, 16avos, octavos, cuartos y semifinales.
- **Primera 2027** (`r=1`): `events: null` al 12/10/2026 (sirve para probar que el índice recurre a la temporada anterior).

## Corrección y hallazgos de la Fase 4 (11/10/2026)

- **No hay mojibake en la API.** Lo informado en la Fase 0 (`eventsday` con `R�­o Cuarto`) fue un error de inspección: Python en Windows decodifica los pipes como cp1252 y los `repr` escapan `­`. Verificado decodificando explícitamente como UTF-8: los 65 fixtures (incluido `eventsday`) son UTF-8 correcto. `RoundMergePolicy.looksGarbled` queda como defensa barata.
- **Copa Argentina: 200 = Final** (verificado con la final 2025, noviembre 2025). V2 resuelto.
- **Copa Argentina 2025 incompleta en la API**: 32avos 32/32, 16avos 16/16, octavos 4/8, cuartos y semifinales sin datos (ni con 125/150 ni con otros códigos probados: 160, 170, 175, 180, 190), final 1/1. La app muestra esas etapas vacías.
- **Primera Nacional 2025**: 34 fechas (r=35 vacía).
