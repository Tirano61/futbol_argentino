# Fase 13 — Contraste manual de las tablas de Primera 2026

Fecha: 12/10/2026. Datos de la app: partidos grabados el 11/10/2026 (`test/fixtures/api/eventsround_4406_r*_s2026.json`), calculados con `RegularSeasonMatches`, `ZoneTableBuilder` y `AnnualTableBuilder`.

## 1. Apertura 2026 (final) vs `lookuptable` (TheSportsDB, 12/10/2026)

Las 5 filas que devuelve `lookuptable.php?l=4406&s=2026` coinciden en posición, PJ, PG, PE, PP, GF, GC y Pts (test `table_builders_test.dart`, «Apertura: coincide con lookuptable»):

| Zona | Pos | Equipo | PJ | PG | PE | PP | GF | GC | Pts |
|---|---|---|---|---|---|---|---|---|---|
| A | 1 | Estudiantes de La Plata | 16 | 9 | 4 | 3 | 19 | 7 | 31 |
| A | 2 | Boca Juniors | 16 | 8 | 6 | 2 | 22 | 9 | 30 |
| A | 3 | Vélez Sarsfield | 16 | 7 | 7 | 2 | 18 | 12 | 28 |
| B | 1 | Independiente Rivadavia | 16 | 10 | 4 | 2 | 29 | 15 | 34 |
| B | 2 | River Plate | 16 | 9 | 2 | 5 | 22 | 12 | 29 |

## 2. Clausura 2026 tras la fecha 10 vs prensa

Fuente: El Economista, 22/09/2026, «Tabla de posiciones Grupo A / Grupo B Clausura 2026» ([A](https://eleconomista.com.ar/deportes/tabla-de-posiciones-grupo-a-clausura-2026-n97345/amp), [B](https://eleconomista.com.ar/deportes/tabla-de-posiciones-grupo-b-clausura-2026-n97347/amp)). La nota da posición y puntos de los 30 equipos y algunos datos sueltos (PG, PP, DG, GF). La app, con los partidos jugados hasta el 22/09/2026 inclusive:

**Zona A** — 15 de 15 coinciden en posición y puntos.

| Pos | Equipo | Pts app | Pts prensa | PJ | PG-PE-PP | GF-GC | DG | Datos de la nota |
|---|---|---|---|---|---|---|---|---|
| 1 | Instituto | 22 | 22 | 10 | 7-1-2 | 13-7 | +6 | 7 PG, 2 PP, DG +6 ✓ |
| 2 | Vélez Sarsfield | 20 | 20 | 10 | 5-5-0 | 15-9 | +6 | invicto 5-5, DG +6 ✓ |
| 3 | Defensa y Justicia | 18 | 18 | 10 | 5-3-2 | 13-11 | +2 | |
| 4 | Gimnasia y Esgrima de Mendoza | 17 | 17 | 10 | 5-2-3 | 14-9 | +5 | DG +5 ✓ |
| 5 | Boca Juniors | 17 | 17 | 10 | 4-5-1 | 14-11 | +3 | 4 PG, 1 PP ✓ |
| 6 | Independiente | 17 | 17 | 10 | 5-2-3 | 10-8 | +2 | 5 PG ✓ |
| 7 | Lanús | 16 | 16 | 10 | 5-1-4 | 13-9 | +4 | DG +4 ✓ |
| 8 | Newell's Old Boys | 16 | 16 | 10 | 4-4-2 | 11-8 | +3 | 4 PG, DG +3 ✓ |
| 9 | Unión | 13 | 13 | 10 | 4-1-5 | 17-16 | +1 | GF 17 ✓ |
| 10 | San Lorenzo | 11 | 11 | 10 | 3-2-5 | 4-8 | −4 | GF 4 ✓ |
| 11 | Estudiantes de La Plata | 10 | 10 | 10 | 3-1-6 | 10-11 | −1 | |
| 12 | Deportivo Riestra | 10 | 10 | 10 | 2-4-4 | 8-10 | −2 | |
| 13 | Platense | 9 | 9 | 10 | 2-3-5 | 9-15 | −6 | DG −6 ✓ |
| 14 | Talleres de Córdoba | 8 | 8 | 10 | 2-2-6 | 11-17 | −6 | más GF que Central Córdoba ✓ |
| 15 | Central Córdoba de Santiago del Estero | 8 | 8 | 10 | 2-2-6 | 7-13 | −6 | último ✓ |

**Zona B** — 15 de 15 coinciden en posición y puntos.

| Pos | Equipo | Pts app | Pts prensa | PJ | PG-PE-PP | GF-GC | DG | Datos de la nota |
|---|---|---|---|---|---|---|---|---|
| 1 | Argentinos Juniors | 18 | 18 | 10 | 5-3-2 | 13-9 | +4 | 2 PP, DG +4 ✓ |
| 2 | Rosario Central | 18 | 18 | 10 | 5-3-2 | 11-8 | +3 | 5 PG, DG +3; «el orden lo define la diferencia de gol» ✓ |
| 3 | Independiente Rivadavia | 17 | 17 | 10 | 5-2-3 | 14-13 | +1 | 5 PG ✓ |
| 4 | Gimnasia y Esgrima de La Plata | 17 | 17 | 10 | 5-2-3 | 15-15 | 0 | 10 PJ, 5-2-3 ✓ |
| 5 | Belgrano | 16 | 16 | 10 | 4-4-2 | 11-7 | +4 | 4 PG ✓ |
| 6 | Huracán | 16 | 16 | 10 | 4-4-2 | 10-8 | +2 | DG +2 ✓ |
| 7 | Sarmiento | 16 | 16 | 10 | 5-1-4 | 17-16 | +1 | 4 PP, GF 17 ✓ |
| 8 | River Plate | 13 | 13 | 10 | 4-1-5 | 13-12 | +1 | |
| 9 | Atlético Tucumán | 13 | 13 | 10 | 3-4-3 | 7-6 | +1 | |
| 10 | Tigre | 12 | 12 | 10 | 3-3-4 | 9-9 | 0 | 4 PP ✓ |
| 11 | Barracas Central | 12 | 12 | 10 | 3-3-4 | 5-7 | −2 | |
| 12 | Banfield | 9 | 9 | 10 | 2-3-5 | 11-16 | −5 | |
| 13 | Aldosivi | 8 | 8 | 10 | 2-2-6 | 12-16 | −4 | 2 PG ✓ |
| 14 | Racing Club | 8 | 8 | 10 | 2-2-6 | 11-16 | −5 | 14.º ✓ |
| 15 | Estudiantes de Río Cuarto | 6 | 6 | 10 | 1-3-6 | 5-13 | −8 | 10 PJ, 1 PG ✓ |

Nota: Belgrano y Huracán (16 pts, DG +4 y +2) quedan delante de Sarmiento (16, DG +1); Aldosivi (DG −4) delante de Racing (−5): el desempate por diferencia de gol coincide con el orden publicado.

## 3. Tabla Anual 2026

No se encontró una Tabla General publicada con fecha de corte comparable: la página de la LPF carga las tablas con JavaScript (la descarga no trae filas) y la prensa indexada no transcribe la anual. La anual se valida por construcción: para cada equipo es igual a la suma de sus filas de zona del Apertura y del Clausura (test «Tabla Anual = zona del Apertura + zona del Clausura»), y las dos partes están contrastadas arriba. **Pendiente**: contrastarla a mano con la Tabla General oficial cuando se pueda ver (por ejemplo, desde un navegador).
