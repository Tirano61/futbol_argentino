# Fase D1 — Etapas, grupos y series de Libertadores y Sudamericana (datos grabados)

Generado el 14/10/2026 desde los `eventsround_4501_*` y `eventsround_4724_*` grabados ese día (`test/fixtures/api/README.md`, sección «Hito D · Fase D1»). Fechas en hora argentina (UTC−3, desde `strTimestamp`). En 2026, `r=1/2/3` mezclan previas (feb–mar) y grupos (abr–may): acá se separan por mes.

## Copa Libertadores (4501) 2025

### Etapas

| Etapa | Fase (URL) | `r` | Partidos | Desde | Hasta | Ida y vuelta | Estados | Con `strGroup` |
|---|---|---|---|---|---|---|---|---|
| Fases previas (Fases 1, 2 y 3) | `previa` | 400 | 30 | 04/02/2025 | 13/03/2025 | sí | FT 30 | 0/30 |
| Fecha 1 | `grupos` | 1 | 16 | 01/04/2025 | 03/04/2025 | no | FT 16 | 16/16 |
| Fecha 2 | `grupos` | 2 | 16 | 08/04/2025 | 10/04/2025 | no | FT 15, WO 1 | 16/16 |
| Fecha 3 | `grupos` | 3 | 16 | 22/04/2025 | 24/04/2025 | no | FT 16 | 16/16 |
| Fecha 4 | `grupos` | 4 | 16 | 06/05/2025 | 08/05/2025 | no | FT 16 | 16/16 |
| Fecha 5 | `grupos` | 5 | 16 | 13/05/2025 | 15/05/2025 | no | FT 16 | 16/16 |
| Fecha 6 | `grupos` | 6 | 16 | 27/05/2025 | 29/05/2025 | no | FT 16 | 16/16 |
| Octavos de final | `eliminatorias` | 16 | 16 | 12/08/2025 | 21/08/2025 | sí | FT 16 | 0/16 |
| Cuartos de final | `eliminatorias` | 125 | 8 | 16/09/2025 | 25/09/2025 | sí | FT 8 | 0/8 |
| Semifinales | `eliminatorias` | 150 | 4 | 22/10/2025 | 30/10/2025 | sí | FT 4 | 0/4 |
| Final | `eliminatorias` | 200 | 1 | 29/11/2025 | 29/11/2025 | no | FT 1 | 0/1 |

### Grupos (8 grupos de 4; todos contra todos: sí)

Orden calculado con el reglamento 2025 (`d1_reglamentos_conmebol.txt`) y contrastado con la etapa que jugó después cada equipo (1.º y 2.º → octavos; 3.º → playoffs de la Sudamericana).

