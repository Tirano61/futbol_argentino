# Plan Maestro — Hito E: Rediseño Visual y Experiencia de Usuario

> Plan aprobado el 17/10/2026 con las condiciones de abajo. Enlazado desde `docs/PLAN.md`; decisión D28 en `docs/DECISIONS.md`. **Estado: E1, E2 y E3 aprobadas (17/10/2026); E4, E5 y E6 aprobadas (18/10/2026); E7 terminada, esperando aprobación** (resultados de E1 en §20, de E2 en §21, de E3 en §22, de E4 en §23, de E5 en §24, de E6 en §25 y de E7 en §26).
> Las maquetas ASCII de este documento son **ilustrativas**: no son capturas de la app. La maqueta visual de E1 está en `docs/design/hito_e_maqueta.html`.

## Aprobación con ajustes (17/10/2026)

El usuario aprobó E-D1 a E-D14 con cuatro condiciones, ya incorporadas en este plan:

1. **E-D10, marcadores.** Verifiqué `advancingPlaces` en el código: existe en `GroupStage` (`lib/features/competitions/domain/catalog/standings_format.dart:152`), está cargado **por temporada** en el catálogo (Libertadores 2025/2026 = 3, Sudamericana 2025/2026 = 2; `competition_catalog.dart:1282-1337`) y sale de los Manuales de Clubes oficiales (`docs/evidence/d1_reglamentos_conmebol.txt`: Lib 1.º y 2.º a octavos, 3.º a los playoffs de la Sudamericana; Sud 1.º a octavos, 2.º a los playoffs).
   - **Límite**: es un solo número, «puestos que siguen en alguna copa». No distingue octavos de playoffs.
   - **Se marca solo eso**: un único marcador «Sigue en competencia» y, como leyenda, el `qualificationNote` literal del catálogo, que dice el destino de cada puesto.
   - **No se agregan reglas ni datos nuevos.** No hay marcadores en Primera, Nacional ni ninguna tabla sin `advancingPlaces`. Una posición compartida que cruza el corte no se marca.
   - El comentario de `qualificationNote` («la app no lo marca en la tabla») se actualiza en E5.
   - En la maqueta de E1 se muestra para confirmarlo. Si el usuario no lo confirma, los marcadores quedan para una mejora funcional posterior.
2. **E-D8, selector en la AppBar.** Se prototipa en E1 a 360, tablet vertical, tablet horizontal con panel, escritorio Web y texto al 200 %, más un análisis de interferencias. Se implementa en E4 solo con aprobación del usuario.
3. **E-D3, filas compactas.** La altura **siempre depende del contenido**: no hay altura fija ni recortes de información deportiva (§5.1). Lista de casos obligatorios en §5.4.
4. **E1** incluye todo lo pedido (§17.1). Al terminar E1 se presentan las capturas y la maqueta, y el trabajo se detiene. **E2 no empieza sin aprobación.** Los commits y PRs los hace el usuario.

## Contexto

El Hito D cerró la parte deportiva: 7 competiciones, tablas, calendario, llaves, series y fichas. El aspecto visual quedó en el Material 3 de fábrica, armado fase por fase:
- cada partido es una `Card` elevada;
- los avisos son contenedores `tertiaryContainer`, violáceos en oscuro;
- Competiciones apila hasta 6 filas de controles;
- cada pantalla usa sus propios espaciados.

El Hito E busca una app deportiva moderna, compacta y sobria, con FotMob como orientación conceptual y no como copia. **Solo toca la capa de presentación**: la API, la persistencia, la caché, la sincronización, las reglas deportivas, las rutas y la URL quedan intactas, igual que el presupuesto de consultas.

---

## 1. Inventario de pantallas y componentes

| Pantalla | Archivo | Componentes propios | Compartidos que usa |
|---|---|---|---|
| Shell | `lib/app/shell/adaptive_shell.dart` | `NavigationBar` (< 600), `NavigationRail` (600–1199), riel extendido (≥ 1200) | — |
| Barra superior | `lib/app/shell/top_bar_team_search.dart`, `rate_limit_notice.dart` | `TextField` 280 px (≥ 1200), banda de 429 | — |
| Inicio | `features/home/presentation/pages/home_page.dart` | `_Shortcuts` (tarjeta de búsqueda + `ActionChip` por categoría), `_FavoriteTeams` (`ListTile` + hasta 2 `MatchCard`), `_FailedCompetitionsNotice` | `MatchCard`, `matchDayItems`, `SectionHeader`, `StaleDataBanner`, `ErrorView` |
| Competiciones | `features/competitions/presentation/pages/competitions_page.dart` | `_ViewSelector` (`SegmentedButton` medido), panel de detalle de 440 px (≥ 1200) | — |
| Selectores | `competition_picker.dart`, `fixture_controls.dart` | `CompetitionPicker` (botón + hoja / filas de chips medidas), `FixtureSelectors` (temporada `DropdownButton` + chips de fase), `StageNavigator` | — |
| Fixture / series | `competitions_page.dart`, `series_list.dart` | `_SeriesHeader`, `_MissingLeg` | `MatchCard`, `matchDayItems` |
| Tabla | `standings_panel.dart` | `StandingsTableView` (filas propias, columnas por breakpoint, cebra), `_CoverageView` (Card), `_NotesView` | `InfoBanner`, `TeamBadge` |
| Calendario | `calendar_panel.dart` | `_MonthHeader`, `_MonthGrid` (celdas de 56 px con píldora de cantidad), división 480 \| lista (≥ 1200) | `InfoBanner`, `matchDayItems` |
| Llaves | `bracket_panel.dart` | `_BracketCanvas` (columnas 208–264, `_ConnectorPainter`), `_TieCard`, `_TeamLine`, `_ChampionBanner` | `InfoBanner`, `MatchCard` |
| Ficha de equipo | `features/teams/presentation/pages/team_detail_page.dart` | `_Header` (Card, escudo 64, `Chip` de competiciones), `_SyncStatus` (banner propio) | `matchDayItems`, `SectionHeader` |
| Búsqueda / Favoritos / Ajustes | `team_search_page.dart`, `favorites_page.dart`, `settings_page.dart` | banners propios, `Card` + `ListTile` | `EmptyView`, `TeamBadge` |
| Detalle de partido | `features/match_detail/presentation/pages/match_detail_page.dart` | `_Scoreboard` (escudo 64, `headlineMedium`), `Card` de `_InfoTile` (`ListTile`), `_ShareActions` | `MatchStatusChip`, `StaleDataBanner` |
| Compartidos | `lib/shared/presentation/widgets/` | `MatchCard`, `MatchStatusChip`, `matchDayItems`/`DayHeader`, `SectionHeader`, `InfoBanner`, `EmptyView`/`ErrorView`/`StaleDataBanner`, `TeamBadge`, `LiveAutoRefresh`, `refresh_feedback` | — |
| Tema | `lib/app/theme/app_theme.dart` | solo `ColorScheme.fromSeed(0xFF4A9BD9)` + `AppBarTheme` + `CardTheme(margin 4)` | — |

---

## 2. Auditoría visual: capturas y código

**Capturas vigentes.** Las más recientes que representan el diseño actual son las `d7_*` (17/10), y luego las `d6_*`, `d5_*` y `d4_*`. Después de ellas, el selector de competición (D2) y el de vistas (D7) cambiaron. Las `f6_*` (Inicio), `f14_*`, `f18_*` y `hitoA_*` son **anteriores** a esos cambios. **No hay ninguna captura vigente del Inicio**: falta la sección «Tus equipos» y faltan los accesos por categoría. La auditoría del Inicio sale del código. En E1 se generan las capturas de referencia «antes» (§13).

### 2.1 Qué conservar
- La semilla celeste como identidad. Los colores solo desde `colorScheme`: no hay ningún `Color(0x…)` suelto.
- `TeamBadge`, con su caché, el fallback Web, la `ValueKey(url)` y las iniciales.
- La medición del selector de vistas: nunca parte una etiqueta y se desplaza si no entra.
- La tabla sin scroll horizontal, con columnas por ancho y filas de 48 px que abren el equipo.
- En llaves: el ganador en negrita con ✓ y la línea «Ida 1-0 · Vuelta 0-2».
- El panel de detalle a ≥ 1200 y el Inicio en 2 columnas.
- La semántica rica: etiquetas de partido y de posición, encabezados.
- El texto al 200 % y las pautas de accesibilidad que ya se testean.

### 2.2 Hipótesis verificadas, ordenadas por impacto

| # | Problema | Estado | Evidencia |
|---|---|---|---|
| P1 | Competiciones: los controles compiten por el espacio | ✅ **Confirmado, el más grave** | Teléfono (`d7_telefono_selector_vistas`): título, vistas, selector de competición en píldora, temporada, chips de fase cortados («Eliminator…») y ronda. El primer partido arranca al ~65 % de la altura y se ve uno solo. A ≥ 600 hay 2 filas de chips (`d4`, `d7_*_llaves`). |
| P2 | Las tarjetas de partido pesan demasiado | ✅ Confirmado | Una `Card` elevada por partido, con margen 4 y tinte azulado (`match_card.dart:53`). La píldora «Final» se repite en cada tarjeta. El subtítulo («Primera Nacional · Fecha 33») se repite en cada tarjeta (`f6`). El ganador no se distingue. |
| P3 | Inicio sin jerarquía clara | ✅ Confirmado (por código) | En < 1200, la tarjeta «Buscar equipo» duplica el ícono de la barra. Los accesos ocupan 4 encabezados + 4 filas de chips (`home_page.dart:432-498`). «Tus equipos» repite `ListTile` + 2 tarjetas con subtítulos de 2 líneas. «Hoy» queda debajo del pliegue en un teléfono. `SectionHeader` usa `titleLarge` (22) con 24 px arriba. |
| P4 | Pesos inconsistentes | ✅ Confirmado | Hay 4 banners hechos a mano (`home:515`, `team:356`, `search:303`, `rate_limit_notice`) además de `InfoBanner`. El ganador es bold + ✓ en llaves pero nada en las tarjetas. Los anchos máximos son 720, 900 y 1200 según la pantalla. El detalle usa `ListTile` de 72 px por dato. |
| P5 | Espacios vacíos | ✅ Confirmado | Tarjetas centradas con una columna fija de 104 px: a 768–1280 los nombres cortos dejan bandas vacías (`d6_ficha_boca`). En el detalle, 6 `ListTile` ocupan ~430 px (`d5_detalle_serie_penales`). `EmptyView` usa un ícono de 56. |
| P6 | Tema oscuro | ⚠️ Parcial | Las superficies son correctas pero azuladas. Los avisos en `tertiaryContainer` quedan violetas, fuera de marca (`hitoA_tema_oscuro`). Los conectores en `outline` se leen bien (`d7_web_1920`). |
| P7 | Tablas | ⚠️ Parcial | Alineación y columnas ya son correctas. Falta: Pts poco destacado; la cebra junto con la tarjeta de cobertura y 4 renglones de notas pesan; no hay favoritos ni marcadores de clasificación. Las columnas dependen del ancho de la **pantalla** y no del disponible (con el panel de detalle abierto, no del espacio real). |
| P8 | Llaves | ⚠️ Parcial | Funcionan bien. El banner de campeón es una franja llena de `primaryContainer`. Las tarjetas son elevadas. Los conectores no distinguen un cruce definido de uno pendiente. |
| P9 | Uso de anchos | ⚠️ Parcial | El teléfono desperdicia altura (P1). La tablet vertical (800) usa un contenido de 900 con tarjetas centradas. El calendario solo se divide a ≥ 1200 aunque a 1000 px ya entraría. |

---

## 3. Propuesta de estilo

**Tres ideas guía:**
1. Listas en vez de tarjetas: los partidos se agrupan en superficies con divisores finos.
2. Un solo color de marca. Los demás colores solo cuando significan algo: en vivo, aviso, avanza o clasificación.
3. La cifra manda: el marcador, la hora y los puntos tienen el mayor peso de cada fila. El resto queda en gris secundario.

No se usan degradados, sombras decorativas ni animaciones nuevas. El «en vivo» es un punto fijo, sin pulso: una animación infinita además trabaría los `pumpAndSettle`.

---

## 4. Sistema de diseño

**Ubicación de los tokens.** Van en `lib/shared/presentation/theme/`, porque los widgets compartidos los necesitan y `shared` no debe depender de `app`. `lib/app/theme/app_theme.dart` arma el `ThemeData` con ellos. **Prohibido** escribir colores, tamaños de letra o radios sueltos en las pantallas (regla nueva en `CLAUDE.md`).

### 4.1 Paleta (verificada en E1: `docs/evidence/e1_contrastes.md`, 0 fallas)

Se mantiene `ColorScheme.fromSeed` con la semilla celeste. Encima van:
- `copyWith`, para tener superficies **neutras** (grises, sin el tinte azul);
- una `ThemeExtension<AppPalette>` con 4 colores de función.

| Función | Token | Claro | Oscuro | Uso |
|---|---|---|---|---|
| Marca | `primary` | `#1E6BB8` (celeste profundo, ~5,4:1 sobre blanco) | `#7DB8EC` | Selección, pestaña activa, encabezados de día, enlaces |
| Contenedor de marca | `primaryContainer` | `#D6E8F7` | `#1C3A57` | Partido seleccionado, día seleccionado, favorito en tabla (tenue) |
| Fondo | `surface` | `#F3F5F8` | `#0F1215` | Fondo de pantalla |
| Superficie de grupo | `AppPalette.group` (token propio: en oscuro un grupo es más claro que el fondo, al revés que `surfaceContainerLowest` de M3) | `#FFFFFF` | `#171B20` | Grupos de partidos, tabla, tarjetas de llave |
| Superficie secundaria | `surfaceContainerHigh` | `#E8ECF1` | `#232931` | Encabezado de grupo, avisos neutros, «A definir» |
| Divisores | `outlineVariant` | `#E1E5EA` | `#2A3038` | Separadores de filas |
| Bordes y conectores | `outline` | `#7D8792` | `#6B7580` | Conectores de llaves, contorno de chips (contraste ≥ 3:1) |
| Texto principal | `onSurface` | `#15191E` | `#E6E9ED` | Nombres, marcadores |
| Texto secundario | `onSurfaceVariant` | `#5A6470` | `#9AA4AF` | Metadatos, encabezados de tabla |
| **En vivo** | `AppPalette.live` / `liveContainer` | `#C8203A` / `#FDE3E6` | `#FF6B78` / `#4A1A20` | Marcador y etiqueta en juego / entretiempo |
| **Aviso** | `AppPalette.warning` / `warningContainer` | `#8A5A00` / `#FFF1D6` | `#F2B84B` / `#3D2E10` | Postergado, suspendido, resultado pendiente, datos incompletos |
| **Avanza / clasifica** | `AppPalette.success` | `#1B7F3B` | `#5CCB82` | ✓ del que avanza, campeón, marcador de clasificación |
| Error | `error` (del esquema) | — | — | Fallas de API, cancelado |

**El oscuro no es una inversión.** Las superficies suben de luminosidad con la elevación (fondo → grupo → secundaria). Los colores de función usan tonos más claros y menos saturados.

### 4.2 Tipografía

Se queda Roboto: es la de Android, y en Web Flutter la descarga, así que no hay fuentes nuevas. Roboto ya trae cifras tabulares; igual se fija `FontFeature.tabularFigures()` en los estilos numéricos, por si en Web cae otra fuente. La clase `AppText` define extensiones sobre `TextTheme`:

| Rol | Base M3 | Tamaño / peso | Color |
|---|---|---|---|
| Título de pantalla | `titleLarge` (AppBar) | 22 / w500 | `onSurface` |
| Título de sección («Hoy», «Próximos») | `titleMedium` | 16 / w700 (antes 22 / w600) | `onSurface` |
| Encabezado de grupo (competición · fecha) | `labelLarge` | 14 / w600 | `onSurface`; detalle en `onSurfaceVariant` |
| Encabezado de día | `labelLarge` | 13 / w600 | `primary` |
| Equipo en lista | `bodyMedium` | 14 / w400; **ganador w700** | `onSurface` |
| Equipo en héroe (detalle, ficha) | `titleMedium` / `headlineSmall` | 16 / w600 · 24 / w600 | `onSurface` |
| Marcador en lista | `titleMedium` | 18 / w700, tabular | `onSurface`; en vivo `live` |
| Marcador en héroe | `displaySmall` | 36 / w700, tabular | ídem |
| Hora en lista | `titleSmall` | 14 / w600, tabular | `onSurface` |
| Estadísticas de tabla | `bodyMedium` | 14 / w400, tabular; **Pts w700** | `onSurface` |
| Encabezado de tabla | `labelSmall` | 11 / w600 | `onSurfaceVariant` |
| Etiqueta de estado | `labelSmall` | 11 / w600 | según el estado |
| Secundario y notas | `bodySmall` | 12 / w400 | `onSurfaceVariant` |
| Mensaje de estado (banner) | `bodyMedium` | 14 | según el tono |

### 4.3 Espaciado y forma

`AppSpacing`: **4 · 8 · 12 · 16 · 24 · 32**. Ningún otro valor sin una razón escrita.

| Uso | Valor |
|---|---|
| Margen lateral de pantalla | 16 (< 600) · 24 (≥ 600) |
| Entre secciones | 24 |
| Título de sección → contenido | 8 |
| Entre grupos de partidos | 12 |
| Fila de partido (padding) | h 12 · v 8; alto mínimo 56 (crece con texto grande) |
| Fila de tabla | h 8; alto mínimo 48 (es tocable) |
| Controles de un mismo nivel | 8 |
| Radios | 12 (superficies de grupo) · 8 (chips, píldoras, banners, celdas) |
| Escudos | 20 (llaves) · 24 (tabla) · 28 (filas de partido) · 32 (encabezados de grupo y favoritos) · 72 (héroe de ficha y detalle) |
| Elevación | 0 en todo el contenido; la separación sale de la superficie y no de la sombra |

### 4.4 Componentes

