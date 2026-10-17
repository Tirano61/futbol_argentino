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
| `eventsnext.php` / `eventslast.php?id={idTeam}` | **1** (de local o visitante, cualquier competición; corregido en V9) | Boca → Sudamericana (4724) | D8: «Otras competiciones» de la ficha (Fase 15, TTL 30 min) |

### 2.3 Confirmados pero no aptos con clave gratuita
`eventsseason` (tope 15) · `eventsday` (tope 3) · `search_all_seasons` (tope 5, devuelve las más antiguas) · `search_all_teams` (tope 10) · `lookup_all_teams` (dataset fijo incorrecto: equipos ingleses) · `lookuptable` (5 filas) · `lookupeventstats` / `lookuptimeline` / `lookuplineup` (5 filas).

### 2.4 Estructura real de los datos
**Primera División (4406)**
- `eventsround r=1..16, s=2026` → **30 eventos: 15 del Apertura (ene–may) + 15 del Clausura (jul–dic)**; `strGroup` vacío → la fase no viene en el dato.
- `r=16` → **38**: 15 regulares Apertura (abr) + **8 octavos Apertura (may)** + 15 regulares Clausura (nov).
- `r=0` → **7**: cuartos, semis y final del Apertura (`AET`, `PEN`).
- `r=17`, `32`, `125`, `150`, `160`, `170`, `200` → vacíos. 2025 tiene la misma mezcla.

**Primera Nacional (4616)**: 18 partidos por ronda, sin zonas en eventos; `r=38` vacío; Reducido pendiente.

**Copa Argentina (4500)**: códigos `64` (32 p.), `32` (16), `16` (8), `125` (4), `150` (2), `200` (vacío aún). `PEN`: la tanda viene en `intHomeScoreExtra`/`intAwayScoreExtra` (corregido en la Fase 19.1; vacía en los 32avos de 2026).

**Horarios**: `strTimestamp` UTC sin zona (preferido) · `dateEvent`+`strTime` UTC (a veces `HH:mm`) · `strTimeLocal` inconsistente (20:45 UTC → `18:00`; vacío o null) · `dateEventLocal` = fecha local · varios `00:00:00` ambiguos.

**Estados observados**: `NS`, `1H`, `HT`, `2H`, `FT`, `AET`, `PEN`; `strPostponed: "no"`.

### 2.5 Pendientes de validación

| # | Tema | Cómo |
|---|---|---|
| V1 | Escudos en Flutter Web | ✅ **Resuelto en T0.2 (11/10/2026)**: carga normal bloqueada por CORS en Web; `webHtmlElementStrategy.fallback` funciona (ver «Resultado T0.2») |
| V2 | Código de la final de Copa (¿200?) | ✅ Resuelto: 200 = Final (final 2025) |
| V3 | Reducido de Nacional / playoffs del Clausura | nov–dic 2026 (Fase 19.2) |
| V4 | Estados no observados (`PST`, `CANC`, `ABD`…) | log de estados desconocidos en debug |
| V5 | Significado de `00:00:00` UTC | regla conservadora D5 mientras tanto |
| V6 | Ausencia de tope en `eventsround` | clasificación de calidad de respuesta (§5.3) |
| V7 | Cantidad de rondas de Nacional 2026 | ✅ Resuelto (11/10/2026): 36 fechas (r=37 vacía); explicado en V14 (34 de zona + 2 interzonales) |
| V8–V15 | Validaciones post-MVP | Ver «Validaciones post-MVP — Fase 11» |
| V16–V21 | Copa Libertadores y Copa Sudamericana (Hito D) | ✅ Relevadas en la Fase D1 (14/10/2026). Ver «Hito D — Fase D1» |

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

## Validaciones post-MVP — Fase 11 (12/10/2026, 80 respuestas reales más)

Grabadas en `test/fixtures/api/` (y una instantánea en `snapshot_20261012/`), registradas en su README.