| Grupo | Pos | Equipo | `idTeam` | Pts | DG | GF | GF de visitante | Jugó después |
|---|---|---|---|---|---|---|---|---|
| A | 1 | Estudiantes de La Plata | 135160 | 12 | +6 | 11 | 7 | Octavos |
| A | 2 | Botafogo | 134285 | 12 | +3 | 8 | 2 | Octavos |
| A | 3 | Universidad de Chile | 137736 | 10 | +2 | 8 | 3 | Playoffs Sud |
| A | 4 | Carabobo | 137630 | 1 | -11 | 2 | 0 | — |
| B | 1 | River Plate | 135171 | 12 | +6 | 13 | 6 | Octavos |
| B | 2 | Universitario | 138329 | 8 | +0 | 4 | 2 | Octavos |
| B | 3 | Independiente del Valle | 138225 | 8 | -3 | 8 | 3 | Playoffs Sud |
| B | 4 | Barcelona SC | 138159 | 4 | -3 | 4 | 1 | — |
| C | 1 | LDU Quito | 138227 | 11 | +4 | 8 | 3 | Octavos |
| C | 2 | Flamengo | 134287 | 11 | +3 | 6 | 2 | Octavos |
| C | 3 | Central Córdoba de Santiago del Estero | 137603 | 11 | +0 | 7 | 4 | Playoffs Sud |
| C | 4 | Deportivo Táchira | 137634 | 0 | -7 | 4 | 1 | — |
| D | 1 | São Paulo | 134291 | 14 | +6 | 10 | 5 | Octavos |
| D | 2 | Club Libertad | 138294 | 9 | +1 | 6 | 2 | Octavos |
| D | 3 | Alianza Lima | 138311 | 5 | -4 | 7 | 4 | Playoffs Sud |
| D | 4 | Talleres de Córdoba | 136674 | 4 | -3 | 5 | 3 | — |
| E | 1 | Racing Club | 135170 | 13 | +11 | 14 | 8 | Octavos |
| E | 2 | Fortaleza | 136186 | 8 | +3 | 8 | 4 | Octavos |
| E | 3 | Atlético Bucaramanga | 137606 | 6 | -4 | 6 | 2 | Playoffs Sud |
| E | 4 | Colo-Colo | 137724 | 5 | -10 | 5 | 3 | — |
| F | 1 | Internacional | 134281 | 11 | +4 | 12 | 4 | Octavos |
| F | 2 | Atlético Nacional | 137607 | 9 | +1 | 7 | 0 | Octavos |
| F | 3 | Bahia | 134293 | 7 | -2 | 5 | 2 | Playoffs Sud |
| F | 4 | Nacional Montevideo | 135364 | 7 | -3 | 7 | 6 | — |
| G | 1 | Palmeiras | 134465 | 18 | +13 | 17 | 8 | Octavos |
| G | 2 | Cerro Porteño | 138290 | 7 | -4 | 7 | 1 | Octavos |
| G | 3 | Bolívar | 138200 | 6 | +1 | 12 | 3 | Playoffs Sud |
| G | 4 | Sporting Cristal | 138326 | 4 | -10 | 6 | 2 | — |
| H | 1 | Vélez Sarsfield | 135179 | 11 | +7 | 11 | 5 | Octavos |
| H | 2 | Peñarol | 135369 | 11 | +5 | 9 | 4 | Octavos |
| H | 3 | San Antonio Bulo Bulo | 148052 | 6 | -10 | 5 | 0 | Playoffs Sud |
| H | 4 | Club Olimpia | 138296 | 5 | -2 | 9 | 5 | — |

### Series y partidos únicos sin dato de la definición

Global (o resultado) empatado y sin tanda informada. «Juega después» = el único de los dos que aparece en un partido posterior de la misma competición y temporada (evidencia de avance).

| Etapa | Serie | Piernas | Global | Estado de la última | Tanda | Juega después |
|---|---|---|---|---|---|---|
| Fases previas (Fases 1, 2 y 3) | Blooming – El Nacional | 2 | 4-4 | FT | sin dato | El Nacional |
| Fases previas (Fases 1, 2 y 3) | Deportes Iquique – Independiente Santa Fe | 2 | 3-3 | FT | sin dato | Deportes Iquique |
| Fases previas (Fases 1, 2 y 3) | Alianza Lima – Boca Juniors | 2 | 2-2 | FT | sin dato | Alianza Lima |
| Octavos de final | Atlético Nacional – São Paulo | 2 | 1-1 | FT | sin dato | São Paulo |
| Octavos de final | Club Libertad – River Plate | 2 | 1-1 | FT | sin dato | River Plate |
| Cuartos de final | Flamengo – Estudiantes de La Plata | 2 | 2-2 | FT | sin dato | Flamengo |

## Copa Libertadores (4501) 2026

### Etapas