Los criterios se aplican con *component themes* en `app_theme.dart`, para no repetir estilos en cada widget:
- **Superficie de grupo** (nueva, `MatchGroup`): `AppPalette.group`, radio 12, sin elevación ni borde, con divisores `outlineVariant` de 1 px entre filas. Reemplaza «una `Card` por partido».
- **Card** (`CardTheme`): elevación 0, `AppPalette.group`, radio 12. Queda para los bloques que no son listas: cabecera de ficha y datos del detalle.
- **Chips** (`ChipTheme`): radio 8, sin tilde (`showCheckmark: false`). El seleccionado va en `primaryContainer` con texto en negrita. Densidad visual compacta, pero el **área táctil sigue en 48** (`MaterialTapTargetSize.padded`), porque lo exigen los tests de pautas.
- **Pestañas de vista** (nuevas, `ViewTabs`): texto con un subrayado de 3 px en `primary` para la activa. Diferencian la navegación de los filtros, que van en chips.
- **Botones**: `FilledButton.tonal` para acciones de contenido (Compartir, Completar, Reintentar en vacío); `TextButton` dentro de los banners; `IconButton` con tooltip en las barras.
- **Menús y selectores**: `DropdownButton` sin subrayado para temporada y ronda (como hoy). Hoja inferior para la competición en < 600; `MenuAnchor` agrupado por categoría en ≥ 600 (decisión E-D8).
- **Etiqueta de estado** (`MatchStatusChip`, rediseñada): ver §5.2.
- **Banner** (`InfoBanner`, ampliado con `tone`: `info` · `warning` · `offline` · `error`): fondo `surfaceContainerHigh`, ícono del color del tono, radio 8, padding 12/8. Sin fondos violetas. `StaleDataBanner` y los 4 banners hechos a mano pasan a usarlo.
- **Divisores** (`DividerTheme`): `outlineVariant`, 1 px, sin espacio extra.
- **Indicadores de carga**: se mantienen los actuales (`CircularProgressIndicator` con etiqueta semántica en la carga inicial y `LinearProgressIndicator` de 3 px en la actualización). **No** se usan *skeletons* ni *shimmer*: los tests dependen de que `pumpAndSettle` avance mientras gira un indicador.

---

## 5. Tarjetas de partido (prioridad alta)

### 5.1 Una fila de partido para todos los contextos

`MatchCard` mantiene su nombre, su `ValueKey(match.id)` y su API (`subtitle`, `onTap`, `selected`, `showAdvance`), para minimizar los cambios en los tests. Cambia el dibujo: pasa a ser una **fila sin `Card`**, que va dentro de un `MatchGroup`. Hay una variante `MatchHero` para el encabezado del detalle.

```
Maqueta ilustrativa — fila compacta (360 px)
┌────────────────────────────────────────────┐
│ Primera División · Clausura · Fecha 13   › │  ← encabezado de grupo (una vez)
├────────────────────────────────────────────┤
│      River Plate (R)  2 – 1  (B) Boca Jrs  │  ← ganador en negrita
│                       Final                │  ← texto gris, sin píldora
├────────────────────────────────────────────┤
│        Racing (R)   17:00   (I) Independ.  │  ← programado: solo la hora
├────────────────────────────────────────────┤
│     Talleres (T)  1 – 1   (B) Belgrano     │
│               ● En juego                   │  ← píldora en vivo, punto fijo
└────────────────────────────────────────────┘
```

- **Altura según el contenido.** No hay alto fijo; 56 es solo el mínimo. La fila crece con nombres de 2 líneas, tanda, notas («Reprogramado», «Avanza…») y texto al 200 %. Nunca se recorta un marcador, una hora, una tanda ni un estado. El único recorte admitido es el nombre de un equipo a partir de la 3.ª línea, porque el nombre completo sigue en la semántica y en el detalle.
- Columna central de **ancho medido**: el ancho del marcador más ancho posible con la escala de texto, en lugar de los 104 fijos.
- **Ganador en negrita**, por marcador o por `TieOutcome.of` (lo mismo que hoy decide «Avanza»).
- Con `subtitle` (ficha de equipo, «Tus equipos»), la línea de contexto queda **arriba a la izquierda**, en `bodySmall` gris. En las listas agrupadas se omite, porque la dice el encabezado.
- `selected`: fondo `primaryContainer` más una barra de 3 px a la izquierda; la señal no es solo de color.
- `matchDayItems` agrupa las filas consecutivas del mismo día en un `MatchGroup`. El Inicio agrupa además por competición (§6).

### 5.2 Estados

El estado nunca depende solo del color: siempre lleva texto, y en las anomalías también ícono.

| Estado (`MatchLabels.status`) | Centro | Etiqueta debajo | Señal no cromática |
|---|---|---|---|
| Programado | hora `HH:mm` | — | — |
| Horario por confirmar | «Horario por confirmar» (2 líneas, `labelSmall`) | — | texto |
| Resultado pendiente | hora en gris | «Resultado pendiente», tono aviso | ícono ⏳ |
| En juego | marcador en `live` | píldora `liveContainer` «● En juego» | punto + texto |
| Entretiempo | marcador en `live` | píldora «● Entretiempo» | punto + texto |
| Final / Final (alargue) | marcador | texto gris «Final» / «Final (alargue)» | ganador en negrita |
| Final (penales) | marcador + «(4-3 pen.)» | texto gris «Final (penales)» | ganador en negrita; nota «✓ Avanza X (4-3 en penales)» en `success` |
| Postergado | «—» | «Postergado», tono aviso | ícono `event_busy` |
| Suspendido / Interrumpido | marcador parcial si existe | tono aviso | ícono `pause_circle` |
| Cancelado | «—» | «Cancelado», tono error | ícono `block` |
| Desconocido | — | texto crudo, gris | — |

### 5.3 Resultados especiales y series
- **Serie de ida y vuelta** (Fixture de copas): un solo `MatchGroup` por serie. Encabezado: «Fluminense – Palmeiras» más «Global parcial 1-2». Luego las dos filas, con «Ida» / «Vuelta» como contexto. Si avanza alguien: pie «✓ Avanza Palmeiras (global 3-1)» en `success`. Sin evidencia: «Sin dato de la definición» en gris, con ícono `help_outline`. Los textos salen de `MatchLabels`, sin cambios.
- **Pierna faltante** (`_MissingLeg`): fila tenue «Vuelta: sin datos en TheSportsDB» dentro del grupo.
- **Clasificación no determinada**: nunca se pinta un ganador sin `TieOutcome`.

### 5.4 Casos obligatorios: maqueta de E1, tests de widget de E2 y capturas
Cada caso se prueba a 360 y a 1280, al 100 % y al 200 %, en claro y oscuro:
- nombres largos en los dos lados («Gimnasia y Esgrima de La Plata» – «Central Córdoba de Santiago del Estero»);
- empate definido por penales con «Avanza X (4-3 en penales)»;
- serie de ida y vuelta: ida jugada y vuelta pendiente (global parcial), serie completa con global, serie definida por tanda, serie sin dato de la definición, pierna faltante;
- cada estado de §5.2: en juego, entretiempo, final, alargue, penales, postergado, suspendido, interrumpido, cancelado, resultado pendiente, horario por confirmar, desconocido;
- «Reprogramado» y «La API ya no lo lista en esta fecha» juntos;
- escudo faltante o que no carga (iniciales);
- fila seleccionada (panel de detalle) y fila no tocable (otras competiciones).

---

## 6. Inicio

```
Maqueta ilustrativa — Inicio en teléfono (360 px)
┌ Fútbol Argentino                 ⟳  ⚙ ┐
│ [🔍 Buscar equipo                    ] │  ← campo de 48 px (se quita el ícono duplicado)
│ Primera División: (Primera)  │ Ascenso: (Nacional)(B Metro)(Primera C) │ Copas… →│ ← 1 fila desplazable
│ Tus equipos                            │
│ ┌(B) Boca Juniors                   ›┐ │
│ │ Próximo · Dom 18/10 · 17:00  Boca – Racing │
│ └────────────────────────────────────┘ │
│ Hoy  · Sábado 17/10/2026               │
│ ┌ Primera División · Clausura · F. 13 ┐│
│ │  fila · fila · fila                  ││
│ └──────────────────────────────────────┘│
│ ┌ Primera Nacional · Fecha 34 ─────────┐│
```

- **Encabezado**: se mantiene «Fútbol Argentino» (lo verifica un test). Búsqueda: en < 1200 queda el campo compacto (48 px) y se quita el ícono duplicado de la barra.
- **Accesos a competiciones**: en < 600, **una sola fila desplazable**. Cada categoría es una etiqueta corta (semánticamente encabezado, en el mismo orden) seguida de sus chips. En ≥ 600, un `Wrap` en un solo bloque. Se mantienen los `ActionChip` y los tooltips «Fixture de X».
- **Tus equipos**: un bloque compacto por equipo. Encabezado con escudo 32, nombre y chevron, que lleva a la ficha; debajo, hasta 2 filas con contexto «Próximo · día» / «Último · día». Sigue arriba de «Hoy», como hoy (lo verifica un test).
- **Hoy / Próximos 7 días / Recientes**: los títulos de sección bajan a 16 / w700. Los partidos se agrupan **por competición** (y por día en Próximos), con «Primera División · Clausura · Fecha 13» **una vez** en el encabezado del grupo. Agrupar se hace en presentación, con una función pura sobre la competición de cada partido; no se agrega ninguna consulta.
- **≥ 1200**: se mantienen las 2 columnas (Hoy + Próximos | accesos + Tus equipos + Recientes) y sus aserciones de posición.

---

## 7. Competiciones: cabecera, selectores y navegación

Jerarquía en 3 niveles, con alturas fijas. Medido en teléfono, el objetivo es **≤ 200 px de controles debajo de la AppBar**. Hoy son unos 280 px lógicos: vistas, selector, temporada, fase y ronda, con sus separaciones.

```
Maqueta ilustrativa — teléfono (360 px)
┌──────────────────────────────────────┐
│ Copa Libertadores ▾       2026 ▾   ⟳ │  Nivel 1 · AppBar: competición (abre la hoja) + temporada
│ Fixture   Tabla   Calendario   Llaves│  Nivel 2 · pestañas con subrayado (48)
│ ━━━━━━━                              │
│ (Previas) (Grupos) (Eliminatorias)   │  Nivel 3 · chips en 1 fila desplazable (48)
│  ‹        Semifinales ▾          ›   │            navegador de ronda (48)
├──────────────────────────────────────┤
│ Fluminense – Palmeiras · Global 1-2  │  ← contenido
```
```
Maqueta ilustrativa — escritorio 1280 px con panel de detalle
│ Copa Libertadores ▾  Temporada 2026 ▾                     [🔍 Buscar] ⟳ │
│ Fixture  Tabla  Calendario  Llaves          │ Partido            ⟳ ⤢ ✕ │
│ (Previas)(Grupos)(Eliminatorias)  ‹ Semifinales ▾ › │ héroe…           │
```

- **Nivel 1, competición y temporada**: el título de la AppBar pasa a ser el selector de competición. Conserva la `ValueKey('competition-selector')` y el tooltip «Elegir competición».
  - < 600: abre la hoja actual, agrupada por las 4 categorías sin cambios.
  - ≥ 600: abre un `MenuAnchor` con las mismas secciones. Esto **reemplaza las 2 filas de chips de D22** (decisión E-D8).
  - La temporada va a la derecha como `DropdownButton` compacto. Si no entra (texto al 200 % o nombre largo; se mide como hoy), baja al inicio del Nivel 3.
  - No cambian el modelo de categorías ni la regla «la categoría se deriva de la competición».
- **Nivel 2, vistas**: `ViewTabs` reemplaza al `SegmentedButton`. Reutiliza la medición de D7: segmentos iguales, nunca parte una etiqueta y se desplaza si no entra. Íconos solo ≥ 600 y si entran. Semántica de pestaña seleccionada. Mismos textos y mismo `vista=`.
- **Nivel 3, filtros de la vista**: es la única fila que cambia según la vista.
  - Fixture: chips de fase + `StageNavigator`. En ≥ 600 van en una misma fila si entran (medido); si no, en dos.
  - Tabla: chips de tabla (Anual / Zona A / Zona B / Grupo A–H).
  - Calendario: encabezado del mes.
  - Llaves: chips de fase y «Desde».
  - El botón «N partidos sin fase determinada» queda como `TextButton` al final del Nivel 3.
- **Panel de detalle (≥ 1200)**: la cabecera ocupa solo la columna de contenido, como hoy. Las mediciones usan el **ancho disponible** (`LayoutBuilder`) y no el de la pantalla.
- **Intacto**: rutas, parámetros (`temporada`, `fase`, `ronda`, `etapa`, `vista`, `tabla`, `mes`, `llave`), eventos de los BLoC, restauración de la selección, recarga en Web y navegación entre fases y rondas. Solo cambia la composición de los widgets que ya disparan esos eventos.
- **Posible fase posterior** (no entra en E4): que el Nivel 3 se desplace con el contenido. Se evalúa con las capturas de E4.

---

## 8. Tablas de posiciones

```
Maqueta ilustrativa — teléfono (360 px)
 Posiciones 2026 · Zona A          ✓ 16/16 fechas
 #   Equipo                    PJ   DG   Pts
 ▌1  (F) Ferro Carril Oeste    33   +9   62
 ▌2  (D) Deportivo Morón       33  +17   58
  3  (G) Godoy Cruz      ★     32  +13   56   ← favorito: fondo tenue + estrella
 ───────────────────────────────────────────
 Puntos: 3/1/0 · Desempate: DG, GF, enfrentamiento directo…   (notas al pie)
```

- **Las reglas y los desempates no cambian.** `StandingsTableView` mantiene filas propias, 48 px y la semántica «Posición N: Equipo».
- Se quita la cebra; las filas van separadas por divisores finos dentro de una superficie de grupo. Encabezado `labelSmall` gris. Cifras tabulares y alineadas a la derecha. **Pts en negrita** sobre una columna apenas sombreada. Posición en w700, con `*` si es compartida.
- **Columnas según el ancho disponible**, no según el breakpoint. Prioridad: Pts › PJ › DG › PG › PE › PP › GF › GC. Entran todas las que caben, con el mínimo actual de PJ / DG / Pts. Sin scroll horizontal salvo que no entren ni las tres.
- **Favoritos**: fila con `primaryContainer` tenue y estrella junto al nombre (decisión E-D11). Se lee del `FavoritesBloc` global; 0 peticiones.
- **Cobertura**: la `Card` se reemplaza por una línea de meta junto al título («✓ 16/16 fechas · 240/240 partidos» o tono aviso con «Partidos sin sumar (67)», desplegable como hoy). Las notas quedan **visibles** como pie en `bodySmall`, con «Calculada por la app… no es la tabla oficial» siempre a la vista.
- **Marcadores de clasificación** (E-D10, condicionada): una barra de 3 px junto a la posición, **solo** en los grupos CONMEBOL con `GroupStage.advancingPlaces` (verificado por temporada contra los Manuales de Clubes).
  - Se marca un único nivel, «Sigue en competencia». Leyenda: el `qualificationNote` literal más «posiciones actuales, no definitivas».
  - Una posición compartida que cruza el corte no se marca.
  - **Sin marcadores** en Primera, Nacional y toda tabla sin `advancingPlaces`. No se agregan reglas ni datos al dominio en este hito.
  - Si en E1 no lo confirmás, los marcadores quedan para una mejora funcional posterior.

## 9. Calendario mensual

No cambia la lógica ni el día argentino.
- **Encabezado**: «Octubre 2026» a la izquierda (`titleMedium`) y los dos chevrons juntos a la derecha (tonales, con los mismos tooltips).
- **Celda**: el número del día y debajo un punto con la cantidad (`labelSmall`, `primary`). Días sin partidos en gris y no tocables (como hoy). **Hoy** con anillo `primary`. **Seleccionado** relleno en `primary` con texto `onPrimary` y negrita, más `selected` en la semántica.
- **Lista del día**: `MatchGroup` con filas compactas; el contexto fase · etapa va en el encabezado del grupo.
- **Anchos**: división grilla | lista cuando el **ancho disponible** es ≥ 900 (hoy es ≥ 1200 de pantalla). Así la tablet horizontal y Web a 1000 px aprovechan el ancho. La grilla mantiene un máximo de 560.

## 10. Llaves

Se mantienen la arquitectura y el canvas.
- **Tarjeta de llave**: superficie de grupo (sin elevación), con un borde `outlineVariant` de 1 px para que se lea sobre el fondo. Las filas del equipo quedan como hoy (escudo 20, ganador en negrita con ✓, ahora en `success`), con goles tabulares y la tanda «(4)» en `labelSmall`. El pie «Ida 1-0 · Vuelta 0-2» queda en gris.
- **Conectores**: el cruce definido se dibuja en `onSurfaceVariant` y el pendiente en `outlineVariant`, con codos redondeados de radio 6. Así se lee el recorrido sin agregar colores.
- **Campeón**: fila compacta (trofeo en `success`, escudo 32, «Campeón: X» en `titleMedium`) sobre la superficie de grupo, en lugar de la franja de `primaryContainer`.
- **«A definir» / «Sin datos del partido» / «Sin dato de la definición»**: fondo `surfaceContainerHigh`, texto gris, ícono `help_outline`. Mismos textos.
- **Sin ubicar y previas**: con `MatchGroup` y filas compactas.
- Se conservan los anchos de columna (208–264), la altura de casilla calculada desde la tipografía (válida al 200 %) y el desplazamiento horizontal.

## 11. Ficha de equipo y detalle de partido

### 11.1 Ficha de equipo
- **Cabecera sin `Card`**: escudo 72, nombre en `headlineSmall` / w600, estadio · ciudad en gris. Competiciones como `Chip` de baja jerarquía (sin borde, fondo `surfaceContainerHigh`; un test busca `Chip`).
- **Favorito**: el `FavoriteButton` pasa a la cabecera, junto al nombre, con los mismos tooltips (decisión E-D14). En la barra queda solo «Actualizar».
- **Sincronización**: la barra de progreso de 3 px con «Completando partidos… n/t» se mantiene. La falla usa `InfoBanner(tone: offline)`.
- **Próximos / Disputados / Otras competiciones**: encabezado de día + `MatchGroup`. El contexto (competición · etapa) queda arriba a la izquierda de cada fila. «Otras competiciones (información parcial)» conserva su explicación y sus filas no tocables (sin chevron).

### 11.2 Detalle de partido

```
Maqueta ilustrativa — héroe del detalle
           Copa Libertadores · Cuartos de final
      (LDU)              3 – 2              (PAL)
    LDU Quito        Final (penales)      Palmeiras
                     Penales 3-4
      ✓ Avanza Palmeiras (4-3 en penales) · Global 3-3
 ─────────────────────────────────────────────────────
 Fecha      Miércoles 16/09/2026     Hora (Argentina)  19:00
 Estadio    Rodrigo Paz Delgado
 Serie      Ida   Palmeiras 1-0 LDU Quito
            Vuelta LDU Quito 3-2 Palmeiras (3-4 pen.)
 [ Compartir ]  [ Agregar al calendario ]
```

