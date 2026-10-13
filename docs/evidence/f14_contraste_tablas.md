# Fase 14 — Contraste de las tablas de Primera Nacional 2026

Fecha: 12/10/2026. Reglas: punto 3 y 5 del Boletín Especial 6823 y art. 112 (puntos 1 a 3) del Reglamento General de AFA (texto en `f14_reglamento_desempate.txt`).

## 1. `lookuptable` (TheSportsDB, 12/10/2026 22:00 UTC)

Las 5 filas de `lookuptable.php?l=4616&s=2026` coinciden en posición, PJ, PG, PE, PP, GF, GC y Pts con la app calculada sobre las rondas 1–36 grabadas, tomando las 33–36 de la instantánea del mismo momento (`snapshot_20261012/`). Test: `nacional_tables_test.dart`, «contraste con lookuptable».

| Grupo API | Zona | Pos | Equipo | PJ | Pts | DG | GF |
|---|---|---|---|---|---|---|---|
| Group 1 | A | 1 | Ferro Carril Oeste | 33 | 62 | +9 | 37 |
| Group 1 | A | 2 | Deportivo Morón | 33 | 58 | +17 | 51 |
| Group 1 | A | 3 | Godoy Cruz | 32 | 56 | +13 | 42 |
| Group 2 | B | 1 | Tristán Suárez | 33 | 59 | +17 | 32 |
| Group 2 | B | 2 | Temperley | 33 | 59 | +13 | 40 |

Caso real de desempate: Tristán Suárez y Temperley igualan en 59 puntos; los separa la diferencia de gol (art. 112, punto 1), como en `lookuptable`.

Con los `eventsround` del 11/10 (los que usan la mayoría de los tests), la fecha 33 está a medio jugar: Ferro 61 en 32 PJ. Wikipedia en español mostraba esos mismos números ese día.

## 2. Tabla completa vs Promedios Info (consultada el 12/10/2026 ~21:45 ART)

Fuente: [promediosinfo.com — Primera Nacional](https://promediosinfo.com/liga/primera-b-nacional.html) (fecha 33 completa; último partido listado: lunes 12/10). La app: APK release en la tablet, 12/10/2026 21:40 ART, con All Boys–Godoy Cruz **en juego** (0–0).

**Zona A**: 16 de 18 coinciden en posición, Pts, PJ, DG y GF. Godoy Cruz (app 56 en 32 PJ; nota 57 en 33) y All Boys (app 33 en 32; nota 34 en 33) difieren solo por ese partido, que estaba en juego en la app (listado en «Partidos sin sumar» como «en juego») y terminó 0–0 (+1 punto cada uno).

**Zona B**: las 16 filas visibles en la captura (1.º a 16.º) coinciden en posición, Pts, PJ, DG y GF: Tristán Suárez 59, Temperley 59, Atlanta 58, Gimnasia de Jujuy 55, Midland 51, Gimnasia y Tiro 49, Maipú 48, Colegiales 47, San Martín SJ 46, San Martín T 43, Rafaela 42, Almagro 41, Agropecuario 40, Quilmes 39, Patronato 37, Nueva Chicago 36. Chacarita y Güemes no quedaron en la captura.

Capturas: `f14_android_horizontal_zona_a.png`, `f14_android_horizontal_zona_b.png`, `f14_android_cobertura_notas.png`, `f14_android_vertical_zona_a.png`.

## 3. Escudos en Web (problema encontrado y corregido)

En el Chrome de la tablet, con la tabla reordenándose (carga en frío) o al cambiar de zona, cada escudo quedaba en su fila aunque el equipo cambiara (`f14_web_frio_escudos_cruzados.png`, `f14_web_escudos_cruzados_antes.png`). Causa: con `WebHtmlElementStrategy.fallback`, una `Image` ya montada que recibe otra URL no cambia el `<img>`. Corrección: `TeamBadge` pone `key: ValueKey(url)` en la imagen. Con la versión nueva, 4 cambios de zona seguidos muestran el escudo correcto (`f14_web_escudos_corregidos.png`). Android no tenía el problema.