| Etapa | Fase (URL) | `r` | Partidos | Desde | Hasta | Ida y vuelta | Estados | Con `strGroup` |
|---|---|---|---|---|---|---|---|---|
| Fase 1 | `previa` | 1 | 6 | 03/02/2026 | 12/02/2026 | sí | FT 4, PEN 2 | 0/6 |
| Fase 2 | `previa` | 2 | 16 | 17/02/2026 | 26/02/2026 | sí | FT 12, PEN 4 | 0/16 |
| Fase 3 | `previa` | 3 | 8 | 03/03/2026 | 12/03/2026 | sí | FT 7, PEN 1 | 0/8 |
| Fecha 1 | `grupos` | 1 | 16 | 07/04/2026 | 09/04/2026 | no | FT 16 | 0/16 |
| Fecha 2 | `grupos` | 2 | 16 | 14/04/2026 | 16/04/2026 | no | FT 16 | 16/16 |
| Fecha 3 | `grupos` | 3 | 16 | 28/04/2026 | 30/04/2026 | no | FT 16 | 0/16 |
| Fecha 4 | `grupos` | 4 | 16 | 05/05/2026 | 07/05/2026 | no | FT 15, AWD 1 | 0/16 |
| Fecha 5 | `grupos` | 5 | 16 | 19/05/2026 | 21/05/2026 | no | FT 16 | 0/16 |
| Fecha 6 | `grupos` | 6 | 16 | 26/05/2026 | 28/05/2026 | no | FT 16 | 0/16 |
| Octavos de final | `eliminatorias` | 16 | 16 | 11/08/2026 | 25/08/2026 | sí | FT 13, PEN 3 | 0/16 |
| Cuartos de final | `eliminatorias` | 125 | 8 | 08/09/2026 | 17/09/2026 | sí | FT 7, PEN 1 | 0/8 |
| Semifinales | `eliminatorias` | 150 | 4 | 14/10/2026 | 22/10/2026 | sí | NS 3, 1H 1 | 0/4 |
| Final | `eliminatorias` | 200 | 0 | — | — | no | sin datos todavía | |

### Grupos (8 grupos de 4; todos contra todos: sí)

Orden calculado con el reglamento 2026 (`d1_reglamentos_conmebol.txt`) y contrastado con la etapa que jugó después cada equipo (1.º y 2.º → octavos; 3.º → playoffs de la Sudamericana).

| Grupo | Pos | Equipo | `idTeam` | Pts | DG | GF | GF de visitante | Jugó después |
|---|---|---|---|---|---|---|---|---|
| A | 1 | Flamengo | 134287 | 16 | +12 | 14 | 6 | Octavos |
| A | 2 | Estudiantes de La Plata | 135160 | 9 | +1 | 6 | 2 | Octavos |
| A | 3 | Independiente Medellín | 137613 | 7 | -5 | 6 | 4 | Playoffs Sud |
| A | 4 | Cusco | 138320 | 1 | -8 | 4 | 1 | — |
| B | 1 | Coquimbo Unido | 137725 | 10 | +2 | 8 | 2 | Octavos |
| B | 2 | Deportes Tolima | 137609 | 8 | +1 | 7 | 1 | Octavos |
| B | 3 | Nacional Montevideo | 135364 | 8 | -2 | 7 | 3 | Playoffs Sud |
| B | 4 | Universitario | 138329 | 6 | -1 | 5 | 1 | — |
| C | 1 | Independiente Rivadavia | 137777 | 16 | +9 | 15 | 9 | Octavos |
| C | 2 | Fluminense | 134296 | 8 | +0 | 7 | 1 | Octavos |
| C | 3 | Bolívar | 138200 | 5 | -2 | 6 | 2 | Playoffs Sud |
| C | 4 | Deportivo La Guaira | 137644 | 3 | -7 | 6 | 3 | — |
| D | 1 | Universidad Católica | 137735 | 13 | +4 | 8 | 5 | Octavos |
| D | 2 | Cruzeiro | 134294 | 11 | +5 | 8 | 2 | Octavos |
| D | 3 | Boca Juniors | 135156 | 7 | +1 | 6 | 2 | Playoffs Sud |
| D | 4 | Barcelona SC | 138159 | 3 | -10 | 2 | 0 | — |
| E | 1 | Corinthians | 134284 | 11 | +4 | 8 | 4 | Octavos |
| E | 2 | Platense | 137775 | 10 | +1 | 8 | 5 | Octavos |
| E | 3 | Independiente Santa Fe | 137621 | 8 | -1 | 6 | 2 | Playoffs Sud |
| E | 4 | Peñarol | 135369 | 3 | -4 | 4 | 2 | — |
| F | 1 | Cerro Porteño | 138290 | 13 | +4 | 6 | 2 | Octavos |
| F | 2 | Palmeiras | 134465 | 11 | +5 | 10 | 4 | Octavos |
| F | 3 | Sporting Cristal | 138326 | 6 | -3 | 6 | 3 | Playoffs Sud |
| F | 4 | Atlético Junior | 137615 | 4 | -6 | 5 | 1 | — |
| G | 1 | LDU Quito | 138227 | 12 | +3 | 8 | 1 | Octavos |
| G | 2 | Mirassol | 141181 | 12 | +3 | 7 | 2 | Octavos |
| G | 3 | Lanús | 135165 | 9 | -4 | 3 | 0 | Playoffs Sud |
| G | 4 | Always Ready | 138209 | 3 | -2 | 7 | 2 | — |
| H | 1 | Independiente del Valle | 138225 | 13 | +5 | 11 | 3 | Octavos |
| H | 2 | Rosario Central | 135172 | 13 | +8 | 9 | 4 | Octavos |
| H | 3 | Universidad Central | 141313 | 9 | -4 | 7 | 2 | Playoffs Sud |
| H | 4 | Club Libertad | 138294 | 0 | -9 | 4 | 2 | — |