- **Héroe (`MatchHero`)**: la competición y la etapa arriba en gris. Escudos de 72, nombres en `titleMedium`, marcador en `displaySmall` tabular (en `live` si se está jugando), la etiqueta de estado de §5.2 y «Penales 3-4». Si hay llave, una línea `success` con «Avanza…».
- **Datos**: la `Card` de `ListTile` de 72 px se reemplaza por **filas compactas etiqueta | valor** (2 columnas desde 600 de ancho disponible). Se mantienen los textos de las etiquetas («Hora (Argentina)», «Estado», «Llave», «Serie de ida y vuelta») y las notas («sin confirmar», «TheSportsDB no informa…»).
- **Acciones**: «Compartir» y «Agregar al calendario» como botones tonales debajo del héroe; mismos textos, snackbars con `persist: false`. «Ver video» y la miniatura quedan como hoy, al final.
- El panel de 440 px usa el mismo widget; a ese ancho las filas van en 1 columna.

---

## 12. Arquitectura, restricciones y cambios fuera de presentación

- **Solo se toca** `lib/app/theme`, `lib/app/shell`, `lib/shared/presentation` y `lib/features/*/presentation`. Sin paquetes nuevos.
- **Cambios fuera de presentación: ninguno.** No se agregan reglas deportivas ni cupos de clasificación (condición de E-D10). Agrupar por competición o por día, calcular el ganador, leer los favoritos y `advancingPlaces` usan lo que ya existe (`TieOutcome`, `MatchGrouping`, `FavoritesBloc`, `GroupStage`). La única excepción es actualizar el **comentario** de `GroupStage.qualificationNote` en E5.
- **Reglas nuevas para `CLAUDE.md`:**
  - tokens en `shared/presentation/theme`;
  - sin colores, tamaños ni radios literales en las pantallas;
  - estados nunca solo por color;
  - sin animaciones infinitas (el punto «en vivo» es fijo);
  - mediciones con el ancho disponible.

## 13. Estrategia responsive, temas y accesibilidad

- **Breakpoints** (`Breakpoints`): no cambian y siguen decidiendo **solo el shell** (barra, riel, riel extendido, 2 columnas del Inicio, panel de detalle). Dentro del contenido, cada componente decide con el ancho disponible: columnas de tabla, nivel 3 en una fila, calendario dividido, detalle en 2 columnas.
- **Anchos máximos**: listas 900 en < 1200 y 1200 en escritorio (como hoy). Detalle, búsqueda, favoritos y ajustes en 720.
- **Matriz de verificación por fase**: 360 / 768 / 1280 / 1920, vertical y horizontal (tablet 800 × 1280), texto al 200 %, claro y oscuro.
- **Accesibilidad**:
  - áreas táctiles de 48 aunque lo visual sea compacto;
  - `textContrastGuideline` en **los dos temas**: se agrega la corrida en oscuro a `accessibility_test`, con el tema fijado en `settings` antes del `pumpApp`;
  - contraste ≥ 3:1 en conectores y marcadores (verificado en E1 con los valores de §4.1);
  - semántica intacta (etiquetas de partido, posición y celdas del calendario).
- **Escudos**: en oscuro, los escudos con fondo transparente se leen sobre `#171B20`. Los que traen fondo blanco se ven como hoy. No se recortan ni se les pone fondo, así no se deforman.

## 14. Capturas de referencia

- **«Antes» y «después» con los mismos datos.** Se usa la app grabada (`tool/recorded_app/main.dart`, reloj de D1) en la tablet (`SOP10X2501001122`, vertical y horizontal) y en Chrome a 360 / 768 / 1280 / 1920, en claro y oscuro.
  - Archivos en `docs/evidence/e{N}_{plataforma}_{pantalla}_{tema}.png`.
  - Pantallas: Inicio, Fixture de Primera, Fixture de Libertadores (eliminatorias), Tabla Anual, Zona, Nacional, Grupo Lib, Calendario, Llaves (Primera / Lib / Sud), ficha de Boca, ficha de extranjero, detalle (normal / serie con penales), búsqueda, favoritos, ajustes, sin conexión, error y 429.
- **Capturas automáticas** (decisión E-D12): `test/visual/screens_golden_test.dart` arma la app completa con `pumpApp`, carga Roboto con `loadRealFonts` y genera ~16 imágenes por fase con `matchesGoldenFile`.
  - Los escudos salen como iniciales, porque los tests no tienen red.
  - Las imágenes se regeneran **solo** con `--update-goldens`, a mano, después de revisar la diferencia; nunca para que un test vuelva a pasar.
  - El commit de las imágenes lo hacés vos.
- **Maqueta**: en E1 una página HTML **ilustrativa**, rotulada como tal, con la paleta, la fila de partido en todos sus estados, la tabla y la cabecera de Competiciones en claro y oscuro, para aprobar antes de tocar código. Archivo local (`docs/design/hito_e_maqueta.html`); se publica como artifact privado solo si lo pedís.

---

## 15. Archivos afectados

| Fase | Archivos (representativos) |
|---|---|
| E2 | `lib/app/theme/app_theme.dart`; nuevos `lib/shared/presentation/theme/{app_palette,app_spacing,app_text}.dart`; `shared/presentation/widgets/{match_card,match_status_chip,match_day_list,section_header,info_banner,status_views}.dart`; nuevo `match_group.dart`; `app/shell/{adaptive_shell,rate_limit_notice}.dart` |
| E3 | `features/home/presentation/pages/home_page.dart`, `app/shell/top_bar_team_search.dart` |
| E4 | `competitions_page.dart`, `competition_picker.dart`, `fixture_controls.dart`, `series_list.dart`; nuevo `view_tabs.dart` |
| E5 | `standings_panel.dart`, `calendar_panel.dart` |
| E6 | `bracket_panel.dart`, `team_detail_page.dart`, `match_detail_page.dart`; nuevo `match_hero.dart` |
| E7 | `team_search_page.dart`, `favorites_page.dart`, `settings_page.dart`, `coming_soon_page.dart`, diagnóstico (consistencia); docs |
| Tests | `test/app/{responsive_layout,accessibility,view_selector_layout,competition_picker_layout,continental_text_scale}_test.dart`, `test/helpers/recorded_app.dart` (`selectCompetition`), `test/features/home/home_page_test.dart`, `test/features/teams/presentation/team_detail_*_test.dart`, `test/features/match_detail/*`, `standings_view_test.dart`, `calendar_view_test.dart`; nuevo `test/visual/` |
| Docs | `docs/HITO_E.md` (nuevo), `PLAN.md` (sección Hito E), `DECISIONS.md` (D28+), `ARCHITECTURE.md` (tema y componentes), `CLAUDE.md` (convenciones) |

## 16. Riesgos de regresión

| Riesgo | Mitigación |
|---|---|
| Tests que fijan detalles de implementación (`SegmentedButton`, `ListTile` de favoritos, subtítulos exactos, 62 `MatchCard`, `OutlinedButton` del selector) | Se conservan nombres, claves, tooltips y textos donde se pueda. Cada test que cambie se lista en el informe con el motivo; ninguno se debilita. |
| Desbordes al 200 % con filas más densas | Nombres en 2 líneas, columnas medidas y no fijas; los tests de 200 % existentes corren en cada fase. |
| Áreas táctiles < 48 por compactar | Densidad solo visual; `androidTapTargetGuideline` en cada fase. |
| Contraste en oscuro | Corrida nueva de `textContrastGuideline` en oscuro; valores verificados en E1. |
| `pumpAndSettle` colgado por animaciones nuevas | Sin animaciones infinitas ni *skeletons*; los indicadores de carga quedan como están. |
| Selector en el título: URL, BLoC y Web | Mismos eventos y callbacks; pruebas de URL y recarga existentes y manuales en Chrome. |
| Escudos en Web (`<img>` fallback) | Siempre por `TeamBadge`, sin tocar `ValueKey(url)`. |
| Presupuestos de consultas | Los tests `*_budget_test`, `home_request_budget_test` y `live_refresh_test` deben dar los mismos números en cada fase. |
| Cambio de paleta global en E2 «toca todo» | E2 solo cambia tema y componentes compartidos. Las pantallas se rediseñan una por fase, y las capturas de E2 muestran el efecto global antes de seguir. |

---

## 17. Roadmap

Ajuste respecto de la propuesta: la base visual (tema y fila de partido) va **antes** del Inicio, porque la usan todas las pantallas. Así el Inicio no se diseña dos veces. Quedan 7 fases chicas.

| Fase | Contenido | Entregables |
|---|---|---|
| **E1 — Auditoría y propuesta** | Capturas «antes» (§14). Verificación de contrastes de la paleta. Maqueta HTML ilustrativa. Arnés de capturas automáticas (`test/visual/`, solo tests). `docs/HITO_E.md` con las decisiones aprobadas. **Sin cambios en `lib/`.** | Capturas, maqueta, informe de contrastes, decisiones cerradas |
| **E2 — Base visual y filas de partido** | Tokens y `ThemeData` (paleta, superficies, tipografía, temas de componentes), `MatchCard` como fila, `MatchGroup`, `MatchStatusChip` (§5.2), series en el Fixture, `InfoBanner` con tonos (reemplaza los 4 banners hechos a mano), `SectionHeader` y `EmptyView` compactos | Filas de partido consistentes en Inicio, Fixture, ficha y calendario |
| **E3 — Inicio** | Búsqueda sin duplicado, accesos en 1 fila, Tus equipos compacto, agrupación por competición, jerarquía de secciones, 2 columnas | Inicio con «Hoy» visible arriba en un teléfono |
| **E4 — Competiciones** | Selector en el título (hoja / menú), temporada en el Nivel 1, `ViewTabs`, Nivel 3 por vista, mediciones por ancho disponible | Controles ≤ 200 px en teléfono; URLs intactas |
| **E5 — Tablas y calendario** | Tabla (columnas por ancho, Pts, favoritos, cobertura integrada, marcadores CONMEBOL si se aprueban), calendario (encabezado, celdas, división ≥ 900) | — |
| **E6 — Llaves, ficha y detalle** | Tarjetas y conectores de llaves, campeón, ficha (cabecera, favorito), `MatchHero`, datos compactos | — |
| **E7 — Consistencia y cierre** | Búsqueda, favoritos, ajustes y diagnóstico con los tokens; pasada completa claro/oscuro; estados (carga, actualización, vacío, error, sin conexión, guardado, progreso, cancelación, 429, datos incompletos); antes/después; documentación final | Informe final con todas las diferencias visuales |

### 17.1 E1 en detalle (la fase que empieza ahora)

**Regla de la fase: no se modifica nada en `lib/`.** Solo se tocan `test/visual/` (nuevo), `docs/` y la carpeta temporal.

1. **Capturas actuales de referencia («antes»).**
   - *Automáticas*: `test/visual/screens_golden_test.dart` arma la app completa con `pumpApp` sobre los datos grabados de D1, con Roboto real.
     - Pantallas: Inicio, Fixture de Primera, Fixture de Libertadores (eliminatorias con series), Tabla Anual, Zona A, Nacional, Grupo de Libertadores, Calendario, Llaves (Primera / Libertadores 2025), ficha, detalle y un estado de error / sin conexión.
     - Anchos 360 / 768 / 1280 / 1920; claro y oscuro (si `pumpApp` no fija el tema, el test lo guarda en `settings` antes de arrancar); y 360 al 200 %.
     - Se generan con `--update-goldens` (en E1 la base **es** el diseño actual) y se copian a `docs/evidence/e1_test_*`.
     - Limitación: los escudos salen como iniciales (sin red).
   - *En dispositivo*: tablet `SOP10X2501001122` vertical (800) y horizontal (1280) con la app grabada (APK de `tool/recorded_app`, siguiendo el procedimiento de `CLAUDE.md`), claro y oscuro, con escudos reales. Web en la tablet por `adb reverse`. Después se reinstala el APK normal y se borra `build/web/fixtures/`.
   - Archivos: `docs/evidence/e1_{android|web}_{pantalla}_{claro|oscuro}.png`.
2. **Maqueta ilustrativa** (`docs/design/hito_e_maqueta.html`, rotulada «Maqueta ilustrativa: no es una captura de la app»; antes se carga la guía `artifact-design`):
   - selector claro/oscuro y selector de texto 100 % / 200 %;
   - paleta con muestras y la relación de contraste calculada en la página;
   - escala tipográfica y escala de espaciados;
   - **filas de partido con todos los casos de §5.4**, más la variante héroe;
   - **Inicio** en teléfono y en escritorio (2 columnas);
   - **Fixture** con series;
   - **Tabla** con Pts destacado, favorito y marcador CONMEBOL con su leyenda (para confirmar E-D10);
   - un ejemplo de Calendario y de Llaves.
3. **Prototipo del selector de Competiciones (E-D8)**, en dos formas:
   - (a) en la maqueta, interactivo en 5 marcos: 360 · tablet vertical 800 · tablet horizontal 1280 con riel y panel de 440 · Web 1920 con riel extendido y búsqueda en la barra · 360 al 200 %. Toca el título → hoja (< 600) o menú agrupado por categoría (≥ 600). Incluye el caso de nombre largo («Primera B Metropolitana») y la temporada que baja al Nivel 3 cuando no entra.
   - (b) **Prototipo en Flutter, solo en tests** (`test/visual/prototypes/competition_header_prototype.dart` + golden). Arma la AppBar propuesta con los widgets reales de la barra (`TopBarTeamSearch`, «Actualizar») y los Niveles 2–3 en esos anchos y al 200 %. Verifica sin desbordes, objetivos táctiles ≥ 48 y que la temporada baje cuando no entra. Genera imágenes **reales** de Flutter para comparar.
   - (c) **Análisis de interferencias**, escrito: con `AdaptiveShell` (riel, barra, ancho del contenido con el panel), con la búsqueda de la barra a ≥ 1200, con las acciones del AppBar, con el botón Atrás o Inicio, y con rutas, parámetros, recarga Web y enlaces compartidos (el selector solo llama a la misma navegación que hoy). También: `ValueKey('competition-selector')` y el helper de tests `selectCompetition`.
4. **Paleta y tipografía**: la propuesta final de §4.1–4.2 con los ajustes que surjan de la verificación.
5. **Verificación de contraste y accesibilidad**:
   - `docs/evidence/e1_contrastes.md`: ratio WCAG de cada par de tokens en los dos temas (texto ≥ 4,5:1; texto grande, íconos, conectores y marcadores ≥ 3:1). Se calcula con un script en la carpeta temporal.
   - Corrida de las pautas actuales (`accessibility_test`) también en tema oscuro, como diagnóstico del estado actual, desde el arnés de `test/visual/`.
6. **Documentación**:
   - `docs/HITO_E.md` (este plan + condiciones + resultados de E1);
   - sección «Hito E» en `docs/PLAN.md`;
   - D28 (Hito E: decisiones E-D1–E-D14 y condiciones) en `docs/DECISIONS.md`;
   - el puntero a `docs/HITO_E.md` en «Documentación» de `CLAUDE.md`.
7. **Validación**: `flutter analyze` sin issues, `flutter test` completo en verde (los tests nuevos de `test/visual/` incluidos).
8. **Informe y pausa**: capturas, maqueta, prototipo, contrastes e interferencias para tu aprobación. **Sin empezar E2.**

## 18. Criterios de aceptación

**En todas las fases:**
- `flutter analyze` sin issues; `flutter test` completo en verde (hoy 882 tests), presupuestos de consultas sin cambios.
- Capturas en tablet (vertical y horizontal) y Chrome a 360 / 768 / 1280 / 1920, claro y oscuro, de las pantallas tocadas, junto a sus «antes».
- Pautas de accesibilidad (táctil, etiquetas, contraste en los dos temas) y texto al 200 % sin desbordes.
- Capturas automáticas regeneradas **solo** tras revisión, con la lista de imágenes cambiadas.
- Informe con los cambios, las diferencias visuales y los tests modificados (con su motivo); docs actualizados. **Pausa hasta tu aprobación.** Sin commits ni PRs de mi parte.

**Específicos:**
- **E1**: ninguna línea de `lib/` cambiada. Contrastes ≥ 4,5:1 (texto) y ≥ 3:1 (no texto) para cada token en los dos temas.
- **E2**:
  - Ningún literal de color, tamaño o radio en los widgets compartidos.
  - Cada estado de §5.2 y cada caso de §5.4 con un test de widget (texto + ícono, sin desbordes al 200 %, sin recortar información deportiva).
  - El ganador en negrita solo cuando hay `TieOutcome`.
  - Las filas son tocables con 48 px.
- **E3**:
  - En 360 × 640, «Hoy» empieza en la primera pantalla si no hay favoritos, o debajo de un solo favorito.
  - Siguen pasando el orden de las categorías, «Tus equipos» arriba de «Hoy» y las 2 columnas a ≥ 1200.
  - 0 peticiones nuevas (`home_request_budget_test`).
- **E4**:
  - Controles ≤ 200 px en teléfono (test de layout nuevo).
  - Todas las combinaciones de `vista`, `fase`, `ronda`, `tabla`, `mes` y `llave` abren igual que antes (tests de rutas existentes y recarga manual en Web).
  - Nunca se parte una etiqueta de vista.
- **E5**:
  - Mismas posiciones, desempates y textos de «posición compartida».
  - Ningún marcador fuera de `advancingPlaces` (o de los cupos aprobados).
  - Columnas correctas con el panel de detalle abierto.
- **E6**:
  - Cuadros 2025 y 2026 iguales en contenido (`continental_finals_test`, `bracket_budget_test`).
  - El detalle conserva todos los textos y notas.
- **E7**:
  - Todos los banners por `InfoBanner`.
  - Revisar la diferencia entre ganador del partido y clasificado de la serie (observación de E3, §22).
  - Capturas finales completas y docs al día (incluida la sección de convenciones en `CLAUDE.md`).

---

## 19. Decisiones que necesitan tu aprobación

