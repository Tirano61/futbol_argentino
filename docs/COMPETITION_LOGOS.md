# Logos de las competiciones

Procedencia y condiciones de uso de los logos que muestra el selector de competición (`CompetitionLogo`, `lib/features/competitions/presentation/widgets/competition_logo.dart`). Aprobado el 18/10/2026 (análisis previo en la conversación de esa fecha; decisión D29 en `DECISIONS.md`).

## Archivos

Cada asset `assets/competitions/<idLeague>.png` es el `strBadge` de la liga en TheSportsDB (`lookupleague.php?id=`), en su variante **`/small`** (200 × 200 px, PNG RGBA con transparencia), descargado el **18/10/2026** y guardado **sin cambios** (sin recortar, recolorear ni redimensionar). La fecha de carga sale del número del nombre del archivo en TheSportsDB.

| idLeague | Competición | Logo | URL de origen (`strBadge`; el asset es `<URL>/small`) | Cargado en TheSportsDB | Bytes | SHA-256 del asset |
|---|---|---|---|---|---|---|
| 4406 | Primera División | Liga Profesional de Fútbol (LPF) | `https://r2.thesportsdb.com/images/media/league/badge/rk9xhx1768238251.png` | 12/01/2026 | 10 677 | `82929b6844720ec56813e4d40f1135e12e4e7f35152a1dca736006c19f0d7547` |
| 4616 | Primera Nacional | Primera Nacional (AFA) | `https://r2.thesportsdb.com/images/media/league/badge/u5tbaw1762466392.png` | 06/11/2025 | 17 111 | `50b775726f7c460bd959bf15084ae20d54d91dbf65570b8a4b2530981eddd95e` |
| 4500 | Copa Argentina | Copa Argentina | `https://r2.thesportsdb.com/images/media/league/badge/welbig1655924428.png` | 22/06/2022 | 13 851 | `2b0655463c19b681dfd28b85340049e81e33c678ac5ab2a442713e1474396e1d` |
| 5215 | Primera B Metropolitana | «Primera B» (AFA) | `https://r2.thesportsdb.com/images/media/league/badge/5vbn1s1784161051.png` | 16/07/2026 | 14 385 | `9cf25c3ab77015e6b1d1d39cf93034241381bcc0611065b1f997c1cc7867fef7` |
| 5524 | Primera C | «Primera C» (AFA) | `https://r2.thesportsdb.com/images/media/league/badge/6j0rlo1734111674.png` | 13/12/2024 | 13 793 | `e859383d0535f64108363571d687d546121a0572c8858b89812aec7318f45c21` |
| 4501 | Copa Libertadores | CONMEBOL Libertadores | `https://r2.thesportsdb.com/images/media/league/badge/9shr931685425181.png` | 30/05/2023 | 19 135 | `f2c89415c6afb763c269744b2d6c37df0c0805aa50f81763c56739fbb99f37fe` |
| 4724 | Copa Sudamericana | CONMEBOL Sudamericana | `https://r2.thesportsdb.com/images/media/league/badge/9yynq01685425243.png` | 30/05/2023 | 17 966 | `ab90b65c5b059995c0d430c75d2644de5d9bff33c0a035308140e95d52bbd71a` |

Los siete son logos **de la competición** (ruta `/league/badge/` del `lookupleague` de cada liga), no escudos de equipos. Primera División usa la marca de la LPF, que organiza el torneo. Se descartó `strLogo` (rectángulo de 800 × 310 con el nombre, ilegible a 28 dp; en Primera es el logo anterior de la LPF, en Copa Argentina el de «Copa Total Argentina», y Nacional, Libertadores y Sudamericana son solo texto blanco). B Metro y Primera C no tienen otra imagen que el `strBadge`.

El test `test/features/competitions/presentation/competition_logo_test.dart` comprueba que cada asset sea un PNG de 200 × 200 con transparencia y que su URL de origen coincida con el `strBadge` de las grabaciones (`test/fixtures/api/lookupleague_<id>.json`; la Nacional, en `search_all_leagues_Argentina.json`).

## Presentación

- Logo de 28 dp con `BoxFit.contain` dentro de un recuadro de 36 dp (`AppSizes.competitionLogo` / `competitionLogoTile`) de color oscuro neutro **igual en los dos temas** (`AppPalette.logoBackdrop`). Casi todos los logos tienen partes blancas (el nombre de la Nacional, las astillas de la Copa Argentina, el borde de B y C, el texto CONMEBOL) que en un fondo claro desaparecen; como no se pueden modificar, el recuadro los muestra completos en ambos temas.
- Solo en el selector de competición: título de la barra, hoja inferior (< 600 px) y menú (≥ 600 px). No en Inicio, encabezados, fases, rondas, temporadas ni pestañas.
- Sin logo (competición nueva en el catálogo) o si el asset no carga: el mismo recuadro con un ícono de la categoría (trofeo para copas, pelota para ligas).
- Assets locales: se ven sin conexión en Android y no hacen peticiones a la API ni a `r2.thesportsdb.com`. En Web se sirven desde el mismo origen que la app (sin CORS).

## Condiciones de uso

Términos de TheSportsDB (`https://www.thesportsdb.com/docs_terms_of_use.php`, versión del 17/09/2026), lo que aplica:

- El contenido que devuelve la API se puede copiar y guardar.
- **«Any trademarked sports logos must be used 'As is' and should not be modified in any way. This does not grant permission to use a third-party trademark.»** Por eso los assets son los archivos originales y el recuadro va detrás, sin tocar la imagen.
- Hay que mencionar la fuente y enlazar el sitio cuando corresponda: Ajustes › Fuente, «Datos e imágenes: TheSportsDB» con enlace a `https://www.thesportsdb.com/`, y la aclaración de que logos y escudos pertenecen a sus dueños.
- Con la clave gratuita no se puede publicar en tiendas de aplicaciones.

Los logos son marcas de sus titulares (LPF, AFA y CONMEBOL). La app es de **uso personal**. **Antes de cualquier publicación en tiendas o distribución pública** hay que verificar los derechos de uso de cada logo (permiso de cada titular) y las condiciones vigentes de TheSportsDB (clave paga, registro imagen por imagen de origen, licencia y permisos). La atribución en Ajustes **no reemplaza** esos permisos.

## Mantenimiento

Cada temporada, al grabar `lookupleague` de nuevo: si el `strBadge` de una liga cambió, `competition_logo_test.dart` falla. Entonces bajar la variante `/small` de la URL nueva, reemplazar el asset sin modificarlo y actualizar la URL en el test y en esta tabla (con fecha, bytes y SHA-256).