### Series y partidos únicos sin dato de la definición

Global (o resultado) empatado y sin tanda informada. «Juega después» = el único de los dos que aparece en un partido posterior de la misma competición y temporada (evidencia de avance).

| Etapa | Serie | Piernas | Global | Estado de la última | Tanda | Juega después |
|---|---|---|---|---|---|---|
| — | ninguna | | | | | |

## Copa Sudamericana (4724) 2025

### Etapas

| Etapa | Fase (URL) | `r` | Partidos | Desde | Hasta | Ida y vuelta | Estados | Con `strGroup` |
|---|---|---|---|---|---|---|---|---|
| Primera fase | `previa` | 400 | 16 | 04/03/2025 | 06/03/2025 | no | FT 16 | 0/16 |
| Fecha 1 | `grupos` | 1 | 16 | 01/04/2025 | 03/04/2025 | no | FT 16 | 16/16 |
| Fecha 2 | `grupos` | 2 | 16 | 08/04/2025 | 10/04/2025 | no | FT 16 | 16/16 |
| Fecha 3 | `grupos` | 3 | 16 | 22/04/2025 | 24/04/2025 | no | FT 16 | 16/16 |
| Fecha 4 | `grupos` | 4 | 16 | 06/05/2025 | 08/05/2025 | no | FT 16 | 16/16 |
| Fecha 5 | `grupos` | 5 | 16 | 13/05/2025 | 15/05/2025 | no | FT 16 | 16/16 |
| Fecha 6 | `grupos` | 6 | 16 | 27/05/2025 | 29/05/2025 | no | FT 16 | 16/16 |
| Playoffs de octavos | `eliminatorias` | 160 | 16 | 15/07/2025 | 24/07/2025 | sí | FT 16 | 0/16 |
| Octavos de final | `eliminatorias` | 16 | 16 | 12/08/2025 | 21/08/2025 | sí | FT 16 | 0/16 |
| Cuartos de final | `eliminatorias` | 125 | 8 | 16/09/2025 | 25/09/2025 | sí | FT 8 | 0/8 |
| Semifinales | `eliminatorias` | 150 | 4 | 21/10/2025 | 30/10/2025 | sí | FT 4 | 0/4 |
| Final | `eliminatorias` | 200 | 1 | 22/11/2025 | 22/11/2025 | no | FT 1 | 0/1 |

### Grupos (8 grupos de 4; todos contra todos: sí)

Orden calculado con el reglamento 2025 (`d1_reglamentos_conmebol.txt`) y contrastado con la etapa que jugó después cada equipo (1.º → octavos; 2.º → playoffs).