| # | Decisión | Recomendación |
|---|---|---|
| E-D1 | Color de marca | Mantener el celeste, más profundo para texto: `#1E6BB8` claro / `#7DB8EC` oscuro |
| E-D2 | Superficies | Neutras (gris), sin el tinte azulado de `fromSeed`; fondo gris y grupos blancos (en oscuro, escalones de gris) |
| E-D3 | Partidos | Agrupados en superficies con divisores, en vez de una `Card` elevada por partido |
| E-D4 | «Final» | Texto gris sin píldora; píldora solo en vivo, entretiempo y anomalías |
| E-D5 | Ganador | En negrita en todas las listas (con `TieOutcome`) |
| E-D6 | Inicio | Partidos agrupados por competición, contexto una vez en el encabezado |
| E-D7 | Inicio en teléfono | Accesos en una fila desplazable con etiquetas de categoría; quitar el ícono de búsqueda duplicado |
| E-D8 | Selector de competición | En el título de la AppBar en todos los anchos (hoja < 600, menú ≥ 600). Reemplaza las filas de chips de D22 a ≥ 600 |
| E-D9 | Vistas | Pestañas con subrayado en lugar de `SegmentedButton` |
| E-D10 | Marcadores de clasificación | **Aprobada con condición**: un único nivel «Sigue en competencia» solo con `GroupStage.advancingPlaces` (verificado); sin reglas nuevas. Se confirma con la maqueta de E1 |
| E-D11 | Favoritos en tablas | Sí, fondo tenue + estrella |
| E-D12 | Capturas automáticas | Golden tests en `test/visual/`, actualizados solo a mano tras revisión |
| E-D13 | Orden de fases | E1–E7 como en §17 (base visual antes del Inicio) |
| E-D14 | Favorito en la ficha | Botón en la cabecera, junto al nombre (mismos tooltips) |

## Verificación (cómo se comprueba cada fase)

1. `flutter analyze` y `flutter test`, incluidos `test/visual/` (comparación de imágenes) y los presupuestos.
2. `flutter run -d SOP10X2501001122` y `flutter run -d chrome`. Para comparar con el «antes», la app grabada: `flutter build apk --release -t tool/recorded_app/main.dart` / `flutter build web --release -t tool/recorded_app/main.dart`.
3. Capturas en la tablet (mobile-mcp o `adb`), vertical y horizontal; Chrome a 360 / 768 / 1280 / 1920 con DevTools; claro y oscuro desde Ajustes; texto grande desde la accesibilidad de Android.
4. Recorrido manual de las URLs de Competiciones (copiar, pegar, recargar y volver atrás) en Chrome.
5. Informe de fase con capturas antes/después y espera de aprobación.

---

## 20. Resultados de E1 (17/10/2026) — aprobada

Sin cambios en `lib/`. Todo lo nuevo está en `test/visual/`, `docs/design/` y `docs/evidence/`.

### Entregables
| Qué | Dónde |
|---|---|
| Maqueta ilustrativa (claro/oscuro, texto 100/200 %, junto a los «antes») | `docs/design/hito_e_maqueta.html` |
| Capturas «antes» automáticas: 69 renders reales de Flutter (13 pantallas a 360 y 1280 en claro y oscuro; Inicio, Fixtures, Tabla Anual y Llaves también a 768 y 1920; 3 al 200 %; error de API y 429) | `test/visual/goldens/*.png` (test `test/visual/screens_golden_test.dart`) |
| Capturas «antes» en Web con escudos reales: 44 (app grabada, Chrome a 360/768/1280/1920, claro y oscuro) | `docs/evidence/e1_web_*.png` |
| Prototipo Flutter de la cabecera de Competiciones (E-D8): 13 imágenes y 16 tests | `test/visual/prototypes/`, `test/visual/competition_header_prototype_test.dart`, `test/visual/goldens/prototipo_*.png` |
| Contrastes y accesibilidad | `docs/evidence/e1_contrastes.md`, `test/visual/dark_theme_accessibility_test.dart` |

### Hallazgos nuevos (confirman o precisan la auditoría §2)
- **P1 medido:** a 360 px los controles de Competiciones ocupan **272 px** debajo de la barra; el prototipo, **152 px** (156 al 200 %). A 768 px hoy son 5 filas (vistas, categorías, competiciones, temporada, grupos en 2 filas: `e1_web_tabla_grupo_libertadores_768_claro.png`).
- **Nombres partidos a mitad de palabra** a 360 px («Sarmient o», «Fluminen se», «Palmeira s»): la columna central fija de 104 px deja ~90 px por nombre (`fixture_primera_360_claro.png`, `fixture_libertadores_series_360_oscuro.png`). Lo resuelve la columna medida de §5.1, y entra en los casos de §5.4.
- **Inicio a 360 × 780:** «Hoy» empieza a los ~600 px (`inicio_360_claro.png`).
- **Chip de fase elegido fuera de la vista** a 360 («Eliminator…» cortado contra el borde). En el prototipo se desplaza solo hasta quedar visible: incorporarlo en E4.
- **Al 200 %, solo dos pestañas de vista a la vista** (también pasa hoy con el selector segmentado); en el prototipo el resto se desplaza. A decidir en E4: dejarlo así o agregar una pista de desplazamiento.
- **La etiqueta «Competiciones» de la barra inferior se parte en dos líneas al 200 %** (shell actual, `prototipo_360_200_claro.png`). Para E7.
- **Pestañas:** con segmentos iguales (como el selector actual) las cuatro no entran a 360; el prototipo usa el ancho de cada etiqueta, repartiendo lo que sobra en teléfonos y con ancho natural desde 600 px.
- **Tema oscuro actual:** las pautas de accesibilidad pasan (12/12); el problema del oscuro es estético (avisos violetas, superficies azuladas), no de contraste.
- **Paleta:** dos tonos del borrador corregidos por contraste (`live` claro y `outline` claro); 0 fallas con los valores finales.
- **Estados especiales:** las grabaciones no tienen partidos postergados, suspendidos ni cancelados (sí `1H`, `HT`, `2H`, `AET`, `PEN`, `WO`, `AWD`); la maqueta los muestra con equipos genéricos rotulados. Para los tests de E2 se usarán `Match` construidos en el test, no JSON editados.
- **Tablet:** no estaba conectada durante E1 (solo había otros dos dispositivos, que no se usaron). Las capturas en Android con escudos reales quedan para cuando esté disponible; las `d4`–`d7` de `docs/evidence/` siguen vigentes para Competiciones, Tablas y Llaves, y las Web de E1 cubren Inicio y la ficha con escudos reales.

### Para aprobar antes de E2
1. La paleta final (§4.1) y la tipografía (§4.2), vistas en la maqueta.
2. Las filas de partido (§5) y el Inicio (§6) de la maqueta.
3. El selector de Competiciones (E-D8) con el prototipo Flutter y la maqueta interactiva.
4. **E-D10:** marcador único «Sigue en competencia» en los grupos CONMEBOL, o dejar los marcadores para más adelante.
5. Que las capturas automáticas (`test/visual/goldens/`, 82 imágenes, ~5 MB) entren al repositorio como base de comparación.

---

## 21. Resultados de E2 (17/10/2026) — aprobada

E1 se aprobó con el estilo de la maqueta. E2 implementa la base visual y las filas de partido. **Solo presentación**: sin cambios en endpoints, repositorios, casos de uso, caché, sincronización, rutas, parámetros ni dependencias. Presupuestos de consultas iguales (todos los `*_budget_test`, `home_request_budget_test` y `live_refresh_test` en verde).

### Componentes
| Componente | Archivo | Qué hace |
|---|---|---|
| `AppColors`, `AppPalette` | `lib/shared/presentation/theme/app_palette.dart` | Esquema desde la semilla celeste con superficies neutras (§4.1) + `ThemeExtension` con `group`, `live`/`liveContainer`, `warning`/`warningContainer`, `success`. `AppPalette.of(context)` cae al brillo del tema si falta la extensión (widget tests con el tema de fábrica). |
| `AppSpacing`, `AppRadius`, `AppSizes` | `.../theme/app_spacing.dart` | Escala 4·8·12·16·24·32, radios 12/8, alturas mínimas (fila 56, encabezado 40, táctil 48), escudos 20/24/28/32/72, ícono de estado 14, punto en vivo 6. |
| `AppText` | `.../theme/app_text.dart` | Extensión de `TextTheme` con los roles de §4.2 (sección, grupo, día, equipo/ganador, marcador y hora tabulares, estado, tabla, secundario, aviso). |
| `AppTheme` | `lib/app/theme/app_theme.dart` | `ThemeData` con la paleta y temas de componentes: AppBar sin elevación al desplazar, `Card` plana (grupo, radio 12), chips radio 8 sin tilde (elegido en `primaryContainer` y negrita; el área táctil sigue en 48), divisores de 1 px, barra inferior y riel con indicador `primaryContainer`, hoja inferior en la superficie de grupo. |
| `MatchCard` (fila) | `shared/presentation/widgets/match_card.dart` | Misma API, clave y semántica. Fila sin `Card`; contexto arriba a la izquierda; columna central **medida** (mín. «0 – 0» u hora, máx. «00 – 00» o «Horario por»); estado centrado debajo; ganador en negrita solo con `TieOutcome.of`; elegida con fondo `primaryContainer` y barra de 3 px; alto mínimo 56. La semántica ahora incluye la acción de tocar (antes la excluía). |
| `MatchGroup`, `MatchGroupHeader`, `MatchGroupFooter`, `MatchGroupNote` | `.../widgets/match_group.dart` (nuevo) | Superficie de grupo con divisores; encabezado en `surfaceContainerHigh` (semántica de encabezado); pie de «Avanza» (`success`) o «Sin dato de la definición»; fila tenue para la pierna faltante. |
| `MatchStatusChip` | `.../widgets/match_status_chip.dart` | §5.2: «Final» gris sin píldora; píldora con punto fijo en juego y entretiempo; ícono + texto en las anomalías (reloj de arena, `event_busy`, `pause_circle_outline`, `block`); desconocido con el texto crudo. |
| `matchDayItems` / `DayHeader` | `.../widgets/match_day_list.dart` | Cada día = encabezado (13/w600 en `primary`) + un `MatchGroup`. |
| `InfoBanner` | `.../widgets/info_banner.dart` | `tone` (`info` · `warning` · `offline` · `error`, con ícono por defecto) y `band` (franja a todo el ancho con `SafeArea`). Fondo `surfaceContainerHigh`, ícono del color del tono. Reemplaza los 4 avisos hechos a mano (Inicio, ficha, búsqueda, límite de consultas) y el de `StaleDataBanner`. Sin fondos violetas. |
| `SectionHeader` | `.../widgets/section_header.dart` | 16/w700, detalle al lado (baja si no entra), 24 arriba y 8 abajo. |
| `EmptyView` / `ErrorView` | `.../widgets/status_views.dart` | Ícono de 40, textos con colores del esquema, «Reintentar» tonal, detalle técnico en `bodySmall` monoespaciado. La carga queda igual (§4.4). |
| Series del Fixture | `features/competitions/.../series_list.dart` | Un `MatchGroup` por serie: equipos + `MatchLabels.aggregate` en el encabezado, piernas «Ida/Vuelta · día», pie con `MatchLabels.tieAdvances` o «Sin dato de la definición», pierna faltante como fila tenue. Textos sin cambios. |

Ajustes mínimos en pantallas, para que las filas no queden sueltas sobre el fondo (el rediseño de cada pantalla sigue en su fase): «Hoy» y los partidos de «Tus equipos» en un `MatchGroup` (Inicio), «Sin ubicar en el cuadro» en un `MatchGroup` (Llaves), tonos de los `InfoBanner` existentes (Tabla, Calendario, Llaves), iniciales de `TeamBadge` en `primaryContainer` (como la maqueta). `MatchLabels.showsScore` (nuevo): el marcador parcial de un partido suspendido o interrumpido se muestra y se lee en la semántica.

### Decisión nueva para aprobar: fila apilada con texto grande
Con el texto al 200 % en un teléfono, a los costados del marcador quedan ~50 px por nombre (unas 3 letras de 28 px por renglón): los nombres se partían a mitad de palabra y se cortaban a los dos renglones. La fila calcula si a los costados del marcador más ancho entra un nombre de al menos 5,5 veces el tamaño de letra (unas 10 letras); si no, **apila los equipos**: local arriba, visitante abajo, los goles a la derecha de cada uno (o la hora, si no empezó), y la tanda y el estado debajo. Sigue la regla de §5.1 (altura según el contenido, nada recortado). A 360 px se apila desde ~110 % de texto; a 768 px o más, nunca hasta el 200 %. Si preferís la fila a los costados siempre (como la maqueta), el cambio es de una línea.

Otros ajustes respecto del plan:
- Entre el escudo y el marcador hay **4 px** (no 8): a 360 px, con la medida real de Roboto, «Independiente» (91,5 px) no entraba por medio píxel y se partía. Lo verifica un test.
- La etiqueta elegida de la barra inferior queda con el peso de fábrica: en negrita, «Competiciones» se partía en dos renglones a 360 px y 100 %.
- La pierna faltante va en 14 px: en 12 px gris, la pauta de contraste de Flutter (que mide píxeles) daba 3,4:1 por el suavizado, aunque el par de colores da 6,01:1.

### Tests
- **Nuevo** `test/shared/match_row_test.dart` (22 tests, con Roboto real): cada estado de §5.2 (texto + ícono) y cada caso de §5.4 (nombres largos, penales con «Avanza», reprogramado + «La API ya no lo lista», escudo inexistente y escudo que no carga, fila elegida y fila no tocable) y las cinco series de §5.3 (global parcial, global, tanda, sin dato, pierna faltante), en **360 y 1280 px × 100 y 200 % × claro y oscuro**: sin desbordes, ningún texto recortado ni fuera de la fila (salvo nombres desde el 3.er renglón), filas ≥ 48 px y pautas de accesibilidad (táctil, etiquetas, contraste). Además: negrita solo con `TieOutcome` (no en vivo, ni en un empate sin tanda, ni en el parcial de un suspendido), marcador en vivo en `live`, disposición a los costados o apilada, «Independiente» en un renglón a 360 px, semántica de la fila elegida y de la no tocable, parcial de un suspendido en la semántica.
- **Modificados** (sin debilitarlos):
  - `test/app/accessibility_test.dart` (200 %): `scrollUntilVisible(find.byType(MatchCard))` exige un único resultado, y ahora el grupo construye todas sus filas juntas. Se desplaza hasta que aparece la primera fila y la asegura visible.
  - `test/features/competitions/presentation/continental_bracket_view_test.dart` (Fixture de octavos): el global y «Avanza» eran un solo texto («Global … · Avanza …»); ahora el global va en el encabezado y «Avanza» en el pie (§5.3). Se verifica cada texto **dentro del mismo grupo** de la serie y que el grupo tenga sus 2 filas.
- `flutter analyze`: sin issues. `flutter test`: **1001 tests en verde** (904 + 97 de `test/visual/`).

### Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): los 69 goldens de pantallas cambiaron (la paleta y la fila tocan todas) y se regeneraron **después de revisarlos**; los 13 del prototipo de E1 no cambiaron. Los «antes» de E1 quedaron copiados en `docs/evidence/e1_test_*.png` y los «después» en `docs/evidence/e2_test_*.png` (mismos nombres). Comparación lado a lado: `docs/evidence/e2_comparacion.html`.
- **Web con escudos reales** (app grabada, Chrome a 360/768/1280/1920, claro y oscuro): `docs/evidence/e2_web_*.png`, con los mismos encuadres que `e1_web_*`.
- **Android** (APK release, datos en vivo): en un Motorola One Fusion (Android 11, 411 dp de ancho), a pedido del usuario porque la tablet no estaba conectada. Inicio, Fixture de Primera, Libertadores (semis en juego y cuartos con «Avanza»), detalle, texto al 200 % (fila apilada) y tema claro y oscuro, sin desbordes: `docs/evidence/e2_android_motorola_*.png` (9). Al terminar se restauraron el tema de la app («Oscuro») y la fuente del teléfono (100 %). La tablet (vertical 800 y horizontal 1280) sigue pendiente.

### Qué no cambia todavía (fases siguientes)
Inicio agrupado por competición y accesos en una fila (E3); cabecera de Competiciones, pestañas y chips de fase (E4); tabla y calendario (E5); llaves, cabecera de ficha y héroe del detalle (E6); búsqueda, favoritos, ajustes, diagnóstico y la etiqueta «Competiciones» al 200 % (E7).

---

## 22. Resultados de E3 (17/10/2026) — aprobada

E2 se aprobó y se fusionó. E3 rediseña el Inicio con los componentes de E2. **Solo presentación**: sin cambios en BLoC, casos de uso, entidades, repositorios, endpoints, caché, sincronización, rate limiter, rutas ni dependencias. Mismas consultas (`home_request_budget_test` y los demás `*_budget_test` y `live_refresh_test` en verde).

### Cambios visuales
| Parte | Antes (E2) | Después (E3) |
|---|---|---|
| Búsqueda (< 1200) | Ícono en la barra **y** tarjeta «Buscar equipo» | Un solo acceso: campo compacto de 48 px arriba del contenido (`TeamSearchShortcut`), abre Equipos como antes. ≥ 1200: el campo de la barra, sin cambios |
| Accesos en teléfono | 4 títulos + 4 filas de chips (~330 px) | **Una fila** desplazable: etiqueta de categoría + chips, separadas por un divisor; llega a los bordes de la pantalla y el chip cortado contra el borde indica que hay más. Se arrastra también con mouse (Web) |
| Accesos en tablet y Web | 4 títulos + filas de chips | `Wrap` por categoría: cada una (etiqueta + chips) sigue a la anterior si entra y solo se parte si no entra sola. Con Roboto: 4 renglones a 768, 2 a 1100 y 6 en la columna derecha a 1280 y 1920, sin desplazamiento. Mismos `ActionChip` y tooltips «Fixture de X»; se quitó el trofeo repetido en cada chip (la etiqueta de la categoría ya los agrupa) |
| Tus equipos | `ListTile` suelto + grupo con 2 filas, contexto en 2 renglones | **Un bloque por equipo** (`MatchGroup`): escudo 32, nombre y chevron a la ficha; debajo hasta 2 filas con «**Próximo** · día · competición · etapa» / «**Último** · …» (el prefijo en negrita). Un partido en juego no repite «En juego» ni el día: lo dicen el marcador y la etiqueta |
| Hoy / Próximos / Recientes | Un grupo por día con el contexto en **cada** fila | Un grupo por **competición · fase · etapa** (y por día en Próximos) con el contexto **una vez**, en el encabezado («**Primera División** · Clausura · Fecha 12»). Recientes lleva el día en el título, como Hoy |
| Barra de actualización | Dentro de la lista | Fija arriba de la lista (se ve aunque se desplace) |
| Pie y mensajes vacíos | Valores literales | Tokens (`AppSpacing`, `onSurfaceVariant`) |