| # | Tema | Resultado |
|---|---|---|
| V8 | Competiciones 5215, 5523, 5524 (+5428, 4724) | ✅ 5215 = **Primera B Metropolitana** (22 equipos, 11 partidos por ronda, ronda 40 próxima) · 5523 = **Torneo Federal A** (varias etapas mezcladas en la numeración: la r1 tiene 35 partidos de marzo a agosto con 37 equipos; la r32, 24) · 5524 = **Primera C** (28 equipos, 14 por ronda) · 5428 = Copa de la Liga Profesional, **discontinuada** (última temporada 2024) · 4724 = Copa Sudamericana (internacional: solo D8). Ninguna trae `strGroup`. `search_all_leagues?c=Argentina` devuelve 5 ligas (incluye básquet y rugby), no las de ascenso: no sirve para descubrir competiciones. |
| V9 | `eventsnext` / `eventslast?id={idTeam}` | ✅ 1 resultado cada uno, **de local o de visitante** (próximo de River: Sarmiento–River) y **de cualquier competición** (próximo de Boca: Sudamericana, r150, ante Vasco da Gama). `eventslast` usa la clave `results`, no `events`. La anotación anterior «solo de local» era incorrecta. |
| V10 | `lookuptable` | ✅ 5 filas, **por zona** (`strGroup`: «Apertura - Group A/B», Nacional «Group 1/2»), con posiciones intercaladas por grupo, `strDescription` (p. ej. «Knockout Phase») y `dateUpdated`. Primera devuelve la tabla final del Apertura 2026. Contraste: puntos, PJ, DG y GF calculados desde los partidos grabados **coinciden en las 5 filas** de Primera y de Nacional. |
| V11 | Paquetes | ✅ `share_plus` 13.3.1: Android (hoja de compartir) y Chrome de Android (Web Share API); «Copiar» como alternativa funciona en Web · `add_2_calendar` **3.0.1** (la 3.1.x requiere un AGP/Kotlin más nuevo y rompe el build): Android abre Google Calendar con el evento precargado y la zona «hora estándar de Argentina»; en Web, un `.ics` propio se descarga bien (UTC, CRLF, UTF-8) · `cached_network_image` 3.4.1: en Android el escudo se ve **sin red tras reiniciar** (archivo en `cache/libCachedImageData`); en Web **falla por CORS**, así que en Web se sigue con `Image.network` + `WebHtmlElementStrategy.fallback`. Evidencia: `docs/evidence/t11_*`. No probado: Chrome de escritorio. **Fase 17**: en Android, Google Calendar interpreta el inicio de un evento de día completo en la zona del dispositivo y muestra el fin como exclusivo: hay que pasar de medianoche a medianoche de Argentina (03:00 UTC a 03:00 UTC del día siguiente); con mediodía UTC ocupaba 2 días y con 00:00 UTC caía el día anterior (probado con `am start -a android.intent.action.INSERT` en la tablet). En Web, `share_plus` usa `mailto:` si el navegador no puede compartir: se desactiva (`mailToFallbackEnabled: false`) y la app copia el texto. Evidencia: `docs/evidence/f17_*`. |
| V12 | Zonas de Primera 2026 con `idTeam` | ✅ **Aprobadas por el usuario el 12/10/2026.** Ver la tabla de abajo. Verificado con los datos: en el Apertura (240 partidos regulares) y en el Clausura (240), cada equipo juega 16 = **14 de su zona (todos distintos) + 2 interzonales**. La fecha 6 es la interzonal (15 cruces) y cada una de las otras tiene un clásico interzonal. Los 240 partidos del Clausura repiten cruce y ronda del Apertura con la localía invertida (art. 14.1.1). Los 8 octavos del Apertura cruzan zonas. |
| V13 | Reglamento Primera 2026 | ✅ Registrado en DECISIONS (D15). |
| V14 | Formato de Primera Nacional 2026 | ✅ **Zonas y formato aprobados por el usuario el 12/10/2026.** [Boletín Especial 6823](https://assets1.afa.com.ar/2026/Lau/Boletin-Especial-6823---Reglamento-del-Campeonato-de-Primera-Nacional-2026.pdf): zonas «A» y «B» de 18, dos ruedas **más una fecha interzonal de ida y vuelta**. En los datos: 34 partidos de zona + 2 interzonales contra el mismo rival, en las rondas **7 y 25** (íntegramente interzonales). Eso explica las **36 rondas** (la prensa habla de las 34 fechas de zona). Los puntos del interzonal **suman en la tabla de zona**: lo confirman `lookuptable` y una tabla publicada (Ferro 62 pts en 33 PJ; sin interzonales serían 56 en 31). |
| V15 | Desempate de Nacional (art. 112 del Reglamento General de AFA, puntos 1 a 3) | ✅ **Resuelto en la Fase 14 (12/10/2026)** con el texto oficial del [Reglamento General de AFA](https://www.afa.com.ar/upload/torneo/Reglamento_General_AFA.pdf) (PDF del sitio de la AFA, del 20/01/2011): 1) diferencia de goles; 2) goles a favor; 3) partidos entre los empatados durante el certamen (puntos, después diferencia de goles, después goles a favor; se repite cuantas veces sea necesario). **No hay Fair Play ni sorteo** en esos puntos. El art. 113 aplica los mismos puntos durante el torneo. El Boletín 6823 (punto 5) los extiende al primer puesto de cada zona; los cuatro descensos se definen con partido/s de desempate (art. 111). Lo que decían las fuentes secundarias sobre un sorteo final no sale del art. 112. Texto en `docs/evidence/f14_reglamento_desempate.txt`. |

### Hallazgos para las fases siguientes
- La ronda 9 del Apertura 2026 se jugó el 2–5 de mayo, junto con los octavos (ronda 16, desde el 2 de mayo): no alcanza con separar por fecha, hay que usar ronda + fase (`PhaseResolver`) para excluir los playoffs.
- Clausura 2026 al 12/10: 178 terminados, 61 por jugar y 1 en juego en las rondas 1–16.
- Nacional 2026 al 12/10: 592 terminados, 55 por jugar y 1 en juego en las rondas 1–36.

### Hallazgos de la Fase 14 (12/10/2026)
- Nacional 2026: las rondas 1–36 grabadas tienen 648 partidos, todos regulares y ubicados; cada equipo juega 34 de su zona y 2 interzonales contra el mismo rival, en las rondas 7 y 25.
- `lookuptable` de Nacional va un paso adelante de los `eventsround` del 11/10 (la fecha 33 se completó el 12/10): para contrastar se usan las rondas 33–36 de `snapshot_20261012/`, grabadas a la misma hora. Con ellas, las 5 filas coinciden (`docs/evidence/f14_contraste_tablas.md`).

### Hallazgos de la Fase 15 (13/10/2026 01:26 UTC, 6 respuestas reales más)
- **Primera B Metropolitana 2026** (5215): la fecha 42 tiene 11 partidos (31/10) y la 43 vuelve vacía: 42 fechas = 22 equipos a dos ruedas (cargado en el catálogo). **2025**: la fecha 1 trae 20 partidos (10 de febrero y 10 de junio): ese año mezclaba dos torneos en la numeración, como Primera; queda sin cantidad de fechas.
- **Primera C 2026** (5524): la fecha 33 vuelve vacía y `eventsnextleague` no devuelve nada aunque la fecha 32 tenía partidos sin terminar. 32 fechas no cierran con 28 equipos todos contra todos: sin cantidad de fechas ni formato hasta investigar el reglamento. **2025**: 26 equipos (13 partidos en la fecha 1).
- **`strLeague` de los punteros por equipo** viene en inglés para las ligas del catálogo («Argentinian Primera Division») y en español para la Sudamericana («Copa Sudamericana»). La sección «Otras competiciones» usa ese nombre; las del catálogo usan el del catálogo.

### Hallazgos de la Fase 19.1 (13/10/2026, sin grabaciones nuevas)
- **Tanda de penales**: los partidos `PEN` traen los goles de la tanda en `intHomeScoreExtra` / `intAwayScoreExtra` (texto). En los JSON grabados: **14 de 19** `PEN` la traen (Primera 2026 r16 y r0; Copa 2026 r32, r16 y r125); los 5 de los 32avos de la Copa 2026 (r64) vienen vacíos. En los `AET` y en el resto, vacíos. Se cruzó con la ronda siguiente: siempre avanza el que ganó la tanda (p. ej. Riestra 1-1 Banfield, 6-7 → Banfield en semis). La app solo la toma con estado `PEN`.
- **Copa 2025**: la API no tiene todas sus rondas (r16 con 4 de 8 partidos, r125 y r150 vacías) y la final (Independiente Rivadavia 2-2 Argentinos, 06/11/2025) figura `FT` sin tanda: no se puede decir quién ganó con los datos.
- **Ronda 0 de Primera**: cuartos, semifinales y final del Apertura se distinguen por equipo (el primer partido de cada uno en la ronda es de cuartos, el segundo de semis…), sin depender de las fechas.
- **Copa 2026**: las semifinales grabadas el 11/10 (25/10) ya cambiaron de fecha en la API (la tablet guardó 28/10 y 14/11 el 13/10).

**Primera División 2026 — zonas (V12)**. Fuente: [sorteo AFA](https://www.afa.com.ar/a/posts/se-realizo-el-sorteo-de-la-liga-profesional-2026-ya-se-conocen-los-grupos-del-torneo-apertura-y-torneo-clausura) (consultada el 12/10/2026), `idTeam` de los partidos grabados. Mismas zonas en Apertura y Clausura (art. 14.1.1, verificado con los datos).

| Zona A | `idTeam` | Zona B | `idTeam` |
|---|---|---|---|
| Platense | 137775 | Argentinos Juniors | 135151 |
| Defensa y Justicia | 135159 | Aldosivi | 135150 |
| Central Córdoba de Santiago del Estero | 137603 | Atlético Tucumán | 135681 |
| Lanús | 135165 | Banfield | 135154 |
| Deportivo Riestra | 137782 | Barracas Central | 137771 |
| Talleres de Córdoba | 136674 | Belgrano | 135155 |
| Boca Juniors | 135156 | River Plate | 135171 |
| Estudiantes de La Plata | 135160 | Gimnasia y Esgrima de La Plata | 135161 |
| Instituto | 137786 | Estudiantes de Río Cuarto | 137773 |
| Gimnasia y Esgrima de Mendoza | 137778 | Independiente Rivadavia | 137777 |
| San Lorenzo | 135173 | Huracán | 135163 |
| Independiente | 135164 | Racing Club | 135170 |
| Newell's Old Boys | 135166 | Rosario Central | 135172 |
| Unión | 135178 | Sarmiento | 135175 |
| Vélez Sarsfield | 135179 | Tigre | 135177 |

Desambiguación: «Estudiantes» (Zona A) = Estudiantes de La Plata; «Gimnasia» (Zona B) = Gimnasia y Esgrima de La Plata; «Gimnasia Mza.» = Gimnasia y Esgrima de Mendoza; «Independiente Rivadavia Mza.» = Independiente Rivadavia. `lookuptable` lo confirma: Estudiantes LP, Boca y Vélez en «Apertura - Group A»; Independiente Rivadavia y River en «Group B».

**Primera Nacional 2026 — zonas (V14)**. Fuente: partición deducida de los 648 partidos grabados (r1–r36), que coincide equipo por equipo con la publicada en la prensa ([El Gráfico](https://www.elgrafico.com.ar/articulo/futbol-de-ascenso/96182/se-sortearon-las-zonas-de-la-primera-nacional-2026), [Cadena 3](https://www.cadena3.com/noticia/futbol/se-sortearon-las-zonas-y-el-fixture-de-la-primera-nacional-2026_501021)) y con `lookuptable` (Ferro, Morón y Godoy Cruz en «Group 1»; Tristán Suárez y Temperley en «Group 2»). **Falta una fuente oficial de la AFA con la lista** (el Boletín 6823 no la incluye).

| Zona A | `idTeam` | Zona B | `idTeam` |
|---|---|---|---|
| Acassuso | 143091 | Agropecuario | 137769 |
| All Boys | 137781 | Almagro | 137787 |
| Almirante Brown | 141011 | Atlanta | 137776 |
| Central Norte | 142489 | Atlético de Rafaela | 135153 |
| Chaco For Ever | 140526 | Chacarita Juniors | 135899 |
| Ciudad de Bolívar | 149544 | Colegiales | 143095 |
| Colón | 135157 | Deportivo Maipú | 141013 |
| Defensores de Belgrano | 137779 | Ferrocarril Midland | 149541 |
| Deportivo Madryn | 142479 | Gimnasia y Esgrima de Jujuy | 137783 |
| Deportivo Morón | 137772 | Gimnasia y Tiro | 144738 |
| Estudiantes de Buenos Aires | 137767 | Güemes | 141012 |
| Ferro Carril Oeste | 137774 | Nueva Chicago | 135167 |
| Godoy Cruz | 135162 | Patronato | 135682 |
| Los Andes | 143087 | Quilmes | 135169 |
| Mitre | 137766 | San Martín de San Juan | 135174 |
| Racing de Córdoba | 144739 | San Martín de Tucumán | 136197 |
| San Miguel | 143096 | Temperley | 135176 |
| San Telmo | 141014 | Tristán Suárez | 141015 |

## Hito D — Fase D1 (14/10/2026, 58 respuestas reales más)

Grabadas en `test/fixtures/api/` (sección «Hito D · Fase D1» del README). Detalle por etapa, grupos con `idTeam` y series en `docs/evidence/d1_grupos_y_etapas.md`; texto oficial de los reglamentos en `docs/evidence/d1_reglamentos_conmebol.txt`.

| # | Tema | Resultado |
|---|---|---|
| V16 | Identificadores y temporadas | ✅ **4501 = Copa Libertadores**, **4724 = Copa Sudamericana** (`lookupleague`: `strCountry` «Worldwide», `strCurrentSeason` 2026). Temporadas `"2025"`, `"2026"` (formato `YYYY`). `search_all_seasons` corta en 5 temporadas (2018–2022 / 2020–2024): no sirve; se consulta `s=` directo. |
| V17 | Rondas por temporada | ✅ Los códigos **cambian entre temporadas**. Libertadores 2025: previas `400` (Fases 1–3 juntas, 30), grupos `1–6`, octavos `16`, cuartos `125`, semis `150`, final `200`. Libertadores 2026: `1`, `2`, `3` = **Fase 1, 2 y 3 (feb–mar) + fechas 1–3 de grupos (abr–may) en la misma ronda**, grupos `4–6`, `16`, `125`, `150` (en curso), `200` vacía. Sudamericana 2025: Primera fase `400` (16, partido único), grupos `1–6`, **playoffs `160`**, `16`, `125`, `150`, final `200`. Sudamericana 2026: `1` = Primera fase (mar) + fecha 1 (abr), grupos `2–6`, **playoffs `32`**, `16`, `125`, `150` (en curso), `200` vacía. Los conteos coinciden con los formatos oficiales; ningún `idEvent` se repite entre rondas. No se usan los códigos de Copa Argentina. |
| V18 | Grupos | ✅ 8 grupos de 4 en las cuatro temporadas, todos contra todos a dos ruedas, 2 partidos por grupo y fecha. **`strGroup` no es confiable**: Libertadores 2026 solo lo trae en `r=2` (las demás fechas, vacío); Libertadores 2025 y Sudamericana (ambas) en todas las fechas de grupos; nunca en previas ni eliminatorias. Los grupos se cargan por `idTeam` (evidencia `d1_grupos_y_etapas.md`). |
| V19 | Series de ida y vuelta y penales | ✅ Las dos piernas vienen en la **misma `r`**, sin id de serie: se emparejan por el par de `idTeam` (a veces la de fecha anterior no es la «ida» esperada: Santa Fe–River 2026). Final a partido único. **2025: sin datos de penales** (todo `FT`, extras vacíos). **2026**: `PEN` en la última pierna; Libertadores trae la tanda en `intHomeScoreExtra`/`intAwayScoreExtra`; la Sudamericana **7 veces `PEN` sin tanda**. En una vuelta `PEN` el resultado del partido puede no ser empate (lo empatado es el global): U. Católica (ECU) 3-4 Juventud con tanda 3-4 es **correcto** (ida 0-1, global 4-4, Juventud ganó 4-3 los penales según la prensa). Sin `AET`. Con la evidencia «el único de los dos que juega un partido posterior **de la misma competición y temporada**» se resuelven todas las series empatadas sin tanda, incluidas las previas 2025 que avanzan dentro de la misma `r=400`, **salvo la final de la Sudamericana 2025** (Lanús 0-0 Atlético Mineiro, `FT`, sin tanda): la API no permite decir el campeón (fue Lanús según el Manual de Clubes Libertadores 2026). |
| V20 | Reglamentos (desempate de grupos, eliminatorias y final) | ✅ **Textos oficiales** de los Manuales de Clubes de CONMEBOL ([Libertadores 2025](https://cdn.conmebol.com/wp-content/uploads/2024/12/Manual-de-Clubes-CL-2025-ESP-Digital.pdf) 2.4.2, [Libertadores 2026](https://cdn.conmebol.com/wp-content/uploads/2025/12/CL-2026-Manual-de-Clubes-ESP-Jun.pdf) 2.4.2, [Sudamericana 2025](https://cdn.conmebol.com/wp-content/uploads/2024/12/Manual-de-Clubes-CS-2025-ESP-Digital.pdf) 2.4.3, [Sudamericana 2026](https://cdn.conmebol.com/wp-content/uploads/2025/12/CS-2026-Manual-de-Clubes-ESP-Jun.pdf) 2.4.3; consultados el 14/10/2026). **2025** (ambas): 1) DG, 2) GF, 3) GF como visitante, 4) Ranking de Clubes CONMEBOL al 16/12/2024, 5) sorteo — sin enfrentamiento directo. **2026** (ambas): 1) entre los empatados, solo sus partidos de grupos: i) puntos, ii) DG, iii) GF; 2) DG total; 3) GF total; 4) menos rojas; 5) menos amarillas; 6) sorteo; «una vez aplicado un criterio, no se regresará a los anteriores». Eliminatorias (previas a ida y vuelta, playoffs, octavos, cuartos, semis): DG del global y después penales (sin alargue ni gol de visitante). Primera fase de la Sudamericana (partido único): penales. Final: alargue y penales. **Contraste con los datos**: con la regla de cada temporada, el orden calculado coincide con quién jugó la etapa siguiente en los 32 grupos (0 diferencias), y la regla 2026 reproduce los dos casos de la prensa con la tabla parcial (Grupo D al 30/04: U. Católica 1.º y Boca 2.º pese a mejor DG; Grupo G al 05/05: LDU, Lanús, Mirassol). Re-aplicar o no el directo al subgrupo no cambia ningún orden real (se implementa sin re-aplicar, como dice la nota). |
| V21 | Otros endpoints | ✅ `lookuptable` (4501/4724): HTTP 200 con **cuerpo vacío** → la tabla se calcula en la app. `eventsseason`: truncado (5–15 eventos) y sin `strGroup` ni extras → no se usa. `eventsnextleague`/`eventspastleague`: 1 evento cada uno; el «pasado» puede estar en juego. `lookupevent`: funciona, trae `strGroup`, extras y más campos (`strDescriptionEN`, `intSpectators`…). `strCountry` del evento es el país de la **sede**. Estados nuevos: `WO` (Colo-Colo 0-3 Fortaleza, Libertadores 2025) y `AWD` (Independiente Medellín 0-3 Flamengo, 2026), con el 0-3 adjudicado: ya se mapean a terminado. |

### Hallazgos para las fases siguientes
- **Etapas que comparten ronda (2026)**: las previas (feb–mar) y los grupos (abr–may) se separan por ventana de fechas, como Apertura/Clausura en Primera. Ventanas reales por etapa en `d1_grupos_y_etapas.md`.
- **Previas 2025 en una sola `r=400`** (Libertadores: Fases 1–3; Sudamericana: Primera fase): van como una sola etapa; el avance de una fase a otra ocurre dentro de la misma ronda.
- **Semifinales 2026 en curso** al grabar (Libertadores: 3 `NS` y 1 en juego; Sudamericana: 2 `FT` y 2 `NS`) y finales sin cargar (`r=200` vacía): los tests de cuadro completo usan 2025; las finales 2026 se graban en la tarea posterior D-F.
- Colo-Colo–Fortaleza (2025) tiene `strTimestamp` `00:00:00` UTC: regla D5 («Horario por confirmar»).
- La ficha de un equipo no puede usar la ausencia en una fecha como eliminación: 1.º de grupo de la Sudamericana no juega los playoffs; los 3.º de Libertadores entran a los playoffs de la Sudamericana y los perdedores de la Fase 3 a sus grupos.

### Hallazgos de la Fase D6 (17/10/2026, 4 respuestas reales más)
- `searchteams.php?t=Flamengo` y `lookupteam.php?id=134287` traen el mismo equipo (Brasil, `idLeague` 4351, `idLeague2` 4501, …): las copas del catálogo sirven para aceptar extranjeros en la búsqueda en línea; `strCountry` no alcanza.
- `eventslast` de Flamengo (17/10, 15:51 UTC) todavía devolvía el partido del Brasileirão del 11/10, no la ida de semifinales de la Libertadores del 16/10: el puntero puede atrasarse; por eso la copa entra a la ficha también por los partidos guardados.
- Con la clave gratuita, TheSportsDB respondió 429 con pocas consultas seguidas durante la prueba en la tablet (17/10): la app pausa, y si el reintento vuelve a dar 429, detiene la descarga de la ficha con «Reintentar».

### Fase D7 (17/10/2026, sin grabaciones nuevas)
- Las semifinales 2026 siguen en curso (vueltas el 21 y 22/10) y `r=200` de las dos copas sigue vacía: las finales 2026 se graban en la tarea D-F, en una instantánea (`test/fixtures/api/snapshot_2026MMDD/`).
- 429 frecuentes con la IP compartida (tablet + PC): en Android la app pausa y sigue; en Web el 429 llega sin CORS y el navegador lo informa como error de red («Sin conexión»), como en D5. «Reintentar» lo resuelve.