| Grupo | Pos | Equipo | `idTeam` | Pts | DG | GF | GF de visitante | Jugó después |
|---|---|---|---|---|---|---|---|---|
| A | 1 | Independiente | 135164 | 12 | +10 | 16 | 6 | Octavos |
| A | 2 | Club Guaraní | 138293 | 8 | -3 | 9 | 5 | Playoffs Sud |
| A | 3 | Boston River | 136051 | 7 | -2 | 12 | 6 | — |
| A | 4 | Nacional Potosí | 138208 | 7 | -5 | 8 | 1 | — |
| B | 1 | Universidad Católica del Ecuador | 138233 | 14 | +7 | 12 | 5 | Octavos |
| B | 2 | Cerro Largo | 138817 | 7 | -3 | 5 | 4 | Playoffs Sud |
| B | 3 | Vitória | 134280 | 6 | -1 | 3 | 1 | — |
| B | 4 | Defensa y Justicia | 135159 | 4 | -3 | 4 | 2 | — |
| C | 1 | Huracán | 135163 | 14 | +9 | 11 | 5 | Octavos |
| C | 2 | América de Cali | 137604 | 8 | +2 | 6 | 4 | Playoffs Sud |
| C | 3 | Corinthians | 134284 | 8 | +0 | 5 | 2 | — |
| C | 4 | Racing Montevideo | 135370 | 1 | -11 | 3 | 1 | — |
| D | 1 | Godoy Cruz | 135162 | 12 | +5 | 10 | 4 | Octavos |
| D | 2 | Grêmio | 134288 | 12 | +4 | 8 | 4 | Playoffs Sud |
| D | 3 | Atlético Grau | 138313 | 4 | -4 | 5 | 3 | — |
| D | 4 | Sportivo Luqueño | 138300 | 2 | -5 | 4 | 2 | — |
| E | 1 | Mushuc Runa | 138229 | 16 | +8 | 12 | 5 | Octavos |
| E | 2 | Palestino | 137732 | 9 | +0 | 9 | 5 | Playoffs Sud |
| E | 3 | Cruzeiro | 134294 | 5 | -2 | 5 | 2 | — |
| E | 4 | Unión | 135178 | 4 | -6 | 2 | 0 | — |
| F | 1 | Fluminense | 134296 | 13 | +9 | 11 | 2 | Octavos |
| F | 2 | Once Caldas | 137618 | 12 | +2 | 8 | 5 | Playoffs Sud |
| F | 3 | Unión Española | 137733 | 5 | -1 | 6 | 1 | — |
| F | 4 | GV San José | 148051 | 4 | -10 | 5 | 1 | — |
| G | 1 | Lanús | 135165 | 12 | +5 | 9 | 3 | Octavos |
| G | 2 | Vasco da Gama | 134282 | 8 | +0 | 8 | 4 | Playoffs Sud |
| G | 3 | Melgar | 138323 | 7 | -5 | 5 | 1 | — |
| G | 4 | Academia Puerto Cabello | 137643 | 5 | +0 | 8 | 2 | — |
| H | 1 | Cienciano | 138319 | 10 | +6 | 12 | 5 | Octavos |
| H | 2 | Atlético Mineiro | 134299 | 9 | +5 | 11 | 3 | Playoffs Sud |
| H | 3 | Caracas | 137631 | 8 | -2 | 9 | 4 | — |
| H | 4 | Deportes Iquique | 137728 | 4 | -9 | 7 | 1 | — |

### Series y partidos únicos sin dato de la definición

Global (o resultado) empatado y sin tanda informada. «Juega después» = el único de los dos que aparece en un partido posterior de la misma competición y temporada (evidencia de avance).

