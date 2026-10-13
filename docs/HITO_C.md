# Plan Hito C — Más datos y mejoras de uso (Fases 11 a 19) · v3: tablas según el reglamento 2026

## Contexto
El MVP (Hitos A y B) y la Fase 10.1 están mergeados en `main`. El usuario pidió un plan nuevo, por pasos, para lo que se puede agregar.

Decisiones del 12/10/2026:
- Primero los datos; después las mejoras de uso diario.
- Entra todo, salvo las notificaciones.
- Se pueden sumar paquetes de pub.dev, con una alternativa para Web.
- El historial se baja solo cuando hace falta: P2 (`SyncPriority.team`, 10 por minuto, se puede cancelar y muestra el avance). No hay una P3.

**v2 y v3 (revisión del usuario):** se descarta la «tabla general no oficial». Las tablas siguen el **Reglamento Torneos Primera División 2026** ([PDF oficial AFA/LPF](https://assets1.afa.com.ar/2026/BOLETINES/Boletin-Resoluciones-6818---Complementario-01---Reglamento-Torneos-LPF-Primera-2026.pdf)):
- **Tabla General Anual 2026**.
- **Tablas por zona**, una por torneo.
- Primera Nacional se investiga aparte.
- El dominio admite clasificaciones distintas según la competición y la temporada.

**Aprobado por el usuario (v3 + ajuste de la Fase 12).** Se empieza por la Fase 11. Las tareas de una misma fase se hacen seguidas; al cerrar cada fase se presentan resultados, verificaciones y problemas, y se espera la aprobación. Sin commits ni PRs: los hace el usuario.

Forma de trabajo de siempre: cada fase cierra con `flutter analyze` sin issues, los tests verdes, la prueba en la tablet SKY y en Chrome, los docs actualizados y la aprobación del usuario. El commit y el PR los hace el usuario.

**Lo primero al aprobar:** reemplazar en `docs/PLAN.md` las líneas «10.2 / 10.3» por este plan, y registrar en `docs/DECISIONS.md` las reglas de abajo con su cita.

## Reglas confirmadas (reglamento 2026, leído el 12/10/2026)

**Formato** (art. 8.1 y 14.1)
- Dos zonas, «A» y «B», de 15 equipos cada una, todos contra todos a una rueda.
- Cada fecha tiene 7 partidos por zona, más un «clásico» o «interzonal» entre los dos equipos que quedan libres.
- Hay además una fecha interzonal: 16 fechas en total.
- Cada equipo juega 16 partidos regulares por torneo: 14 de zona y 2 interzonales. En el año son 32.
- Art. 14.1.1: el Clausura repite el programa del Apertura con la localía invertida, así que **las zonas son las mismas**. Se verifica también contra los datos (T11.5).

**Tabla de cada zona** (art. 9 y 15)
- Puntos acumulados en las 16 fechas, interzonales incluidos: 3 por ganar, 1 por empatar, 0 por perder.

**Desempates de zona** (art. 10 y 16)
1. Diferencia de gol.
2. Goles a favor.
3. Partidos entre los empatados «durante el certamen»: puntos, después diferencia de gol, después goles a favor. Se repite cuantas veces haga falta.
4. Tabla de Fair Play 2026.
5. Sorteo.

**Tabla General Anual** (art. 24.1 y 24.2)
- Suma los puntos de la Primera Fase de Zonas del Apertura y del Clausura.
- El primero es «Campeón de Liga 2026».
- **Se excluyen** octavos, cuartos, semifinales y final.

**Desempates de la tabla anual** (art. 24.3)
1. Diferencia de gol.
2. Goles a favor.
3. Fair Play 2026.
4. Sorteo.

**No hay enfrentamiento directo** en la tabla anual.

**Descenso** (art. 24.4 y 26.2)
- Si hay igualdad en puestos de descenso, se juegan partidos de desempate (art. 111 del Reglamento General).
- La app **no define descensos**: lo aclara en la tabla y no marca puestos de descenso.

**Qué puede calcular la app**
- Con datos de la API: puntos, diferencia de gol, goles a favor y partidos entre sí.
- **No** puede calcular Fair Play (la API no informa tarjetas) ni el sorteo. Los equipos que siguen empatados al llegar a esos criterios se muestran como **«posición compartida»**, con la nota «se define por Fair Play o sorteo (no disponible)».
- Las tablas nunca se presentan como oficiales cuando falta un criterio.

**Referencia para contrastar:** la [Tabla General de la LPF](https://www.ligaprofesional.ar/torneo-apertura-2026/). Se usa a mano al validar, nunca dentro de la app.

**Primera Nacional 2026**, según la prensa ([Cadena 3](https://www.cadena3.com/noticia/futbol/se-sortearon-las-zonas-y-el-fixture-de-la-primera-nacional-2026_501021), [442](https://442.perfil.com/noticias/futbol/zonas-y-formato-de-la-primera-nacional-2026.phtml)):
- Dos zonas de 18 equipos, con «34 fechas» de ida y vuelta.
- Final entre los primeros de cada zona y un Reducido.
- **Conflicto:** la API tiene 36 rondas (V7). Queda para la V14.

---

## Fase 11 — Validaciones post-MVP
- **T11.1** Competiciones 5215, 5523 y 5524 (V8):
  - consultar `lookupleague`, `search_all_leagues?c=Argentina`, los punteros y `eventsround`;
  - relevar el formato de temporada, los códigos de ronda, los partidos por ronda y las zonas;
  - revisar también 5428 y 4724.
- **T11.2** D8 (V9): consultar `eventsnext` y `eventslast?id=` para Boca, River y un equipo de Nacional.
- **T11.3** Grabaciones:
  - volver a grabar las rondas 1–16 de 2026 (Clausura en curso);
  - grabar Nacional 2026, rondas 2–32;
  - grabar `lookuptable` de 4406 y 4616 (V10).
- **T11.4** Paquetes (V11): probar `share_plus`, `add_2_calendar` o un `.ics` en Web, y `cached_network_image` en Android, desde la pantalla de diagnóstico.
- **T11.5** Zonas de Primera 2026 con `idTeam` (V12):
  - Pasar la lista de la AFA a `idTeam` usando los partidos grabados. Hay nombres para desambiguar: Gimnasia LP, Gimnasia Mza., Estudiantes LP, Estudiantes RC, Independiente Rivadavia, Instituto, Central Córdoba.
  - Verificar contra los datos que, en el Apertura y en el Clausura, cada equipo:
    - enfrenta a los 14 de su zona;
    - juega 2 interzonales;
    - tiene 16 partidos regulares.
  - El resultado es la lista con fuente y fecha de consulta, aprobada por vos.
- **T11.6** Reglamento: ya leído. Se registra en DECISIONS con cita y link: art. 8.1, 9, 10, 14.1, 15, 16, 24 y 26. Se aclara que el art. 24.3 no incluye enfrentamiento directo.
- **T11.7** Formato de Primera Nacional 2026 (V14):
  - fuente oficial (reglamento de la Primera Nacional 2026) más los datos de las rondas 1–37;
  - zonas con `idTeam`, explicación de las 36 rondas, tablas que existen y desempates.
  - Si los datos no cierran, Nacional queda sin tablas.
- **Aceptación:** V8–V14 documentados y fixtures grabados en el README. Zonas y formato de Nacional aprobados por vos antes de las Fases 13 y 14.

## Fase 12 — Historial a pedido, conservación y limpieza manual
**Estado:** ✅ completada el 12/10/2026 (ver `docs/PLAN.md`). Esperando aprobación para la Fase 13.

Ajuste aprobado por el usuario: **no se borran temporadas automáticamente**.
- `SyncProgress` en `core/sync/` (sale de `TeamSyncProgress`).
- `MatchRepository` suma `roundCacheState` (falta / vigente / vencida) y `storedSeason`.
- `CompleteRounds`: mismo patrón que `WatchTeamDetail`, prioridad P2, cancelable, emite el avance.
  - **Nunca vuelve a pedir lo guardado y vigente.** Las rondas cerradas tienen TTL de 30 días, y al vencer solo se piden si tienen partidos jugados sin resultado.
  - Para temporadas anteriores ya terminadas, una ronda guardada y completa **no se vuelve a pedir aunque haya vencido** (estado «histórica»). Solo se refresca con un refresco manual.
- **Conservación:** los partidos históricos quedan en la base local. No hay purga automática por temporada.
- **Limpieza manual** en `/ajustes` → «Datos guardados» (la pantalla se crea acá y la Fase 16 le suma el tema):
  - lista de temporadas guardadas por competición, con la cantidad de partidos;
  - el usuario elige cuáles borrar, con confirmación;
  - se borran esos partidos y sus claves `round:*` en `query_meta`;
  - nunca se tocan los favoritos;
  - la temporada actual no se puede borrar.
- **Limpieza automática segura**: solo partidos `removed` que estén **verificados** (la API confirmó que ya no existen) y que lleven más de 30 días así. Hoy la verificación con `lookupevent` no existe (estaba postergada), así que **no se borra nada automáticamente** hasta implementarla. Su implementación con presupuesto acotado queda dentro de esta fase como T12.x opcional, o pospuesta y documentada.
- Sección «Historial» en `/diagnostico`.
- **Peticiones:** en frío, 16 para Primera 2026 completa, 36 para Nacional y 6 para la Copa. En caliente, y en temporadas anteriores ya guardadas, 0.

## Fase 13 — Tablas de Primera 2026: Tabla Anual y zonas por torneo
**Estado:** ✅ completada el 12/10/2026 (ver `docs/PLAN.md`). Aprobada.

- **T13.1 Dominio común**, Dart puro, sin reglas de torneo (`competitions/domain/standings/`):
  - `TeamStats` (PJ, PG, PE, PP, GF, GC, DG, Pts) y `StatsAccumulator`: suma **una vez** cada partido terminado a cada uno de sus dos equipos.
  - `TieBreakCriterion` sealed:
    - `goalDifference`, `goalsFor`;
    - `headToHead`: mini tabla de puntos, diferencia de gol y goles a favor entre los empatados, recursiva;
    - `fairPlay` y `drawOfLots`, marcados como **no calculables**.
  - `TieBreaker`: aplica la lista que le pasan, siempre después de los puntos. Al llegar a un criterio no calculable con equipos todavía empatados, los marca como «posición compartida».
  - `StandingsTable`:
    - título, tipo y filas con posición o marca de posición compartida;
    - **cobertura**: «12 de 16 fechas consultadas», partidos terminados sobre programados, y la lista de partidos pendientes, postergados o excluidos con el motivo;
    - nota del reglamento con el artículo citado.
- **T13.2 Formato por competición y temporada** en el catálogo: `StandingsFormat` sealed, junto a `CompetitionRules`.
  - `LeagueZonesWithAnnual` (Primera 2026):
    - `zones`: torneo → zona → `idTeam`;
    - `zoneTieBreak` = [DG, GF, headToHead, fairPlay, sorteo] (art. 10 y 16);
    - `annualTieBreak` = [DG, GF, fairPlay, sorteo] (art. 24.3);
    - `regularRounds` = 1–16 (sin la ronda 0 de eliminatorias, ni los octavos que van dentro de la ronda 16);
    - cita del reglamento.
  - La Copa usa `NoStandings`. Nacional y las competiciones nuevas no tienen formato hasta validarlas.
- **T13.3 Constructores**, cada uno con su regla:
  - **Partidos que cuentan:** de la temporada, en etapa regular (`StageKind.regular`) y con el torneo resuelto por `PhaseResolver`. Los indeterminados se excluyen y figuran en la cobertura. Solo cuentan los terminados. Cada partido entra una sola vez, por `idEvent`, con `MatchGrouping.dedupe`.
  - `ZoneTableBuilder(torneo, zona)`:
    - filas: los 15 de la zona;
    - suma los partidos regulares **de ese torneo** de cada equipo, **interzonales incluidos**;
    - Apertura y Clausura nunca se mezclan;
    - desempate de zona;
    - para el enfrentamiento directo usa solo partidos de ese certamen.
  - `AnnualTableBuilder`:
    - filas: los 30;
    - **calculada directamente** de los partidos regulares de los dos torneos, cada uno contado una vez: no suma posiciones ni tablas armadas y no repite interzonales;
    - **sin octavos, cuartos, semis ni final**;
    - desempate del art. 24.3, **sin enfrentamiento directo**;
    - disponible antes de que empiece el Clausura, con lo acumulado hasta ese momento;
    - nota: «Descensos: ante igualdad se juegan partidos de desempate (art. 24.4); la app no los define».
  - **Validador de zonas** en tiempo de ejecución: un equipo sin zona, o un partido de zona entre equipos de zonas distintas fuera de los interzonales esperados, desactiva las tablas por zona («zonas no verificadas»). La tabla anual no depende de las zonas y sigue disponible.
- **T13.4** `WatchStandings(competición, temporada)`: lo guardado + `CompleteRounds` de las rondas regulares 1–16. Recalcula a medida que llegan rondas y emite las tablas, la cobertura y el avance.
- **T13.5 Presentación:**
  - `StandingsBloc` (`restartable`, pausa con `TickerMode`, cancela al cerrar).
  - Vista «Fixture | Tabla» en `CompetitionsPage`.
  - Selector **Tabla Anual 2026 · Apertura (Zona A / Zona B) · Clausura (Zona A / Zona B)**, en la URL (`?vista=tabla&tabla=anual|apertura-a|apertura-b|clausura-a|clausura-b`).
  - Avance: «Fechas consultadas 12 de 16».
  - Cobertura y nota del reglamento siempre visibles.
  - Columnas según `Breakpoints`.
  - Tocar un equipo abre su ficha.
  - `showAlreadyUpToDate` si no hubo nada que consultar.
- **Aceptación:**
  - Tabla Anual con 30 filas.
  - Por equipo: PJ = 16 del Apertura + los jugados del Clausura.
  - Suma de PJ = 2 × partidos regulares terminados.
  - Ningún partido de la ronda 0 ni octavos de la ronda 16.
  - La tabla anual de cada equipo es igual a la suma de sus filas de zona del Apertura y del Clausura.
  - Zonas del Apertura completas: 15 filas, 16 PJ por equipo.
  - Clausura parcial, con su cobertura.
  - Puntos contrastados a mano con la Tabla General de la LPF y con `lookuptable`, con la evidencia en `docs/evidence/f13_*`.
  - Sin desbordes a 360, 768, 1280 y 1920 px, ni con texto al 200 %.
- **Tests:**
  - **Constructores con JSON reales** (rondas 1–16 de 2026 y de 2025):
    - la tabla anual es igual a la suma de zona Apertura + zona Clausura para cada equipo;
    - ningún interzonal se cuenta dos veces: el total de PJ es par e igual a 2 × partidos;
    - la ronda 0 y los octavos quedan excluidos;
    - los indeterminados aparecen en la cobertura.
  - **`TieBreaker`** con estadísticas armadas en el test, solo para probar la regla y sin presentarlas como datos reales:
    - DG > GF;
    - enfrentamiento directo recursivo con 2 y con 3 empatados;
    - la tabla anual **no** usa el enfrentamiento directo;
    - posición compartida cuando solo quedan Fair Play o sorteo.
  - Casos reales de empate de los fixtures, si los hay.
  - **Validador de zonas** con todos los partidos grabados.
  - `bloc_test`; presupuesto de consultas en frío y en caliente; layout y accesibilidad.

## Fase 14 — Tablas de Primera Nacional (formato propio, según V14)
**Estado:** ✅ completada el 12/10/2026 (ver `docs/PLAN.md`); V15 resuelta con el texto oficial del art. 112. Aprobada.

- Formato propio en el catálogo (p. ej. `LeagueZones`, dos zonas de 18, con los interzonales que haya resuelto la V14) y sus desempates. **No** se reutiliza Apertura / Clausura / Anual.
- Se reutilizan `TeamStats`, `TieBreaker` y `StandingsTable`. Selector «Zona A · Zona B» con la cobertura de las 36 rondas.
- Final y Reducido: Fase 19.
- Si la V14 no cierra, la fase queda en espera sin bloquear las siguientes.

## Fase 15 — Más competiciones y otras competiciones del equipo (D8)
**Estado:** ✅ completada el 12/10/2026 (ver `docs/PLAN.md`): B Metro y Primera C sin Inicio, índice ni tabla; Boca en frío = 27. Esperando aprobación para la Fase 16.

- Marcas `showInHome` e `inTeamIndex` en `CompetitionDefinition`: el Inicio sigue con 12 consultas o menos.
- Entradas nuevas validadas (V8) con `NoStandings` hasta investigar su formato.
- D8: `getTeamPointers` (2 peticiones, TTL 30 min) y la sección «Otras competiciones (información parcial)» en la ficha. Ficha de Boca en frío: 27 peticiones.

## Fase 16 — Ajustes, tema, aviso de espera y escudos en disco
- Store `settings` + `SettingsRepository` + `SettingsBloc` global; tema sistema / claro / oscuro; pantalla `/ajustes`.
- `RateLimitStatus` también avisa las esperas de 3 s o más por el tope propio, en `RateLimitNotice`.
- `BadgeImageResolver`: Android usa `CachedNetworkImageProvider`; Web queda igual.

## Fase 17 — Compartir, agregar al calendario y auto-refresco en vivo
- **Compartir:** texto con las reglas de horario, vía `share_plus`. En Web, si no se puede, se copia al portapapeles.
- **Calendario:** `IcsBuilder` en Dart puro. Los partidos con hora sin confirmar (`tentative`) se agregan como evento de día completo. Android usa `add_2_calendar`; Web descarga el `.ics`.
- **En vivo (D11):**
  - `MatchGrouping.isLive` compartido con `RoundCachePolicy`;
  - un `Ticker` cada 2 min, solo si la pantalla está visible y hay partidos en vivo;
  - respeta el TTL `live`.

## Fase 18 — Calendario mensual
`MonthCalendar` (lo guardado, agrupado por día argentino) + `WatchCompetitionCalendar` (que usa `CompleteRounds` solo si se pide). Vista «Calendario» en `CompetitionsPage`.

## Fase 19 (nov–dic 2026)
- Nacional: Reducido y final por el ascenso.
- Playoffs del Clausura (V3), final de la Copa 2026, «Avanza X» tras penales, cuadro de llaves.
- Mantenimiento: reglamento y zonas de 2027 en el catálogo.

---

## Orden definitivo
**11** Validaciones (incluye zonas con `idTeam`, el registro del reglamento y el formato de Nacional) → **12** Historial, conservación y limpieza manual → **13** Tabla Anual y zonas de Primera → **14** Tablas de Nacional → **15** Competiciones nuevas y D8 → **16** Ajustes, tema, aviso y escudos → **17** Compartir, calendario y en vivo → **18** Calendario mensual → **19** Fin de temporada.

Las zonas con `idTeam` pasan de la ex Fase 15 a la Fase 11, y su uso a la Fase 13. Las Fases 14 y 15 pueden esperar sus validaciones sin frenar las Fases 16–18.

## Archivos clave
- `lib/features/competitions/domain/catalog/competition_catalog.dart`: `StandingsFormat`, zonas, desempates con cita, marcas.
- Nuevo `lib/features/competitions/domain/standings/`: `TeamStats`, `StatsAccumulator`, `TieBreakCriterion`, `TieBreaker`, `StandingsTable`, `ZoneTableBuilder`, `AnnualTableBuilder`, validador de zonas, `WatchStandings`.
- `lib/features/matches/` (repositorio y fuente local): `roundCacheState`, `storedSeason`, borrado manual por temporada.
- `lib/features/teams/domain/usecases/watch_team_detail.dart`: patrón para `CompleteRounds`. `SyncProgress` pasa a `lib/core/sync/`.
- `lib/features/competitions/presentation/pages/competitions_page.dart` y `routing/fixture_route.dart`: vistas Tabla y Calendario.
- Se reutilizan `PhaseResolver`, `RoundNavigator`, `MatchGrouping` (`dedupe`, `isPlayed`), `StoredMatchLabeler`, `Breakpoints`, `showAlreadyUpToDate` y `pumpApp`.

## Verificación
- **Tests:**
  - JSON reales de `test/fixtures/api/`, grabados de la API y nunca escritos a mano.
  - La regla de desempate se prueba con estadísticas armadas en el test, rotuladas como tales.
  - `FakeClock`; presupuestos de consultas con `MockClient`; `bloc_test`.
  - `pumpApp` a 360, 768, 1280 y 1920 px, con las pautas de accesibilidad y texto al 200 %.
- **Validación externa manual:** los puntos de la Tabla Anual y de las zonas se contrastan con la Tabla General de la LPF y con `lookuptable`. Las diferencias se explican (fecha de corte, partidos pendientes).
- **Dispositivos:** APK release en la tablet (vertical y horizontal) y Web release en el Chrome de la tablet; peticiones contadas con `logcat`.
- **Docs:**
  - PLAN;
  - API (V8–V14);
  - DECISIONS: reglamento 2026 con los artículos citados, zonas con su fuente, y la regla de que la app no define descensos;
  - DATA_STRATEGY, ARCHITECTURE;
  - CLAUDE.md: actualizar zonas y reglamento cada temporada; tabla anual sin enfrentamiento directo.