**Agrupación** (`HomeGrouping.byDay`, función pura en presentación): día argentino → competición · fase · etapa. Los grupos de un día van en el orden de su primer partido y los partidos conservan el orden cronológico de `HomeFeed`; cada `idEvent` aparece una sola vez (como en `matchDayItems`). Lo verifica `home_grouping_test.dart` con los partidos grabados.

### Decisiones y desvíos
- **Margen lateral de 12 px en teléfonos** (no 16 como §4.3): con 16, a 360 px «Independiente» ya no entra en un renglón de la fila de E2 y se parte a mitad de palabra (visto en la primera captura). 12 es el margen de todas las demás pantallas. Desde 600 px, 24.
- **Etiqueta «Primera División» + chip «Primera División»**: se conserva para mantener las cuatro categorías; es la única categoría con un solo acceso del mismo nombre. A revisar en E7 si se prefiere ocultar la etiqueta cuando repite el chip.
- **Encabezado de grupo sin enlace**: la maqueta mostraba un chevron; no se agregó navegación nueva (abrir la fecha exacta necesita la fase y la ronda, que el Inicio no tiene en presentación). Se puede evaluar después.
- **Error o carga sin datos**: el acceso al buscador está en el contenido, así que en la pantalla de error del Inicio no aparece; el buscador sigue a un toque en la pestaña «Equipos».
- **Encabezado del favorito**: sigue siendo un `ListTile` (ahora compacto, dentro del bloque), por accesibilidad y para conservar el test que lo toca.
- `TopBarTeamSearch`: se quitó `showButtonWhenNarrow` (solo lo usaba el Inicio) y el radio literal 24 pasó a `AppRadius.pillAll`; al 200 % el campo de la barra queda redondo del todo (cambió solo `prototipo_1280_panel_200_claro.png`).

### Tests
- **Nuevos** (21): `test/features/home/home_grouping_test.dart` (6: ni repetidos ni omitidos, días y grupos, orden cronológico, repetidos, fase en el detalle, vacío) y `test/app/home_layout_test.dart` (15, con Roboto): en **360 × 640**, «Hoy» y su primera fila en la primera pantalla sin favoritos, y «Hoy» después del bloque de un favorito (Boca, con sus 2 filas); un solo acceso al buscador (sin ícono en la barra, ≥ 48 px, abre Equipos); la fila de accesos llega a los bordes, se desplaza de costado sin mover la lista y un arrastre vertical sobre ella desplaza la lista; el último chip, desplazado, abre su fixture; al 200 % la fila sigue siendo una y «Hoy» entra en 780 px; a 768 / 1100 / 1280 / 1920 px los renglones de accesos (4 / 2 / 6 / 6), sin desplazamiento ni salirse del contenido y ninguna etiqueta sola en su renglón; pautas de accesibilidad con un favorito a 360 y 1280, en claro y oscuro.
- **Modificados** (sin debilitarlos), en `test/features/home/home_page_test.dart`:
  - «Hoy, Próximos y Recientes»: `find.text('Primera Nacional · Fecha 34')` contaba 18 subtítulos (uno por fila); ahora el contexto va una vez por grupo. Se verifica que haya **3 grupos** (uno por día) con ese encabezado y que contengan **los 18 partidos**; los 62 `MatchCard` se siguen contando.
  - «los accesos llevan a cada fixture»: comparaba la altura de las etiquetas; desde 600 px dos categorías pueden ir en el mismo renglón. Ahora compara el **orden de lectura** (renglón y luego izquierda → derecha), con las mismas aserciones (orden del catálogo, Primera C antes de las copas nacionales, Copa Argentina antes de las internacionales) y el mismo toque.
  - «próximo y último de cada favorito»: el contexto pasó de 2 renglones a uno («Próximo · Domingo 18/10/2026 · Primera División · Clausura · Fecha 13»). Se busca ese texto **dentro del bloque de Boca** y se verifica que el bloque tenga sus 2 filas; siguen las aserciones de «Tus equipos» antes de «Hoy», cero consultas extra y el toque a la ficha.
- `pumpApp` (`test/helpers/recorded_app.dart`) acepta `seed:` para guardar datos antes de arrancar (el favorito de los tests y de las capturas).
- `flutter analyze`: sin issues. `flutter test`: **1026 tests en verde** (1001 + 21 nuevos + 5 capturas nuevas).

### Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): cambiaron y se regeneraron **después de revisarlas** las 7 de Inicio, las 4 de estados (error de API y 429: es el Inicio sin el ícono de búsqueda en la barra) y `prototipo_1280_panel_200_claro.png` (borde del buscador de la barra). **Nuevas**: `inicio_favorito_{360,1280}_{claro,oscuro}.png` e `inicio_favorito_360_200_claro.png`. Antes (E2) y después (E3) en `docs/evidence/e2_test_*` / `e3_test_*`; comparación lado a lado en `docs/evidence/e3_comparacion.html`.
- **Web con escudos reales** (app grabada, Chrome a 360 / 411 / 768 / 1280 / 1920, claro y oscuro): `docs/evidence/e3_web_inicio_*` y, con Boca como favorito (agregado desde su ficha), `e3_web_inicio_favorito_*` (20 imágenes).
- **Android** (APK release, datos en vivo, Motorola One Fusion, 411 dp): Inicio en oscuro, la fila de accesos desplazada, con un favorito en claro y oscuro, la lista agrupada y el texto al 200 % (`docs/evidence/e3_android_motorola_*`, 7). Sin desbordes; «Hoy» queda en la primera pantalla también con el favorito. Al terminar se quitó el favorito de prueba y se restauraron el tema de la app («Oscuro») y la fuente del teléfono (100 %). Queda instalado el APK de E3. Durante la prueba TheSportsDB respondió 429 una vez (carga en frío del Inicio) y la app mostró su aviso.
- **Pendiente**: la tablet (vertical 800 y horizontal 1280) no estaba conectada. Esos anchos quedan cubiertos por las capturas automáticas y Web a 768 y 1280.

### Observación para E7 (no se implementa en E3)
Diferenciar visualmente **el ganador de un partido** (hoy: nombre en negrita) y **el equipo que clasificó en una serie** de ida y vuelta (hoy: pie «✓ Avanza X…» en `success`). Por ahora se conservan los dos. En E7, evaluar que el pie diga explícitamente «Clasificó X por penales» o «Clasificó X por resultado global», siempre con la evidencia existente de `TieOutcome` (sin reglas nuevas).

---

## 23. Resultados de E4 (18/10/2026) — aprobada

E3 se aprobó y se fusionó. E4 rediseña la cabecera de Competiciones según §7 y el prototipo de E1 (E-D8, E-D9). **Solo presentación**: sin cambios en BLoC, eventos, casos de uso, entidades, repositorios, endpoints, caché, sincronización, rate limiter, persistencia, rutas, parámetros de URL ni dependencias. Mismas consultas (todos los `*_budget_test`, `home_request_budget_test` y `live_refresh_test` en verde).

### Cambios visuales
| Parte | Antes (E3) | Después (E4) |
|---|---|---|
| Barra superior | Título fijo con el nombre; el selector era un botón en píldora («Copas internacionales · Libertadores ▾») debajo de las vistas (< 600) o 2 filas de chips categoría → competición (≥ 600) | **El título es el selector** (`CompetitionPicker`, `ValueKey('competition-selector')`, tooltip «Elegir competición»): nombre + flecha. < 600 abre la hoja agrupada por las 4 categorías (la misma de D22); ≥ 600, un `MenuAnchor` con las mismas secciones y la actual con tilde. Reemplaza las filas de chips de D22 |
| Temporada | Fila propia («Temporada 2026 ▾») debajo del selector | **Al lado del selector, en la barra** («2026 ▾» en teléfonos, «Temporada 2026 ▾» desde 600). Si no entra, baja a un renglón propio al principio de los filtros («Temporada 2026 ▾») |
| Nombre de la competición | Siempre completo en el título | Completo si entra con la temporada; si no, el **nombre corto** del catálogo («B Metro») con la temporada; si tampoco, la temporada baja y vuelve el completo si entra solo. La semántica lleva siempre el nombre completo («Competición: Primera B Metropolitana») |
| Vistas | `SegmentedButton` con bordes («Fixture \| Tabla \| Calendario \| Llaves») | **`ViewTabs`**: pestañas con subrayado de 3 px en `primary` (la elegida no se marca solo con color), semántica de botón elegido, 48 px de alto. En teléfono ocupan todo el ancho; desde 600, ancho natural con íconos si entran. Si no entran (200 %), se desplazan con el **borde esfumado** del lado que sigue y la elegida queda a la vista; nunca se parte una etiqueta |
| Filtros del Fixture | Chips de fase en `Wrap` (o fila a < 600 con «Eliminator…» cortado) + `StageNavigator` con botones rellenos y `titleMedium` | Fases en **una fila desplazable** (`ScrollRow`) con la elegida a la vista y bordes esfumados; navegador de ronda compacto (íconos sin relleno, `titleSmall` w600). Desde 600, **fases y ronda en la misma línea** si entran (`FilterLine` mide el ancho real de las fases, también junto al panel de detalle) |
| Filtros de Tabla | Chips en `Wrap` dentro de la lista (Libertadores: 2 renglones a 768) | Una fila fija arriba de la tabla, desplazable, con la tabla elegida a la vista |
| Filtros de Llaves | Chips de torneo arriba de la lista; «Desde» con título y `Wrap` debajo del campeón | Una fila fija arriba del cuadro: torneo (Primera) y «Desde» + rondas (Copa Argentina) |
| Calendario | — | Sin filtros propios en la cabecera (el mes sigue en el encabezado del calendario; se rediseña en E5) |

### Espacio vertical (Roboto, desde la barra hasta el contenido)
| Pantalla | Antes | Después |
|---|---|---|
| Fixture de la Libertadores, 360 px | **272 px** (medido en E1) | **152 px** (−120 px, −44 %) |
| Fixture de Primera, 360 y 411 px | ~272 px | 152 px |
| Fixture de la Libertadores, 411 px | — | 152 px |
| Tabla de grupos, 360 y 411 px | vistas + selector + temporada + chips en la lista | 104 px |
| Llaves de la Copa Argentina, 360 y 411 px | ídem | 104 px |
| Calendario, 360 y 411 px | ídem | 48 px (solo las pestañas) |
| Al 200 % a 360 px | — | Tabla Anual 116, Fixture de Primera 164, Llaves 168, Fixture de la Libertadores 216 (la temporada baja a su renglón: con texto grande la accesibilidad tiene prioridad sobre el límite) |

A 360 × 780 el primer partido del Fixture entra en la primera pantalla (antes, al ~65 % de la altura y uno solo).

### Decisiones y desvíos respecto del plan
- **Orden al medir la barra**: nombre completo + temporada → corto + temporada → completo solo → corto solo (el del prototipo aprobado). Se mide con el ancho disponible del título (pantalla de la sección − riel − búsqueda de la barra − «Actualizar» − Atrás si lo hubiera), la fuente real y la escala de texto: la del título limitada a 1,34 como hace `AppBar`; la temporada usa la del sistema (es un control, no el título).
- **Temporada al 200 % en su propio renglón** (no al principio de la fila de fases como en el prototipo): ahí quedaba fuera de la vista al mostrarse la fase elegida. Es el mismo lugar en todas las vistas.
- **Chips de Tabla y Llaves fijos arriba de su contenido**, pero dentro de cada panel (`StandingsPanel`, `BracketPanel`) y no en la página: la página no lee el estado de esos BLoC y los tests del panel solo siguen valiendo. «Desde» pasó a esa fila (es estado local del cuadro).
- **El mes del Calendario** queda en su encabezado (E5 rediseña el calendario).
- **Sin la memoria «última competición por categoría»** de D2: servía para los chips de categoría, que desaparecen; el menú y la hoja muestran todas las competiciones.
- **Semántica**: en la Web, la temporada de la barra se fundía con el tooltip del selector en un solo nodo («Elegir competición / Temporada 2026»). Ahora cada uno es un nodo propio (lo verifica `competition_picker_layout_test`).
- **Panel de detalle**: la barra ocupa todo el ancho, como antes; pestañas, filtros y navegador quedan en la columna del fixture. Sin cambios en la lógica del detalle.
- Tokens nuevos: `AppSizes.scrollFade` (24) y `AppSizes.tabIndicator` (3). `TopBarTeamSearch.barWidth` expone el ancho del buscador de la barra para la medición.

### Tests
- **Nuevos o reescritos**:
  - `test/app/competitions_header_layout_test.dart` (nuevo, 22, con Roboto): **≤ 200 px** de controles a 360 y 411 en Fixture de Libertadores y de Primera, Tabla de grupos, Calendario y Llaves; la fase elegida a la vista; antes vs. después; al 200 % sin desbordes ni etiquetas partidas, con la temporada en la barra o en los filtros según entre; cambio de temporada desde la barra y desde los filtros; a 1280 y 1920 con el panel: elegir, cerrar y reabrir un partido, cambiar de competición con el panel abierto, cabecera dentro de la columna; 1280 al 200 % con el panel; pautas de accesibilidad.
  - `test/app/competition_picker_layout_test.dart` (reescrito, 8): selector y temporada en la barra a 360 / 411 / 800 / 1280 / 1920 sin cortes ni superposiciones con la búsqueda y «Actualizar», nodos semánticos separados, menú debajo del título, nombre largo (B Metro) a 360 y 800.
  - `test/features/competitions/presentation/competition_picker_test.dart` (reescrito, 13): hoja < 600 (categorías en orden, actual marcada, una elección, no recarga la actual, 200 %), menú ≥ 600 (768 y 1280: categorías y competiciones en orden, tilde solo en la actual, pautas con contraste; elegir; cerrar sin elegir; 200 %) y `CompetitionTitleLayout` (completo / corto, temporada en la barra o abajo).
  - `test/app/view_selector_layout_test.dart` (reescrito, 5): 360 sin íconos ni desplazamiento, una línea, 48 px y semántica de elegida; 360 al 200 % se desplaza con el borde esfumado y la elegida a la vista; 800 con íconos; 1280 junto al panel; B Metro solo con Fixture y Calendario.
- **Modificados** (sin debilitarlos):
  - `test/helpers/recorded_app.dart`: `selectCompetition` toca el título y elige en la hoja o en el menú (antes: botón o chips de categoría); nuevos `tapFilter` (lleva a la vista el chip de una fila desplazable antes de tocarlo) y `competitionTitle` (el selector por el nombre completo de su semántica).
  - `responsive_layout_test`: los chips de Tabla y de «Desde» se tocan con `tapFilter` (pueden quedar fuera de la vista); la hoja se abre desde el título y el nombre se verifica en la semántica (a 360, con la fuente de los tests, se ve el corto).
  - `standings_view_test`: el chip «Clausura · Zona B» se lleva a la vista antes de tocarlo; la vista elegida se lee de `ViewTabs` en lugar de `SegmentedButton`.
  - `new_competitions_test`, `home_layout_test`, `widget_test`: el nombre de la competición en la barra se busca en la semántica del selector (puede verse el corto).
  - `test/visual/competition_header_prototype_test.dart`: la referencia «el diseño actual supera 200 px» (E1) pasa a «la app real ≤ 200 px» (148 px hasta el navegador).
- **Quitados** con el reemplazo de E-D8: los de chips de categoría de `competition_picker_test` (dos filas a 768, una línea a 1280, botón a 550, memoria por categoría, «Copas internacionales» elige la Libertadores) y el de chips enteros de `competition_picker_layout_test`.
- `flutter analyze`: sin issues. `flutter test`: **1080 tests en verde** (4 corridas completas). En una de ellas falló una vez `bracket_budget_test` («Fase D5: Libertadores en frío…»), que compara la lista exacta de consultas al abrir Llaves; pasó en las otras 3 corridas completas y en 8 corridas sueltas, sin poder reproducirlo. E4 no toca consultas; queda anotado como posible intermitencia de orden entre la precarga del fixture y la carga del cuadro.

### Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): cambiaron y se regeneraron **después de revisarlas** las 46 de Competiciones (fixture, tablas, calendario, llaves); no cambiaron Inicio, ficha, detalle, estados ni el prototipo. **Nuevas** (25): 411 y 800 px de fixture, tabla de grupos, calendario y llaves; 200 % de fixture de Primera, tabla de grupos, calendario, llaves de la Libertadores y el selector; `competiciones_selector_*` (hoja a 360 / 411, menú a 800 / 1280, claro y oscuro, 200 %) y `fixture_panel_detalle_*` (1280 claro y oscuro, 1920, 1280 al 200 %). Antes en `docs/evidence/e2_test_*` (Competiciones no cambió en E3), después en `e4_test_*`; comparación lado a lado en `docs/evidence/e4_comparacion.html`.
- **Web con escudos reales** (app grabada, Chrome headless): 360 / 411 / 800 / 1280 / 1920, claro y oscuro; selector abierto (hoja y menú), panel de detalle con un partido y texto al 200 % (tamaño de letra del navegador): `docs/evidence/e4_web_*` (38).
- **Android** (APK release, datos en vivo, Motorola One Fusion, 411 dp, tema de la app «Oscuro»): Fixture de Primera, hoja de competiciones, Libertadores, Tabla de grupos y texto al 200 % (`docs/evidence/e4_android_motorola_*`, 6). Sin desbordes. TheSportsDB respondió 429 al cargar la tabla y la app mostró su aviso con «Reintentar» (comportamiento existente). Se restauró la fuente del teléfono (100 %); queda instalado el APK de E4.
- **Pendiente**: la tablet (vertical 800 y horizontal 1280) no estaba conectada (solo el Motorola y el Mate70Max, que no se usó). Esos anchos quedan cubiertos por las capturas automáticas y Web a 800 y 1280, **sin comprobación en el dispositivo**.