| Etapa | Serie | Piernas | Global | Estado de la última | Tanda | Juega después |
|---|---|---|---|---|---|---|
| Primera fase | Universidad Católica – Palestino | 1 | 1-1 | FT | sin dato | Palestino |
| Primera fase | Asociación Deportiva Tarma – Cienciano | 1 | 1-1 | FT | sin dato | Cienciano |
| Primera fase | Unión Española – Everton de Viña del Mar | 1 | 2-2 | FT | sin dato | Unión Española |
| Primera fase | Racing Montevideo – Montevideo Wanderers | 1 | 0-0 | FT | sin dato | Racing Montevideo |
| Primera fase | Cerro Largo – Danubio | 1 | 2-2 | FT | sin dato | Cerro Largo |
| Primera fase | Atlético Junior – América de Cali | 1 | 2-2 | FT | sin dato | América de Cali |
| Primera fase | Atlético Grau – Cusco FC | 1 | 0-0 | FT | sin dato | Atlético Grau |
| Primera fase | Universidad Católica del Ecuador – Aucas | 1 | 0-0 | FT | sin dato | Universidad Católica del Ecuador |
| Playoffs de octavos | Atlético Bucaramanga – Atlético Mineiro | 2 | 1-1 | FT | sin dato | Atlético Mineiro |
| Octavos de final | Independiente del Valle – Mushuc Runa | 2 | 2-2 | FT | sin dato | Independiente del Valle |
| Octavos de final | Central Córdoba de Santiago del Estero – Lanús | 2 | 1-1 | FT | sin dato | Lanús |
| Cuartos de final | Independiente del Valle – Once Caldas | 2 | 2-2 | FT | sin dato | Independiente del Valle |
| Final | Lanús – Atlético Mineiro | 1 | 0-0 | FT | sin dato | ninguno |

## Copa Sudamericana (4724) 2026

### Etapas

| Etapa | Fase (URL) | `r` | Partidos | Desde | Hasta | Ida y vuelta | Estados | Con `strGroup` |
|---|---|---|---|---|---|---|---|---|
| Primera fase | `previa` | 1 | 16 | 03/03/2026 | 05/03/2026 | no | FT 10, PEN 6 | 0/16 |
| Fecha 1 | `grupos` | 1 | 16 | 07/04/2026 | 09/04/2026 | no | FT 16 | 16/16 |
| Fecha 2 | `grupos` | 2 | 16 | 14/04/2026 | 16/04/2026 | no | FT 16 | 16/16 |
| Fecha 3 | `grupos` | 3 | 16 | 28/04/2026 | 30/04/2026 | no | FT 16 | 16/16 |
| Fecha 4 | `grupos` | 4 | 16 | 05/05/2026 | 07/05/2026 | no | FT 16 | 16/16 |
| Fecha 5 | `grupos` | 5 | 16 | 19/05/2026 | 21/05/2026 | no | FT 16 | 16/16 |
| Fecha 6 | `grupos` | 6 | 16 | 26/05/2026 | 28/05/2026 | no | FT 16 | 16/16 |
| Playoffs de octavos | `eliminatorias` | 32 | 16 | 21/07/2026 | 30/07/2026 | sí | FT 15, PEN 1 | 0/16 |
| Octavos de final | `eliminatorias` | 16 | 16 | 11/08/2026 | 26/08/2026 | sí | FT 15, PEN 1 | 0/16 |
| Cuartos de final | `eliminatorias` | 125 | 8 | 08/09/2026 | 17/09/2026 | sí | FT 7, PEN 1 | 0/8 |
| Semifinales | `eliminatorias` | 150 | 4 | 13/10/2026 | 21/10/2026 | sí | FT 2, NS 2 | 0/4 |
| Final | `eliminatorias` | 200 | 0 | — | — | no | sin datos todavía | |

### Grupos (8 grupos de 4; todos contra todos: sí)

Orden calculado con el reglamento 2026 (`d1_reglamentos_conmebol.txt`) y contrastado con la etapa que jugó después cada equipo (1.º → octavos; 2.º → playoffs).

| Grupo | Pos | Equipo | `idTeam` | Pts | DG | GF | GF de visitante | Jugó después |
|---|---|---|---|---|---|---|---|---|
| A | 1 | Macará | 138228 | 10 | +3 | 6 | 3 | Octavos |
| A | 2 | Tigre | 135177 | 9 | +3 | 8 | 4 | Playoffs Sud |
| A | 3 | América de Cali | 137604 | 9 | +1 | 6 | 3 | — |
| A | 4 | Alianza Atlético | 140803 | 2 | -7 | 2 | 1 | — |
| B | 1 | Atlético Mineiro | 134299 | 10 | +2 | 8 | 3 | Octavos |
| B | 2 | Cienciano | 138319 | 8 | -2 | 5 | 1 | Playoffs Sud |
| B | 3 | Juventud Las Piedras | 135368 | 7 | +3 | 10 | 3 | — |
| B | 4 | Academia Puerto Cabello | 137643 | 7 | -3 | 6 | 0 | — |
| C | 1 | São Paulo | 134291 | 12 | +5 | 6 | 1 | Octavos |
| C | 2 | O'Higgins | 137731 | 10 | +2 | 8 | 4 | Playoffs Sud |
| C | 3 | Millonarios | 137617 | 8 | +0 | 7 | 5 | — |
| C | 4 | Boston River | 136051 | 3 | -7 | 5 | 0 | — |
| D | 1 | Recoleta | 147065 | 8 | +1 | 6 | 4 | Octavos |
| D | 2 | Santos | 134286 | 7 | +2 | 8 | 2 | Playoffs Sud |
| D | 3 | San Lorenzo | 135173 | 7 | +1 | 6 | 3 | — |
| D | 4 | Deportivo Cuenca | 138221 | 6 | -4 | 3 | 0 | — |
| E | 1 | Botafogo | 134285 | 16 | +10 | 15 | 9 | Octavos |
| E | 2 | Caracas | 137631 | 9 | +0 | 9 | 6 | Playoffs Sud |
| E | 3 | Racing Club | 135170 | 8 | +2 | 11 | 5 | — |
| E | 4 | Independiente Petrolero | 140718 | 0 | -12 | 3 | 0 | — |
| F | 1 | Montevideo City Torque | 138818 | 13 | +6 | 11 | 5 | Octavos |
| F | 2 | Grêmio | 134288 | 11 | +5 | 8 | 3 | Playoffs Sud |
| F | 3 | Deportivo Riestra | 137782 | 5 | -6 | 4 | 2 | — |
| F | 4 | Palestino | 137732 | 3 | -5 | 1 | 0 | — |
| G | 1 | Club Olimpia | 138296 | 13 | +4 | 10 | 4 | Octavos |
| G | 2 | Vasco da Gama | 134282 | 10 | +4 | 10 | 3 | Playoffs Sud |
| G | 3 | Audax Italiano | 137722 | 7 | -2 | 7 | 4 | — |
| G | 4 | Barracas Central | 137771 | 3 | -6 | 2 | 0 | — |
| H | 1 | River Plate | 135171 | 14 | +6 | 9 | 4 | Octavos |
| H | 2 | Bragantino | 134736 | 10 | +7 | 12 | 7 | Playoffs Sud |
| H | 3 | Carabobo | 137630 | 9 | +1 | 6 | 2 | — |
| H | 4 | Blooming | 138203 | 1 | -14 | 3 | 2 | — |

### Series y partidos únicos sin dato de la definición

Global (o resultado) empatado y sin tanda informada. «Juega después» = el único de los dos que aparece en un partido posterior de la misma competición y temporada (evidencia de avance).

| Etapa | Serie | Piernas | Global | Estado de la última | Tanda | Juega después |
|---|---|---|---|---|---|---|
| Primera fase | Independiente Petrolero – Guabirá | 1 | 0-0 | PEN | sin dato | Independiente Petrolero |
| Primera fase | Cobresal – Audax Italiano | 1 | 1-1 | PEN | sin dato | Audax Italiano |
| Primera fase | Academia Puerto Cabello – Monagas | 1 | 0-0 | PEN | sin dato | Academia Puerto Cabello |
| Primera fase | Caracas – Metropolitanos | 1 | 0-0 | PEN | sin dato | Caracas |
| Primera fase | Club Nacional – Recoleta | 1 | 1-1 | PEN | sin dato | Recoleta |
| Primera fase | Cienciano – Melgar | 1 | 1-1 | PEN | sin dato | Cienciano |
| Cuartos de final | Santos – Atlético Mineiro | 2 | 4-4 | PEN | sin dato | Atlético Mineiro |