### URLs y navegación (Web, app grabada)
Recorrido en Chrome por CDP, mirando la URL en cada paso: enlace directo a `vista=tabla&tabla=clausura-a` y recarga (se conserva); chip de tabla → `tabla=clausura-b`; pestaña Fixture → `fase=clausura&ronda=12`; ronda anterior → `ronda=11`; fase Apertura → `fase=apertura`; menú del título → Libertadores (`/competiciones/4501…&etapa=eliminatoria`); temporada desde la barra → `temporada=2025`; Llaves → `vista=llaves`; URL compartida de cuartos 2026 (`ronda=125&etapa=eliminatoria`) abre los cuartos. A 360: abrir un partido (`/partidos/…`), atrás (vuelve a `fase=clausura&ronda=11`), adelante y atrás, ronda siguiente y recarga (`ronda=12`). Los tests de rutas (`fixture_route_test`, `competitions_page_test`, `standings_view_test`, `calendar_view_test`, `bracket_view_test`) siguen en verde sin cambios en sus URLs.

### Observaciones para fases siguientes (no se implementan en E4)
- **E5**: al 200 % en un teléfono, los nombres de la tabla se parten a mitad de palabra («Independi ente Riv…», visto en la Web).
- **E6**: al 200 % en el panel de 1280, el marcador del héroe del detalle se parte en dos renglones («1 –» / «3»); en Llaves al 200 % las tarjetas recortan «Ida 0-0 · Vuelta…».
- **E7**: a 1920 px la barra empieza en el borde de la sección y la columna de contenido (máx. 1200) va centrada, así que el selector queda lejos de las pestañas (pasa igual en el Inicio; conviene resolverlo en las dos pantallas juntas). Siguen pendientes las observaciones de E3: «Primera División» duplicado en los accesos del Inicio, búsqueda en los estados de error del Inicio, recorte prematuro de nombres largos, ganador del partido vs. clasificado de la serie y la etiqueta «Competiciones» de la barra inferior al 200 %.

---

## 24. Resultados de E5 (18/10/2026) — aprobada

E4 se aprobó y se fusionó. E5 rediseña la Tabla y el Calendario según §8–§9 y la maqueta de E1 (E-D10, E-D11). **Solo presentación**: sin cambios en BLoC, eventos, casos de uso, entidades, reglas deportivas, desempates, repositorios, endpoints, caché, sincronización, rutas, parámetros de URL ni dependencias. La única línea fuera de presentación es el **comentario** de `GroupStage.qualificationNote` (permitido en §12). Mismas consultas (todos los `*_budget_test`, `home_request_budget_test` y `live_refresh_test` en verde).

### Cambios visuales
| Parte | Antes (E4) | Después (E5) |
|---|---|---|
| Superficie de la tabla | Filas sueltas sobre el fondo, cebra (`surfaceContainerLow` en las impares) | Superficie de grupo (radio 12, sin elevación) con divisores finos; encabezado compacto 11 / w600 dentro de la superficie |
| Columnas | Por breakpoint de **pantalla** (< 600: PJ, DG, Pts; 600–1199: + PG, PE, PP; ≥ 1200: todas), celdas fijas de 40 px con `FittedBox` | Por el **ancho de la tabla** (`LayoutBuilder`) y la escala de texto, medidas con `TextPainter`: Pts siempre; PJ y DG juntas si el nombre conserva `max(palabra más larga, 160 px escalados)`; después PG, PE, PP, GF, GC de a una. Con lugar de sobra, cifras de 44 px. 360 px: PJ · DG · Pts; 411 px: + PG (+ PE en la Anual en vivo); desde 768 px: todas |
| Nombres al 200 % | Se partían a mitad de palabra («Independi ente Riv…») y se cortaban a los 2 renglones | El nombre nunca baja de su palabra más larga y no tiene tope de renglones: corta entre palabras («Independiente / Rivadavia»). Si PJ y DG no entran como columnas van en un renglón debajo del nombre («PJ 27 · DG +15»); si ni con solo Pts entrara la palabra más larga, se quita el escudo antes que partirla. Sin achicar la letra |
| Posición y Pts | Posición en negrita; Pts en negrita | Igual, cifras tabulares a la derecha; Pts sobre una columna apenas sombreada de arriba abajo; `*` en la posición compartida |
| Favoritos (E-D11) | — | Fila con `primaryContainer` tenue y estrella `primary` junto al nombre (dentro del texto: baja con la última palabra, no reserva columna); «Favorito.» al final de la semántica. Del `FavoritesBloc` global, 0 peticiones |
| Grupos CONMEBOL (E-D10) | Nota de clasificación entre las demás notas | Barra de 3 px en `success` junto a la posición de los puestos que hoy siguen en alguna copa (`advancingPlaces`: Libertadores 3, Sudamericana 2); «Sigue en competencia.» en la semántica; leyenda «**Sigue en competencia.** + `qualificationNote` literal + Posiciones actuales, no definitivas.» (la nota ya no se repite en el pie). Una posición compartida que cruza el corte no se marca. Primera y Nacional, sin marcadores |
| Cobertura | `Card` con «Fechas consultadas… · …partidos sumados» y «Todos los partidos guardados están sumados» / «Partidos sin sumar (N)» | Una línea debajo del título con ícono + estado («✓ Tabla completa», «Tabla parcial»; con fechas sin consultar, ícono de aviso) + los mismos números. «Partidos sin sumar (N)» desplegable debajo de la tabla, **agrupado por motivo** («Por jugar (N)», «En juego (N)», «Excluidos: sin torneo determinado (N)»…). Si hay partidos excluidos por inconsistencias, `InfoBanner(warning)` arriba de la tabla |
| Notas | 4 renglones `bodySmall` sueltos | Pie con divisor: posición compartida, reglamento y «Calculada por la app… no es la tabla oficial» con ícono de información en el color del texto principal (siempre a la vista) |
| Título de la tabla | `titleLarge` 22 | 16 / w700 (título de sección) |
| Encabezado del mes | ‹ Octubre 2026 › centrado | «Octubre 2026» a la izquierda (16 / w700) y los dos chevrons juntos a la derecha (mismos tooltips, sin relleno como el navegador de ronda de E4), dentro de la superficie de grupo |
| Celdas del calendario | 56 px fijos con `FittedBox` (al 200 % el número se achicaba); píldora `secondaryContainer` con la cantidad | Número tabular + punto y cantidad en `primary`; sin partidos en gris; **hoy** con anillo `primary` (elegido y hoy: anillo `onPrimary`); **elegido** relleno `primary` con texto `onPrimary`. El alto crece con la escala de texto (al 200 % el número no se achica) |
| Lista del día | Contexto («Clausura · Fecha 12») en **cada** fila | `DayHeader` + un `MatchGroup` por fase · etapa con el contexto **una vez** en el encabezado |
| Dos paneles | Desde 1200 px de **pantalla** | Desde 900 px de **vista** y si a la lista le quedan 400 px escalados: 1024 px (tablet horizontal con riel) ya va dividido; a 1280 y 1920 px con texto al 200 %, uno debajo del otro |

### Decisiones y desvíos respecto del plan
- **PJ y DG debajo del nombre** cuando no entran como columnas, en lugar del desplazamiento horizontal que §8 admitía «si no entran ni las tres»: con texto al 200 % en un teléfono no entran; correr la tabla de costado escondería los puntos. La semántica dice siempre PJ, DG y Pts.
- **Nombre cómodo de 160 px** (a escala 1) antes de sumar columnas secundarias: con 140 la tabla de grupos a 360 px sumaba PG y partía «Estudiantes de La Plata»; con 160 queda PJ · DG · Pts como en el plan.
- **Leyenda en el color del texto principal**: en gris de 12 px la pauta de contraste de Flutter (mide píxeles) daba 2,07:1 a 411 px aunque el par de colores cumple (mismo artefacto que en E2). No se cambió el tamaño de letra.
- **Favoritos sin el bloc**: el panel solo (tests del panel) no tiene `FavoritesBloc`; ahí la tabla va sin favoritos. En la app el bloc es global.
- **El panel de detalle solo existe en el Fixture** (la Tabla y el Calendario ocupan toda la columna, como antes). Las columnas igual dependen del ancho de la tabla: un test la pone en una caja de 336 y de 760 px dentro de pantallas de 360 y 1920 y da las mismas columnas para el mismo ancho (760 = la columna junto a un panel de 440).
- La lista de partidos sin sumar no repite el motivo en cada renglón: lo dice el subtítulo de su grupo.
- `StandingsTableView` pasó a su propio archivo (`standings_table_view.dart`); `standings_panel.dart` arma la vista.

### Tests
- **Nuevos**:
  - `test/app/standings_layout_test.dart` (con Roboto): columnas a 360 / 411 / 768 / 800 / 1280 / 1920 en orden de prioridad; mismo ancho de tabla = mismas columnas en un teléfono y un monitor; **200 %** en Anual, Zona, Nacional, Libertadores y Sudamericana a 360 / 411 / 800 px con un favorito: ninguna palabra partida en dos renglones (`getBoxesForSelection` por palabra) ni texto recortado, PJ/DG debajo del nombre en cada fila cuando no son columnas, semántica con PJ, DG y Pts; favoritos a 360 y 1280 (fila resaltada, estrella en la fila del favorito, semántica, quitar y agregar con la tabla abierta sin ninguna consulta); marcadores en Libertadores (3) y Sudamericana (2), leyenda con la nota literal una sola vez, ninguno en Anual, Zona ni Nacional; **posición compartida que cruza el corte** con datos grabados (Libertadores 2025 al 02/04: Grupo B «3* IDV · 3* Universitario» sin marcar; Grupo D «1* Libertad · 1* São Paulo» marcados); cobertura (parcial, motivos que suman 67, aclaración no oficial con ícono; grupo completo); pautas de accesibilidad con favorito y marcador en claro y oscuro a 360 y 1280.
  - `test/app/calendar_layout_test.dart` (con Roboto): uno debajo del otro a 360 / 411 / 768 / 800 / 1000 px y lado a lado a 1024 / 1280 / 1920; a 1280 y 1920 al 200 %, uno debajo del otro; hoy y elegido (semántica `selected`, relleno, anillo); día argentino (el partido de las 00:30 UTC del lunes 12 queda el domingo 11 a las 21:30); al 200 % la celda crece y el número no se achica; pautas en claro y oscuro.
- **Modificados** (sin debilitarlos):
  - `calendar_view_test`: el contexto ya no va en cada fila. Se verifica el encabezado **una vez** y que su grupo tenga **todos** los partidos del día (5, 15, 5 y 2).
  - `standings_view_test`: el resumen de cobertura se busca con `textContaining` (ahora empieza con el estado y el ícono va dentro del mismo texto) y se verifica «Tabla parcial · Fechas consultadas»; los 3 tests de columnas por ancho pasaron a `standings_layout_test` con la fuente real (con la fuente de los tests, 14 px por letra, a 360 px solo entra Pts); importa `standings_table_view.dart`.
  - `bracket_budget_test`: sin cambios en lo que verifica; los `expect` de «cada ronda una vez» llevan la lista ordenada como `reason` para registrar la ronda repetida si la intermitencia vuelve.
  - `test/visual/screens_golden_test.dart`: escena nueva `tabla_favorito` (Boca en Apertura · Zona A) y más anchos de tabla y calendario.
- `flutter analyze`: sin issues. `flutter test`: **1145 tests en verde** en 3 corridas completas seguidas.

### Intermitencia de `bracket_budget_test`
Apareció **una vez** en la primera corrida completa de E5 (la misma prueba que en E4: «Fase D5: Libertadores en frío…», línea 121): una ronda de la Sudamericana se pidió dos veces (6 pedidos, 5 rondas distintas: r32, r150, r16, r125, r200). No se reprodujo en 6 corridas del archivo con otros tests en paralelo ni en las 3 corridas completas siguientes.
- **Causa probable** (lectura del código, no reproducida de forma determinista): `MatchRepositoryImpl.syncRound` y `watchRound` leen la vigencia guardada (`_metadata.get`, asíncrona) y **después** llaman a `SyncScheduler.run`; el scheduler une pedidos solo mientras el trabajo está en cola o en curso. Si el trabajo de la misma ronda de otro consumidor (el fixture de fondo pide la etapa actual —r150— con P0 y la siguiente con P1; el cuadro pide las 5 rondas con P2) **termina justo entre esa lectura y el `run`**, la ronda se pide otra vez. En los tests parte del trabajo corre fuera de `FakeAsync` (anotado en `CLAUDE.md`), así que el orden depende de la carga de la máquina; en la app puede costar una consulta extra en la misma ventana.
- **No se tocó** (sincronización fuera del alcance de E5) ni se debilitó el test ni el presupuesto. **Propuesta para aprobar aparte**: volver a mirar la vigencia dentro del trabajo encolado antes de pedir (salvo refresco forzado), con un test del caso.

### Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): cambiaron y se regeneraron **después de revisarlas** las 29 de Tabla y Calendario; **nuevas** (12): `tabla_favorito_{360,1280}_{claro,oscuro}` y `_360_200_claro`, `tabla_anual_{411,800}_claro` y `_360_200_claro`, `tabla_grupo_libertadores_{768,1920}_claro`, `calendario_{768,1920}_claro`. No cambió ninguna otra pantalla. Antes en `docs/evidence/e4_test_*` (las de los encuadres nuevos, generadas con el código de E4), después en `e5_test_*`; comparación lado a lado en `docs/evidence/e5_comparacion.html`.
- **Web con escudos reales** (app grabada, Chrome headless por CDP): Tabla Anual a 360 / 411 / 768 / 800 / 1280 / 1920, grupo de la Libertadores con marcadores, Apertura · Zona A con Boca favorito, Calendario a 360 / 411 / 768 / 800 / 1024 / 1280 / 1920, claro y oscuro, y texto al 200 % (tamaño de letra del navegador): `docs/evidence/e5_web_*` (33).
- **Android** (APK release, datos en vivo, Motorola One Fusion, 411 dp, tema de la app «Oscuro»): Tabla Anual con Boca favorito, la misma al 200 % (nombres enteros, PJ/DG debajo), Calendario al 100 y al 200 %, grupo de la Libertadores con marcadores (`docs/evidence/e5_android_motorola_*`, 5). Sin desbordes. TheSportsDB respondió 429 al arrancar y la app mostró sus avisos (comportamiento existente). Al terminar se quitó el favorito de prueba y se restauró la fuente del teléfono (100 %); queda instalado el APK de E5.
- **Pendiente**: la tablet (vertical 800 y horizontal 1280) seguía sin conectarse (solo el Motorola y el Mate70Max, que no se usó). Esos anchos quedan cubiertos por las capturas automáticas y Web a 800, 1024 y 1280, **sin comprobación en el dispositivo**.

### Observaciones para fases siguientes (no se implementan en E5)
- **E7**: las iniciales de reserva de `TeamBadge` (escudo sin imagen) escalan con el texto y al 200 % se parten dentro del círculo («NO» de Newell's en dos renglones); solo se ve sin red. Con texto grande, un `InfoBanner` con acción en un teléfono deja el texto en una columna angosta (el aviso «Completar» del Calendario ocupa media pantalla al 200 %). El aviso de la Tabla tras un 429 dice «No se pudieron consultar todas las fechas (16 de 16)» aunque las 16 estén guardadas: el número cuenta las guardadas, no las actualizadas (texto anterior a E5).
- **Sincronización** (fuera del Hito E): la ventana de carrera descripta arriba.

---

## 25. Resultados de E6 (18/10/2026) — aprobada

E5 se aprobó. E6 rediseña Llaves, la cabecera de la ficha y el detalle de partido según §10–§11 y la maqueta de E1 (E-D14). **Solo presentación**: sin cambios en dominio, reglas deportivas (`TieOutcome`, `KnockoutTie`, `KnockoutBracketBuilder`), BLoC, eventos, casos de uso, repositorios, endpoints, caché, sincronización, rate limiter, rutas, URL ni dependencias. Mismas consultas (todos los `*_budget_test`, `home_request_budget_test` y `live_refresh_test` en verde). Sin logos de competiciones.

### Cambios visuales
| Parte | Antes (E5) | Después (E6) |
|---|---|---|
| Tarjeta de llave | `Card` con sombra; nombre en 1 renglón con «…» («Independiente Rivadav…»); renglón de estado en 1 renglón con «…»; alto fijo calculado con 2 renglones | Superficie de grupo (radio 12, sin elevación) con borde `outlineVariant` de 1 px. **Medida con la escala de texto**: la columna no baja de la palabra más ancha de los nombres y todas las tarjetas del cuadro tienen el alto de la más alta (conectores alineados). Nombres en hasta 2 renglones (regla §5.1); goles y tanda en columnas alineadas, cifras tabulares |
| Ganador | Negrita + ✓ `primary` en su propia columna; perdedor en gris | Negrita + ✓ en `success` **dentro del texto** (carácter de la fuente de íconos), pegado a la última palabra con un espacio duro: no reserva columna y, si no entra, baja con esa palabra. Perdedor en gris. Sin evidencia, nadie en negrita ni ✓ |
| Piernas / estado | «Ida 0-0 · Vuelta…» cortado al 200 % (observación de E4); en juego en `error` | Texto completo: cada pierna se une con espacios duros y se parte **entre** piernas («Ida 1-0 ·» / «Vuelta 0-2»). En juego en `AppPalette.live` y negrita. «Sin dato de la definición» con ícono `help_outline` |
| «A definir» | `surfaceContainerHighest` con sombra | `surfaceContainerHigh`, borde fino, ícono `help_outline` por equipo, «Sin datos del partido» en gris |
| Conectores | Todos iguales (`outline`, 1,5 px, codos rectos) | **Definido** (se sabe quién avanzó): línea llena de 2 px en `onSurfaceVariant`. **Pendiente**: punteada de 1,5 px en `outline`. El tramo final hacia la llave siguiente va lleno solo si las dos que llegan están definidas. Primer codo redondeado (radio 6). La diferencia no depende solo del color |
| Campeón | Franja `primaryContainer` con sombra y texto 22 px (al 200 %, dos renglones grandes) | Fila compacta sobre la superficie de grupo: trofeo en `success`, escudo 32, «Campeón: X» en `titleMedium` |
| Encabezados de ronda | `titleSmall` en 1 renglón con «…» | 14 / w600 en gris, centrados, en los renglones que hagan falta (el alto se mide) |
| Playoffs y «Sin ubicar» | `titleMedium` suelto | `SectionHeader` (con «Sus ganadores juegan los octavos de final.» al lado) |
| Cabecera de la ficha | `Card` con escudo 64, nombre `titleLarge`, chips con borde y trofeo; favorito en la barra | Sin tarjeta: escudo 72, nombre 24 / w600 con el **favorito pegado al nombre** (mismos tooltips y comportamiento; ya no está en la barra), estadio · ciudad en gris; las competiciones como chips sin borde en `surfaceContainerHigh`, **debajo y a todo el ancho**. Si la palabra más larga del nombre no entra al lado del escudo (texto grande), el escudo sube; si tampoco entra al lado de la estrella, la estrella sube junto al escudo |
| Sincronización de la ficha | Arriba de la cabecera | Debajo de la cabecera (barra de 3 px + «Completando partidos… n/t»; falla con `InfoBanner(offline)`) |
| Encabezado del detalle (`MatchHero`) | Competición `titleMedium` y etapa; escudos 64; marcador `headlineMedium` en una columna fija de 120 px (al 200 % se partía «1 –» / «3»); «Penales: 3-4» | Competición (14 / w600), etapa y **día · hora de Argentina** en gris; escudos 72; nombres 16 con el **ganador del partido en negrita**; marcador 36 / w700 tabular (en vivo en `live`), «Penales: 3-4», etiqueta de estado. En una llave: **«Global …»** y **«✓ Avanza …»** en `success` (con su nota de evidencia), o «Sin dato de la definición» |
| Marcador al 200 % | Partido en dos renglones | Medido y con `softWrap: false`: si a los costados no entran los nombres sin partir palabras, los equipos suben en dos columnas y el marcador va entero debajo; si tampoco, los equipos van uno debajo del otro (escudo 32, local arriba) |
| Datos del detalle | `Card` con `ListTile` de 72 px (ícono, valor, «etiqueta · nota») | Filas compactas **etiqueta \| valor** en la superficie de grupo con divisores; la nota debajo del valor. **2 columnas desde 600 px disponibles** (detalle a pantalla completa desde la tablet vertical), **1 columna** en teléfonos y en el panel de 440. La columna de etiquetas se mide; si una palabra no entra, la etiqueta va arriba del valor |
| Acciones | `OutlinedButton` | `FilledButton.tonal` debajo del héroe («Compartir», «Agregar al calendario (todo el día)»), mismos textos y avisos. «Ver video» y la miniatura, al final como antes |

**Resultado del partido vs. resultado de la serie** (pedido de la fase): la negrita del héroe y de las filas es siempre el ganador **del partido** (`TieOutcome.of`, como desde E2). Quién avanza en la llave va aparte, con ✓ y el texto de `MatchLabels` (`detail.advancement`). Ejemplo grabado: Libertadores 2026, vuelta de cuartos LDU 3-2 Palmeiras con penales 3-4 → «**LDU Quito**» en negrita y «✓ Avanza Palmeiras (4-3 en penales)». No se fuerza que coincidan ni se infiere nada sin evidencia; los textos «Clasificó X por…» siguen anotados para E7.

### Decisiones y desvíos respecto del plan
- **Conector pendiente en `outline` punteado**, no en `outlineVariant`: en claro `outlineVariant` sobre el fondo da ~1,2:1 y §13 pide ≥ 3:1 en conectores. La diferencia definido / pendiente queda en el grosor y el punteado (no solo color).
- **✓ dentro del nombre** (no en una columna): con la columna, a 360 px y 200 % la tarjeta de «Independiente Rivadavia» con tanda medía 344 px y no entraba en la pantalla (336 útiles); con el ✓ en el texto mide 317. Primero fue un `WidgetSpan`; en la segunda pasada por el teléfono, al 200 % el ✓ de «Alianza Lima» y «Once Caldas» (Playoffs de la Sudamericana 2025) quedó solo en un renglón: el motor de texto corta antes de un `WidgetSpan` aunque lo preceda un espacio duro. Ahora es el carácter de la fuente de íconos en el mismo texto, y el espacio duro sí lo une («Alianza / Lima ✓»).
- **Global en el héroe**: la fila «Serie de ida y vuelta» lista las piernas y el global pasó al héroe, junto a quién avanza (una sola vez cada texto).
- **Sin fila «Llave»**: «Avanza…» y su nota van en el héroe; la palabra «Llave» queda en la semántica de ese renglón («Llave: Avanza Palmeiras (4-3 en penales)»). Las notas («Según los partidos guardados…», «TheSportsDB no informa cómo se definió…», «TheSportsDB no informa el resultado de los penales.», «sin confirmar») se conservan con el mismo texto.
- **Día y hora en el héroe y en las filas**: el héroe da el contexto («Miércoles 16/09/2026 · 19:00»; en un partido sin empezar, solo el día, porque la hora va en grande en el centro) y las filas «Fecha» y «Hora (Argentina)» conservan sus notas.
- **Centro del héroe como la fila de partido**: el parcial de un suspendido o interrumpido se muestra (`MatchLabels.showsScore`, como desde E2) y un postergado o cancelado muestra «—» (antes, la hora).
- **Chips de la ficha debajo, a todo el ancho**: al lado del escudo, al 200 % «Copa Sudamericana» quedaba cortado. Un chip que no entra usa dos renglones; la letra no se achica.
- **La barra de la ficha conserva el nombre del equipo** como título (E-D14 solo mueve el favorito). Queda repetido con la cabecera; a revisar en E7.
- **Pautas en Llaves de Primera**: con Roboto, la pauta de contraste (mide píxeles) da 2,25:1 en el chip «Clausura» sin elegir con «Apertura» elegida (fila de E4, mismo estilo que los demás chips; también con el código de E5). Con «Clausura» elegida pasa. Las tarjetas de llaves pasan en las 4 copas/torneos, claro y oscuro, 360 y 1280.
- Separación entre columnas del cuadro: 24 (de la escala) en lugar de 28. Tokens nuevos: `AppSizes.connectorDefined/connectorPending/connectorDash`, `AppRadius.connector`, `AppText.heroTeam/heroTeamWinner/teamHeaderName`. `TextMeasure` (`shared/presentation/layout/text_measure.dart`) mide como `Text` (con `WidgetSpan`).

### Tests
- **Nuevos** (con Roboto):
  - `test/app/bracket_layout_test.dart` (61): Primera Apertura, Copa Argentina, Libertadores 2025 y 2026, Sudamericana 2025 a **360 / 411 / 800 / 1280 × 100 y 200 %**: ninguna palabra partida ni texto recortado (solo un nombre puede terminar en «…» desde el 3.er renglón), tarjetas ≥ 48 px y, en teléfonos, la primera columna entera en la pantalla; al 200 % las piernas «Ida/Vuelta n-n» en un solo renglón cada una y el cuadro desplazable; Apertura con **15 ✓** (8 + 4 + 2 + 1) y «Campeón: Belgrano»; final de la Sudamericana 2025 sin ✓, con «Sin dato de la definición» y sin «Avanza»; Libertadores 2026 con «Ida en juego» en `live` y la final «A definir»; al 200 % en 360 y 411 (Sudamericana 2025 con Playoffs) el ✓ en el mismo renglón que la última palabra de cada nombre; pautas de accesibilidad en claro y oscuro a 360 y 1280.
  - `test/app/match_detail_layout_test.dart` (47): Primera (final), serie con penales, Copa Argentina por penales y programado con nombres largos a **360 / 411 / 800 / 1280 × 100 y 200 %**: el centro («1 – 3», «17:00»…) en un renglón y dentro de la pantalla, ninguna palabra partida; **panel de 440 px** a 1280 (100 y 200 %) y 1920: marcador entero dentro del panel y datos en una columna; dos columnas a 1280 a pantalla completa y una a 411; ganador del partido en negrita vs. «Avanza» aparte (serie) y el mismo equipo (partido único por penales); programado sin ganador con «Agregar al calendario» tonal; pautas en claro y oscuro.
  - `test/app/team_header_layout_test.dart` (14): 360 / 411 / 800 / 1280 × 100 y 200 %: favorito en la cabecera y no en la barra, pegado al nombre, escudo de 72, estadio · ciudad, 3 chips enteros, ninguna palabra partida; «Independiente Rivadavia» al 200 % en 360 (escudo y estrella arriba, nombre entero debajo); la estrella agrega y quita; pautas en claro y oscuro.
  - Helper `test/helpers/text_layout.dart` (`expectWholeWords`, `paragraphsIn`, `linesOf`).
- **Modificados** (sin debilitarlos): `continental_bracket_view_test` («tocar una serie abre su vuelta…»): el texto de la fila de la serie ya no termina con el global; se verifica la fila con las dos piernas, la etiqueta «Serie de ida y vuelta», «Global Peñarol 2-3 Racing Club» y «Avanza Racing Club (global 3-2)», cada uno **una sola vez**. `test/visual/screens_golden_test.dart`: escenas nuevas (abajo).
- Sin cambios en los demás tests de Llaves, ficha y detalle (`bracket_view_test`, `continental_finals_test`, `team_detail_page_test`, `team_detail_layout_test`, `match_detail_test`, `match_detail_actions_test`, `accessibility_test`, `responsive_layout_test`).
- `flutter analyze`: sin issues. `flutter test`: **1312 tests en verde** (1145 + 122 nuevos + 45 capturas nuevas).

### Intermitencia de `bracket_budget_test`
Falló **dos veces** en corridas completas de E6 (la misma prueba de E4 y E5: «Libertadores en frío = octavos a final (4)…»): en la primera y en la que siguió al arreglo del ✓. La segunda vez el `reason` mostró la ronda repetida: la final de la Sudamericana 2026 (`4724:r200:s2026`) pedida dos veces, la carrera descripta en §24. Pasó en 8 corridas sueltas del archivo y en las demás corridas (3 de la suite completa y 1 sin `test/visual`). No se tocó (corrección técnica independiente, como se pidió).

### Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): cambiaron y se regeneraron **después de revisarlas** las 29 de Llaves, ficha y detalle (`llaves_primera_*`, `llaves_libertadores_2025_*`, `ficha_boca_*`, `detalle_primera_*`, `detalle_serie_penales_*`, `fixture_panel_detalle_*`); no cambió ninguna otra pantalla. **Nuevas** (45): `llaves_libertadores_2026`, `llaves_sudamericana_2025`, `llaves_copa_argentina`, `detalle_serie_global`, `detalle_copa_penales`, `detalle_programado` y `fixture_panel_detalle_serie` (panel de 440 con la serie), más 411 / 800 y 200 % de Llaves, ficha y detalle. Las «antes» de los encuadres nuevos se generaron con el código de E5. Antes en `docs/evidence/e5_test_*`, después en `e6_test_*` (74 + 74); comparación lado a lado en `docs/evidence/e6_comparacion.html`.
- **Web con escudos reales** (app grabada en Chrome headless por CDP, mismo guion con el código de E5 y el de E6): **67 pares** antes (`docs/evidence/e5_web_*`) / después (`e6_web_*`): Llaves de Primera (Apertura), Libertadores 2025 y 2026, Sudamericana 2025 y Copa Argentina; detalle de la serie con penales, de la serie definida por el global, del partido de Copa por penales y de un programado; panel de detalle (partido y serie) y ficha de Boca; a 360 / 411 / 768 / 800 / 1280 / 1920 en claro y oscuro, y al **200 %** (tamaño de letra del navegador) Llaves, detalle, panel y ficha. En el «antes» al 200 % se ven el marcador del panel en dos renglones («1 –» / «3») y los nombres cortados en las tarjetas («Atlético N…»); en el «después», resueltos (las piernas cortadas de E4 se ven en el golden `e5_test_llaves_libertadores_2025_360_200_claro.png`). Siguen valiendo los «antes» de E1/E2/E4 (`e2_web_*`, `e4_web_*`) de los mismos encuadres. Las Web de Llaves se tomaron antes del arreglo del ✓ (era un `WidgetSpan`): la única diferencia es la posición del ✓ en el renglón; los goldens y el Android ya tienen el arreglo.
- **Android** (APK release, datos en vivo, Motorola One Fusion, 411 dp, tema de la app «Oscuro»): detalle de un partido programado con «Agregar al calendario», Llaves de Primera y de la Libertadores 2026, detalle de la serie LDU–Palmeiras (LDU en negrita, «✓ Avanza Palmeiras» aparte), ficha de Boca con el favorito junto al nombre y 4 chips, y al **200 %** la ficha, Llaves de la Libertadores («Ida 0-0 · Vuelta 1-1» entero) y el detalle de una serie con los equipos apilados y el marcador entero (`docs/evidence/e6_android_motorola_*`, 8). Sin desbordes. TheSportsDB respondió 429 al abrir la ficha y la app mostró su aviso y «Reintentar» (comportamiento existente). Se restauró la fuente del teléfono (100 %); queda instalado el APK de E6.
- **Android, segunda pasada** (a pedido, mismo teléfono, tema de la app **claro**): Llaves de la Copa Argentina desplazando el cuadro hasta la final (cuartos con tanda, semifinal programada, **conector punteado** hacia la final «A definir»), Sudamericana 2026 y 2025 (final «Sin dato de la definición», sin ✓ ni negrita) y su detalle con la nota, la estrella de la cabecera de la ficha (agregar con el aviso «Deshacer» y quitar), «Reintentar» tras un 429 (avance 12 → 32 de 42) y un partido **en vivo** (Racing 1-0 Independiente, entretiempo) al 100 y al 200 %. Al 200 % apareció el ✓ suelto de los Playoffs (arriba); se corrigió, se reinstaló el APK y se verificó en el teléfono (`e6_android_motorola_playoffs_200_*`). Al terminar: tema «Oscuro», fuente al 100 %, sin favoritos agregados, APK de E6 instalado (`docs/evidence/e6_android_motorola_*`, 21 en total).
- **No se pudo probar en la tablet física** (SKY PAD10MAX): seguía sin conectarse (solo el Motorola y el Mate70Max, que no se usó). Quedan **sin comprobación en el dispositivo**: tablet vertical 800 px y horizontal 1280 px (con el panel de detalle de 440 px), en Android. Esos anchos están cubiertos por las capturas automáticas (800 y 1280, panel incluido, 100 y 200 %), por las Web a 800 / 1280 / 1920 y por los tests de layout.

### Observaciones para E7 (no se implementan en E6)
- Mejora ya anotada: «Clasificó X por penales» / «por resultado global» en la serie (sin reglas nuevas).
- La barra de la ficha repite el nombre del equipo que ahora está en la cabecera.
- Al 200 % en un teléfono el héroe del detalle es alto (equipos apilados): «Avanza…» queda debajo del primer pantallazo. La línea «día · hora» puede partirse dejando la hora sola en un renglón.
- Al 200 % todas las tarjetas del cuadro toman el alto de la más alta (una con nombre en dos renglones): las de nombres cortos quedan con aire. Es lo que mantiene alineados los conectores.
- El chip «Clausura» de Llaves de Primera y la pauta de contraste con Roboto (arriba).
- Siguen las de E5 (iniciales de `TeamBadge` al 200 %, `InfoBanner` con acción al 200 %, texto del aviso de la Tabla tras un 429) y de E3/E4.

---

## 26. Resultados de E7 (18/10/2026) — esperando aprobación

E6 se aprobó y se fusionó (rama de trabajo = `main` con E6, `27af58d`). E7 cierra el hito: consistencia de las pantallas que faltaban, correcciones pendientes de E2–E6, accesibilidad y verificación completa. **Solo presentación**: sin cambios en dominio, reglas deportivas (`TieOutcome` intacto), BLoC, casos de uso, repositorios, endpoints, caché, sincronización, rate limiter, rutas, URL ni dependencias. Sin logos de competiciones. Mismas consultas (todos los `*_budget_test`, `home_request_budget_test` y `live_refresh_test` en verde).

### 26.1 Consistencia de pantallas
| Pantalla / estado | Antes (E6) | Después (E7) |
|---|---|---|
| Equipos (búsqueda) | Campo rectangular; una `Card` por equipo; aviso «Resultados de TheSportsDB» en texto suelto; botón de copas con borde, arriba de los resultados; error de copas en texto gris | Campo con la forma del acceso del Inicio (píldora, superficie de grupo); los equipos en un `MatchGroup` con divisores; el aviso como `InfoBanner`; **los resultados enseguida del aviso y la búsqueda en copas después** (al 200 % el resultado quedaba fuera de la pantalla); botón tonal; error como `InfoBanner(error)` |
| Favoritos | Una `Card` por equipo | Un `MatchGroup`; pie en `onSurfaceVariant` |
| Ajustes | Opciones y temporadas sueltas sobre el fondo; error en texto; carga sin etiqueta; «Borrar seleccionadas» relleno | Cada sección en un `MatchGroup` (tema; una superficie por competición con `MatchGroupHeader`); error como `InfoBanner(error)` con «Reintentar»; cargas con etiqueta semántica; botón tonal (el diálogo conserva «Borrar» relleno) |
| Enlace inválido (`/partidos/abc`, `/equipos/abc`) | `ComingSoonPage` con «Próximamente» (no correspondía) | `InvalidLinkPage`: `EmptyView` «Enlace no válido» + «Ir al inicio» |
| Diagnóstico | Espacios, tamaños y colores literales (`Colors.green/red`, `fontSize`) | Tokens (`AppSpacing`, `AppSizes`, `AppPalette.success`, `colorScheme.error`, estilos del tema). Sigue siendo una pantalla de desarrollo |
| Barras superiores a 1920 px | Empezaban en el borde de la sección; el contenido centrado (máx. 1200 / 900 / 720) | `ContentAppBar`: la barra tiene el ancho de la columna de contenido, así título, selector y acciones quedan sobre el contenido (Inicio, Competiciones, ficha, detalle, Equipos, Favoritos, Ajustes). Anchos con nombre en `Breakpoints` (`maxListWidth` 900, `maxNarrowWidth` 720, `listWidth()`) |
| Avisos con acción al 200 % | El texto quedaba en una columna angosta («Completar» ocupaba media pantalla) | `InfoBanner`: la acción va al lado si al texto le quedan ~12 letras por renglón; si no, debajo, alineada al final |
| Descarga detenida (Tabla, Calendario, Llaves) | «No se pudieron consultar todas las fechas (16 de 16)» tras un 429 | `SyncTexts`: separa lo **guardado**, lo **al día** y la **actualización fallida** (ver 26.3). Avance: «Fechas al día: 3 de 16». La cobertura de la tabla dice «Fechas guardadas» (antes «consultadas») |

Revisados sin cambios (ya usaban los componentes comunes): `StaleDataBanner`, aviso de 429 / límite propio (`RateLimitNotice` con `InfoBanner(band)`), estados de carga (indicador con etiqueta), vacío (`EmptyView`) y error (`ErrorView`), barras de progreso de la ficha, Tabla, Calendario y Llaves. No se quitó ningún aviso.

### 26.2 Correcciones visuales pendientes
- **Inicio — «Primera División» repetido**: si una categoría tiene un solo acceso con su mismo nombre, se muestra solo el chip, que pasa a ser el encabezado de su categoría (`MergeSemantics` + `header`): misma navegación y estructura para los lectores de pantalla. Las demás categorías conservan su etiqueta.
- **Inicio — búsqueda con error**: en el estado de error, debajo de 1200 px, el acceso «Buscar equipo» sigue arriba de «Reintentar».
- **Inicio / Competiciones a 1920 px**: título, selector y acciones sobre la columna (antes, 231 px a la izquierda del contenido).
- **Nombres largos en la fila**: hasta **3 renglones** a los costados del marcador (2 con los equipos apilados). «Gimnasia y Esgrima de Mendoza» y «… de La Plata» entran enteros a 360 y 411 px (antes «Gimnasia y / Esgrima de L…»). El corte con «…» solo queda desde el 4.º renglón (p. ej. «Central Córdoba de Santiago del Estero» en la columna de 360).
- **Iniciales de escudos al 200 %**: crecen hasta 1,3× y nunca se parten («NO» de Newell's iba en dos renglones).
- **Ganador del partido vs. clasificado de la serie**: la negrita sigue siendo el ganador **del partido** (`TieOutcome.of`) y quién pasa en una **serie de ida y vuelta** se dice con su evidencia: «Clasificó Palmeiras por penales (4-3)», «Clasificó Racing Club por resultado global (3-2)», «Clasificó River Plate: juega la ronda siguiente». En partido único (Primera, Copa Argentina, finales) sigue «Avanza X (4-3 en penales)»: ahí el ganador del partido es el que pasa. Mismos datos de `TieOutcome.ofTie`; sin inferencias nuevas. Se aplica al pie de la serie (Fixture), al héroe del detalle (y su semántica «Llave: …») y a la semántica de las tarjetas de Llaves.
- **Ficha — nombre duplicado**: la barra dice «Equipo» mientras se ve la cabecera con el nombre, y pasa a «Boca Juniors» cuando la cabecera sale de la vista (se guarda el último alto medido: lejos, la lista descarta la cabecera; visto en el teléfono).
- **Detalle al 200 %**: con el marcador debajo de los equipos, escudos de 32 en lugar de 72 (−40 px); la etapa y «día · hora» se mantienen juntas por partes si no entran en un renglón («Eliminatorias ·» / «Cuartos de final», «Miércoles» / «16/09/2026 · 19:00»): ya no queda «final» ni la hora sola. Sin perder nombres, marcador, penales ni clasificado.
- **Llaves — tarjetas cortas**: cada tarjeta tiene el alto de su contenido, centrada en su lugar; el lugar sigue saliendo de la más alta, así los conectores quedan alineados (lo verifica un test: centros equidistantes).
- **Calendario — «Completar» al 200 %**: acción debajo del texto, que usa todo el ancho (de ~9 renglones a 4 a 360 px).
- **Barra inferior al 200 %**: «Competiciones» se partía («Competicio / nes»): Flutter limita esas etiquetas a 1,3× y a 360 px no entra desde ~1,1×. La escala máxima de las etiquetas se calcula para que la más larga entre (nunca menos de 1×). Costo: al 200 % en un teléfono las etiquetas quedan cerca del tamaño normal (ícono + etiqueta siguen, y la semántica no cambia).

### 26.3 «16 de 16» después de un 429 (investigación)
- **Causa**: el aviso usaba `StandingsCoverage.roundsQueried`, que cuenta las fechas **guardadas**, no las actualizadas. Además, con «Actualizar», `WatchStandings` primero fuerza las fechas recientes (`RefreshRecentRounds`) y después corre `CompleteRounds`: si el forzado falla por el 429 pero las demás fechas están vigentes por su TTL, `progress.done == progress.total` (16/16) y el fallo es el del forzado (`forcedFailure`). Lo mismo en Calendario y Llaves.
- **Arreglo en presentación** (sin tocar cobertura ni sincronización): `SyncTexts.stopped` usa los datos que ya existen (`SyncProgress.done/total/failure` + lo guardado). Si quedaron fechas sin actualizar: «No se pudieron actualizar todas las fechas: 12 de 16 al día. Se muestra lo guardado (16 de 16 fechas). Demasiadas consultas.» Si todas están al día pero la actualización falló: «No se pudo actualizar. Se muestra lo guardado (16 de 16 fechas). Demasiadas consultas.»
- **No resuelto en presentación** (requeriría un cambio funcional, no se hizo): distinguir qué fechas puntuales fallaron y cuántas consultas se hicieron en el forzado (`SyncProgress` no lo expone por separado; `fetched` suma las dos etapas).

### 26.4 Accesibilidad
- **Chip «Clausura» (2,25:1 en E6)**: no era un problema de colores (#15191E sobre blanco, 17:1). La pauta de Flutter mide píxeles: el chip «Apertura» en negrita mide 86,4 px y dejaba a «Clausura» en x = 106,4; con densidad 1 su texto se dibujaba borroso y el gris del suavizado (#ABADAF, 49 píxeles) superaba al color real (#15191E, 47). **Corrección**: `ScrollRow` redondea hacia arriba el ancho de cada elemento (`_WholePixelWidth`): todos empiezan en un píxel entero (texto nítido también en la Web en monitores de 1×; el color real pasa a 70 píxeles contra 23). Las pautas de Llaves de Primera se corren ahora **con los dos torneos elegidos** (se agregó el caso «Apertura»), no solo con el que pasaba.
- **Estados de chips y pestañas** (test nuevo, tema de la app y Roboto, claro y oscuro, 360 y 1280, 100 y 200 %): elegido (negrita, sin borde), sin elegir después de uno en negrita, **con foco** (contraste con el resaltado), **deshabilitado** (se anuncia como inactivo) y pestaña elegida (semántica). Hallazgo: el tema fijaba el color de la etiqueta para todos los estados y un chip deshabilitado se veía activo; ahora usa `onSurface` al 38 % (Material 3). La app no tiene chips deshabilitados hoy; la pauta de contraste de WCAG no se aplica a controles inactivos.
- Objetivos táctiles ≥ 48 px, etiquetas y contraste en los dos temas: en verde en todos los tests de pautas (incluidas las pantallas nuevas en las capturas de 200 %).

### 26.5 Intermitencia de `bracket_budget_test` (solo investigación, sin cambios; corregida en §27)
- **Recorrido exacto** (Sudamericana 2026, al pasar de la Libertadores con Llaves abierta): (1) el fixture carga la etapa actual con P0 y precarga la siguiente —la final, `4724:r200:s2026`— con `prefetchRound` → `syncRound` (P1); (2) el cuadro (`WatchKnockoutBracket` → `CompleteRounds`) recorre las 5 rondas de `bracketApiRounds` con P2 y, para cada una, `syncRound` **lee la vigencia** (`_metadata.get`, asíncrona) y **después** llama a `SyncScheduler.run`. El scheduler une pedidos de la misma clave solo mientras el trabajo está en cola o en curso. Si el trabajo P1 de la final **termina** (guarda la vigencia y sale de `_byKey`) entre la lectura de P2 y su `run`, P2 crea un trabajo nuevo y la ronda se pide **otra vez**. `watchRound` tiene la misma ventana.
- **¿Puede volver a pedirse una ronda ya actualizada por otra tarea?** Sí. **Reproducido de forma determinista** con un test fuera de la suite (`docs/evidence/e7_bracket_race_probe_test.dart.txt`): una `QueryMetadataStore` que retiene la lectura de P2 hasta que P1 terminó → 2 pedidos de `4724:r200:s2026` (se esperaba 1). Es la ronda que se vio repetida en E6. En los widget tests el orden depende de la carga de la máquina (parte del trabajo corre fuera de `FakeAsync`); en la app puede costar una consulta extra en la misma ventana.
- **Prueba determinista propuesta**: ese mismo test en `test/features/matches/data/match_repository_impl_test.dart` (falla hoy; debe pasar con el arreglo), más uno para `watchRound` y uno de «refresco forzado que se une a un trabajo no forzado».
- **Corrección mínima propuesta**: en `syncRound`/`watchRound`, pasar al trabajo encolado el `fetchedAt` que leyó quien lo encoló y, **dentro del trabajo**, releer la vigencia: si `fetchedAt` avanzó desde esa lectura (otro trabajo guardó la ronda en el medio), no pedir. `syncRound` devuelve si la vigencia cambió desde su lectura (como hoy cuenta «consultada» también al sumarse a un trabajo ajeno).
- **Riesgos**: una lectura más de sembast por trabajo; un refresco manual que se suma a un trabajo ya encolado podría resolverse con datos guardados segundos antes (más nuevos que el pedido); el conteo `fetched` (y el aviso «Ya está actualizado») puede cambiar en ese caso; hay que revisar los presupuestos (no deberían subir). **Necesita aprobación específica** (tarea técnica aparte). No se debilitó el test ni se subió ningún presupuesto.

### 26.6 Tests
- **Nuevos**:
  - `test/shared/sync_texts_test.dart` (4): los textos de descarga detenida (todas al día con fallo, parcial, sin total, avance).
  - `test/app/sync_notice_test.dart` (4, Roboto): Tabla Anual con un 429 en el refresco manual (no dice «consultar… (16 de 16)», sí «Se muestra lo guardado (16 de 16 fechas)» y «Reintentar»); aviso «Completar» con la acción al lado (360 al 100 %, 768 al 200 %) y debajo con el texto a lo ancho (360 al 200 %).
  - `test/shared/control_states_test.dart` (8): estados de chips y pestañas (26.4).
  - `test/app/visual_consistency_test.dart` (14, Roboto): nombres largos a 360 y 411; iniciales al 200 %; «Primera División» una vez y el chip como encabezado (360 y 1280); búsqueda en el error del Inicio (360 y 800); título del Inicio y selector de Competiciones sobre el contenido a 1920 (con pautas); título de la ficha según el desplazamiento (incluido lejos); «Competiciones» en un renglón al 200 % (360 y 411); tarjetas de Llaves con su alto y centros equidistantes; detalle al 200 % (escudos de 32, «16/09/2026 · 19:00» y «Cuartos de final» enteros, «Clasificó…»); enlace inválido.
  - `bracket_layout_test`: caso «Primera Apertura 2026» en las pautas (4 tests más).
- **Modificados** (sin debilitarlos):
  - `continental_finals_test`, `continental_bracket_view_test`, `match_detail_test`, `match_detail_layout_test`, `match_row_test`: los textos de las series pasan de «Avanza X (global 3-2)» a «Clasificó X por resultado global (3-2)» (pedido de la fase). Mismas cuentas (15, 14, 8 + 4 con quién pasa); donde se verificaba que no apareciera «Avanza», ahora tampoco «Clasificó».
  - `standings_layout_test`, `standings_view_test`: «Fechas consultadas» → «Fechas guardadas» (mismos números).
  - `team_search_continental_page_test`: el helper deja dibujar el desplazamiento de `ensureVisible` antes de tocar (la acción ahora va después de los resultados).
  - `test/helpers/text_layout.dart` (`expectWholeWords`): un nombre con tope de 2 **o 3** renglones puede terminar en «…».
  - `test/visual/screens_golden_test.dart`: escenas nuevas `busqueda`, `favoritos`, `favoritos_vacio`, `ajustes` e Inicio a 411 y 800 (toda la matriz 360 · 411 · 768 · 800 · 1280 · 1920).
- `flutter analyze`: sin issues. `flutter test`: **1379 tests en verde** (1312 + 34 nuevos + 33 capturas nuevas), en 2 corridas completas seguidas; `bracket_budget_test` pasó en las dos.

### 26.7 Capturas
- **Automáticas** (Flutter, Roboto, escudos como iniciales): cambiaron y se regeneraron **después de revisarlas lado a lado** 140 de las existentes (chips en píxeles enteros, barra inferior al 200 %, accesos del Inicio, barras a 1920 y en las pantallas de 720 px, filas con nombres en 3 renglones, Llaves, detalle, ficha, error del Inicio, prototipo de E1 al 200 %) y las 31 nuevas cambiaron respecto de su «antes». **Nuevas**: 33. Total: 202. «Antes» (código de E6) en `docs/evidence/e6_test_*` (incluye las 33 escenas nuevas generadas con E6), «después» en `e7_test_*`; comparación lado a lado en `docs/evidence/e7_comparacion.html`.
- **Web con escudos reales** (app grabada en Chrome headless por CDP, mismo guion con E6 y E7): Inicio, Equipos, Ajustes, Favoritos (vacío y con Boca), Fixture de Primera, Llaves de Primera y de la Copa Argentina, Tabla Anual, detalle de la serie con penales y ficha de Boca, a 360 / 411 / 768 / 800 / 1280 / 1920 en claro y oscuro, y al 200 % (tamaño de letra del navegador): `docs/evidence/e6_web_*` / `e7_web_*`.
- **Contra las anteriores a E1**: la comparación incluye los «antes» de E1 de los mismos encuadres (`e1_test_*`, `e1_web_*`) cuando existen.
- **Android** (APK release, datos en vivo, Motorola One Fusion, 411 dp, tema de la app «Oscuro»): Inicio (sin «Primera División» repetido), Inicio al 200 % («Competiciones» en un renglón), búsqueda al 200 % (superficie de grupo), Fixture y Calendario al 200 %, ficha de Boca con «Equipo» y, desplazada, con el nombre en la barra y «Gimnasia y / Esgrima de / Mendoza» entero (`docs/evidence/e7_android_motorola_*`, 7). En la primera pasada apareció un error real (el título no cambiaba al desplazar lejos): se corrigió, se agregó al test y se verificó en el teléfono. Al terminar: fuente del teléfono al 100 %, sin favoritos agregados, APK de E7 instalado.
- **Tablet física SKY PAD10MAX: no estaba conectada** (solo el Motorola y el Mate70Max, que no se usó). Siguen **pendientes en el dispositivo**: tablet vertical (800) y horizontal (1280, con el panel de 440) en Android. Las capturas automáticas a 800 y 1280 y las Web a 800 / 1280 / 1920 **no reemplazan** esa prueba.

### 26.8 Pendientes (requieren autorización o una fase posterior)
1. ~~**Carrera de sincronización** (26.5)~~: resuelta en la corrección técnica 1 (§27).
2. **Prueba en la tablet física** (vertical y horizontal, panel de detalle, 200 %).
3. **Versionado de `docs/`** (propuesta en el informe de la fase; `.gitignore` sin cambios).
4. Detalle de la actualización fallida por fecha y conteo de consultas del forzado (26.3): cambio funcional, no se hizo.
5. Observaciones menores: en partido único la tanda se escribe local-visitante («Avanza Boca Juniors (3-4 en penales)» con Boca de visitante) y en las series desde el que clasifica; unificarlo cambiaría textos ya aprobados. En un teléfono al 200 % las etiquetas de la barra inferior quedan cerca del tamaño normal (26.2). Logos de competiciones: fuera del hito.

## 27. Corrección técnica 1 — consultas duplicadas de rondas (solo datos)

- **Causa** (recorrido de 26.5, confirmado en el código): `syncRound` y `watchRound` leen la vigencia (`_metadata.get`, asíncrona) y recién después llaman a `SyncScheduler.run`, que une pedidos de la misma clave solo mientras el trabajo está en cola o en curso. Si otro trabajo de esa ronda termina en esa ventana (guarda la vigencia y sale de `_byKey`), la decisión «hay que pedir» quedó vieja y se crea un trabajo nuevo: la ronda se pide dos veces (final de la Sudamericana 2026, `4724:r200:s2026`, en `bracket_budget_test`). El test existente «dos pantallas pidiendo la misma ronda: una sola petición» tenía la misma ventana (falló una vez en esta tarea antes del arreglo).
- **Corrección** (`lib/features/matches/data/repositories/match_repository_impl.dart`): el trabajo encolado vuelve a leer la vigencia justo antes de pedir (`_refreshRoundIfNeeded`) y no pide si ya no hace falta, con la **misma regla** (`needsRefresh`). Si algún refresco forzado espera esa ronda (contador `_forcedWaiters`, también los que se suman a un trabajo ajeno no forzado), se evalúa con la regla del refresco manual (≥ 30 s desde lo guardado). Sin cambios en `SyncScheduler` (deduplicación, prioridades, cupo P2, pausa, cancelación) ni en el rate limiter.
- **Por qué no deja una ronda vieja como actualizada**: sin otro guardado en el medio, la segunda comprobación da lo mismo que la primera (el tiempo solo avanza: lo vencido sigue vencido, lo que admitía un refresco manual lo sigue admitiendo). Solo cambia si otro trabajo guardó la ronda después de la lectura, y entonces no se pide únicamente si lo guardado está vigente por su TTL (o, con un forzado esperando, dentro de los 30 s). Un guardado fallido no cambia la vigencia: se pide.
- `syncRound` sigue devolviendo `true` en ese caso (la ronda se actualizó desde su lectura, como hoy al sumarse a un trabajo ajeno); `watchRound` emite lo guardado por el otro trabajo.
- **Tests nuevos** (`test/features/matches/data/match_repository_impl_test.dart`, grupo «vigencia leída antes de que otro trabajo guarde la ronda», 4): el caso de `docs/evidence/e7_bracket_race_probe_test.dart.txt` para `syncRound` y para `watchRound` (1 pedido; **fallan con el código anterior**: 2 pedidos); un refresco forzado que se suma a ese trabajo en cola, pasado el intervalo manual, **sí pide** (falla si se ignora el forzado); una ronda vencida en cola sin otro guardado se pide al empezar el trabajo.
- **Validación**: `flutter analyze` sin issues; `flutter test` 1383 en verde (1379 + 4); los 12 archivos de presupuestos y sincronización (`bracket_budget`, `calendar_budget`, `continental_budget`, `standings_budget`, `live_refresh`, `sync_notice`, `sync_scheduler`, `home_request_budget`, `team_detail_sync`, `team_detail_continental`, `complete_rounds`, `match_repository_impl`; 112 tests) 20 veces, de a 2 corridas en paralelo: todas en verde. Ningún presupuesto cambió.
- **Efectos secundarios**: una lectura de sembast más por trabajo de ronda que se ejecuta. Un trabajo P2 en cola por mucho tiempo ya no pide si otra pantalla actualizó la ronda mientras esperaba (antes la pedía otra vez). La misma ventana existe en `getMatch` (`lookupevent`) y no se tocó (fuera del alcance).
