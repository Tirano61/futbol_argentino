# Decisiones arquitectónicas

> Generado desde el Plan Maestro v2 (aprobado el 11/10/2026). Las referencias «§N» apuntan a secciones de [PLAN.md](PLAN.md).

## 11. Decisiones

**Aprobadas**: DDD por features · BLoC sin Cubit · go_router (D3) · sembast/sembast_web (D1) · catálogo de competiciones · carga incremental por rondas.

| # | Decisión | Estado / recomendación |
|---|---|---|
| D2 | DI | Composition root manual + `RepositoryProvider` (sin `get_it`) — recomendada |
| D4 | Zona horaria | UTC−3 fijo encapsulado — recomendada |
| D5 | Horarios ambiguos | **Ajustada**: regla conservadora confirmed/tentative/unknown; `00:00` sin corroboración → «Horario por confirmar» |
| D6 | Fases de Primera | **Ajustada**: catálogo por temporada desde datos reales; inferencia solo con evidencia limpia; si no, `undetermined` |
| D7 | Zonas de Nacional | (a) sin zonas en MVP — recomendada · (b) mapeo manual post-MVP |
| D8 | Otras competiciones del equipo | post-MVP como «información parcial» (implementada en la Fase 15, ver D19) |
| D9 | Sincronización | **Ajustada**: `SyncScheduler` incremental, priorizado, cancelable, reanudable, con cupos |
| D10 | Temporadas | actual y anterior (`YYYY`) |
| D11 | En juego | estado + «actualizado hh:mm», refresco manual; auto-refresco post-MVP |
| D12 | Escudos en Web | ✅ **Cerrada tras T0.2**: `Image.network(..., webHtmlElementStrategy: WebHtmlElementStrategy.fallback)` + placeholder con iniciales si falla la red. Sin proxy. |
| D13 | `matches` como núcleo; fixtures dentro de `competitions` | recomendada |
| D14 | Datos y caché antes que pantallas; Copa en el fixture desde el inicio | recomendada |

---


### Hito C (12/10/2026)

| # | Decisión | Estado |
|---|---|---|
| D15 | Tablas de Primera 2026 | **Aprobada**: según el [Reglamento Torneos Primera División 2026](https://assets1.afa.com.ar/2026/BOLETINES/Boletin-Resoluciones-6818---Complementario-01---Reglamento-Torneos-LPF-Primera-2026.pdf) (ver abajo). Sin tabla «general no oficial». |
| D16 | Historial | **Aprobada**: a pedido (P2, cancelable, con avance), sin P3; los históricos se conservan; borrado solo manual por temporada; limpieza automática solo de `removed` verificados. |
| D17 | Notificaciones | Fuera del alcance (sin backend no se pueden enviar con la app cerrada). |
| D19 | Más competiciones y otras competiciones del equipo (D8) | **Implementada (Fase 15)**: Primera B Metropolitana y Primera C en el catálogo, fuera del Inicio y del índice de equipos y sin tabla; Federal A afuera. D8: próximo y último partido del equipo (`eventsnext`/`eventslast`) en la ficha, como «información parcial», sin guardarlos con los partidos. |
| D18 | Tablas de Primera Nacional 2026 | **Aprobado el formato (V14) y verificado el desempate (V15)**: una tabla por zona (A y B, 18 equipos) con los interzonales sumados; desempate del art. 112 del Reglamento General, puntos 1 a 3 (sin Fair Play ni sorteo); la app no define descensos (art. 111). Sin tabla anual ni Apertura/Clausura. |

**Reglamento 2026 (leído el 12/10/2026)**
- Formato (art. 8.1 y 14.1): zonas «A» y «B» de 15, una rueda; en cada fecha 7 partidos por zona más un «clásico»/«interzonal» entre los dos libres; además una fecha interzonal. 16 fechas = 14 partidos de zona + 2 interzonales por equipo. Art. 14.1.1: el Clausura repite el programa del Apertura con la localía invertida (mismas zonas).
- Tabla de cada zona (art. 9 y 15): puntos de las 16 fechas (3/1/0), interzonales incluidos.
- Desempate de zona (art. 10 y 16): a) diferencia de goles; b) goles a favor; c) partidos entre los empatados durante el certamen (puntos, luego diferencia de goles, luego goles a favor; se repite cuantas veces sea necesario); d) Tabla General de Fair Play 2026; e) sorteo.
- Tabla General de Posiciones 2026 (art. 24.1–24.2): puntos de la Primera Fase de Zonas del Apertura más los del Clausura; el primero es «Campeón de Liga 2026». Excluye octavos, cuartos, semifinales y final.
- Desempate de la Tabla General (art. 24.3): a) diferencia de goles; b) goles a favor; c) Fair Play 2026; d) sorteo. **Sin enfrentamiento directo.**
- Descenso (art. 24.4 y 26.2): ante igualdad, partido/s de desempate (art. 111 del Reglamento General de AFA). La app no define descensos.
- La app calcula puntos, diferencia de goles, goles a favor y enfrentamiento directo; Fair Play y sorteo no se pueden calcular (la API no informa tarjetas): los equipos que siguen empatados se muestran como «posición compartida».
- Contraste manual: [Tabla General de la LPF](https://www.ligaprofesional.ar/torneo-apertura-2026/).
- Zonas con `idTeam` (V12) y formato de Primera Nacional (V14): ver `docs/API.md` («Validaciones post-MVP — Fase 11»). Requieren tu aprobación antes de las Fases 13 y 14.

**Primera Nacional 2026** ([Boletín Especial 6823](https://assets1.afa.com.ar/2026/Lau/Boletin-Especial-6823---Reglamento-del-Campeonato-de-Primera-Nacional-2026.pdf), 30/01/2026)
- Punto 2: zonas «A» y «B» de 18, dos ruedas, más una fecha interzonal de ida y vuelta. Final por el primer ascenso entre los primeros de cada zona; Reducido por el segundo.
- Punto 3: Tabla Final de Posiciones por acumulación de puntos (3/1/0). Los interzonales suman (V14).
- Punto 5: para empates en puntos en cualquier posición de cada zona, **incluido el primer puesto**, el art. 112 del Reglamento General (puntos 1 a 3); para los cuatro descensos, partido/s de desempate (art. 111).
- [Reglamento General de AFA](https://www.afa.com.ar/upload/torneo/Reglamento_General_AFA.pdf), art. 112 (leído el 12/10/2026, V15): 1) mayor diferencia de goles; 2) más goles a favor; 3) considerando solo los partidos del certamen entre los empatados, más puntos y, si siguen iguales, mayor diferencia de goles y más goles a favor; se repite cuantas veces sea necesario. Art. 113: durante el certamen se aplican los mismos puntos. No hay un cuarto criterio: si siguen empatados, la app muestra «posición compartida: el reglamento no define más criterios».
- Modelo propio: no se reutiliza Apertura/Clausura/Anual. No hay tabla general de la temporada salvo la que se arma para el Reducido (Fase 19).

## Alternativas evaluadas

| # | Elegida | Alternativas descartadas y motivo |
|---|---|---|
| D1 Persistencia | `sembast` + `sembast_web` | `hive_ce`: clave-valor, filtrado manual. `drift`: SQL potente pero en Web requiere `sqlite3.wasm` + worker. `shared_preferences`: sin consultas, límite ~5 MB en Web. `isar`: mantenimiento incierto. |
| D2 DI | Composition root manual + `RepositoryProvider` | `get_it`: dependencia extra y service locator global; innecesario para este tamaño. |
| D3 Navegación | `go_router` | `Navigator` 2.0 manual: mucho código para URLs en Web. `auto_route`: requiere generación de código. |
| D4 Zona horaria | UTC−3 fijo encapsulado | Paquete `timezone`: agrega la base IANA (~MB) para una zona sin horario de verano desde 2009. Migrar = cambiar un archivo. |
| D5 Horarios `00:00` | Regla conservadora (confirmed/tentative/unknown) | Mostrar siempre 21:00: podría mostrar horas falsas. Ocultar siempre: pierde horas reales corroboradas. |
| D6 Fases de Primera | Catálogo por temporada + inferencia solo con evidencia + `undetermined` | División fija por meses: ubica mal partidos reprogramados y no distingue octavos de la fecha 16. |
| D7 Zonas Nacional | Sin zonas en MVP | Inferir zonas por cruces: los interzonales lo rompen. Mapeo manual: posible post-MVP con tu aprobación. |
| D9 Sincronización | `SyncScheduler` incremental y cancelable | Descargar la temporada completa al abrir: bloquea, consume el cupo de 30/min. |
| D12 Escudos Web | Fallback `<img>` (validado en T0.2) | Proxy propio (Cloudflare Worker): servicio extra, requiere aprobación explícita. |

## Registro de cambios
- 12/10/2026 — Fase 15: marcas `showInHome`/`inTeamIndex` en el catálogo en lugar de listas aparte: el Inicio y el índice filtran el catálogo que reciben. B Metro y Primera C entran sin las dos marcas (Inicio ≤ 12 y bootstrap del índice = 3 se mantienen) y sin tabla (`NoStandings`) hasta investigar su reglamento. B Metro 2026 = 42 fechas (22 equipos a dos ruedas; la 43 vuelve vacía); Primera C sin cantidad (32 fechas con 28 equipos no cierra con un todos contra todos); las temporadas 2025 de las dos quedan sin fechas. El selector de competición pasa de `SegmentedButton` a chips en una fila con desplazamiento (5 no entran a 360 px; en dos renglones desborda con texto al 200 %). D8: los punteros del equipo van a un store propio (`team_pointers`), no a `events`: así no aparecen competiciones ajenas en fixtures, índice, «Tus equipos» ni «Datos guardados»; la sección solo muestra los de competiciones fuera del catálogo (los demás ya están en la ficha), agrupados por día, sin detalle (el partido no está guardado). Si los punteros fallan sin nada guardado, la ficha sigue sin la sección (información parcial). Boca en frío pasa de 25 a 27 peticiones.
- 12/10/2026 — Fase 14: formato `LeagueZones` propio para Nacional (no reutiliza Apertura/Clausura/Anual); `LeagueZonesWithAnnual` y `LeagueZones` comparten `ZonedStandingsFormat` para el validador y `WatchStandings`. El cálculo de una zona es uno solo para los dos formatos. Si las zonas de Nacional no se verifican no queda ninguna tabla (no hay anual): la vista lo dice («Zonas no verificadas») en lugar de la tabla. Sin `tabla` en la URL se muestra la primera tabla de la competición, y al cambiar de competición se vuelve a la primera (las claves son de cada una). La tabla puede volver a pedir una fecha con partidos en juego si su vigencia corta venció mientras esperaba su turno (no es una fecha vigente). `TeamBadge` pone una clave por URL a la imagen: en Web, con el `<img>` del modo fallback, una imagen montada que cambia de URL seguía mostrando la anterior (se vio en la tabla al reordenarse).
- 12/10/2026 — Fase 13: `StandingsFormat` por competición y temporada en el catálogo (Primera 2026: `LeagueZonesWithAnnual`; el resto `NoStandings`). La tabla anual se calcula directo de los partidos (no sumando tablas) y no usa enfrentamiento directo (art. 24.3). Empates que llegan a Fair Play o sorteo = posición compartida (mismo número, «*» y nota). Las tablas siempre dicen «Calculada por la app… no es la tabla oficial». Las tablas por zona se desactivan si el validador encuentra un equipo sin zona o cruces de más; la anual sigue. «Fixture | Tabla» en la misma pantalla (no una sección nueva); tocar un equipo de la tabla abre su ficha en «Equipos» (como «Tus equipos» del Inicio). El refresco manual de la tabla fuerza con P0 solo las fechas con partidos sin terminar de ayer y hoy. Contraste: Apertura con `lookuptable` y Clausura (fecha 10) con prensa; la anual oficial queda para contrastar a mano.
- 12/10/2026 — Fase 12: zonas de Primera 2026 (V12) y zonas y formato de Nacional 2026 (V14) aprobados por el usuario. `CompleteRounds` va en `competitions` (necesita el catálogo y `RoundNavigator`), no en `matches`. «Primera 2026 completa» son 17 rondas (fechas 1–16 + ronda 0 de eliminatorias del Apertura), no 16: las tablas (Fase 13) pedirán solo las 1–16. Ronda «cerrada» = clase `closed` + respuesta completa + todo con estado final y los terminados con resultado; «histórica» = temporada anterior al año argentino + respuesta completa + todo final (un postergado cuenta como final). El refresco manual (`forceRefresh`) pide las vencidas cerradas o históricas, nunca las vigentes. Temporada «actual» para el borrado = año argentino (o posterior); la regla está en el dominio. El borrado quita primero `query_meta` y después los partidos. La verificación con `lookupevent` y la limpieza automática de `removed` quedan **pospuestas** (no hay P3; hoy ningún partido llega a `removed`). Ajustes se abre desde un engranaje en el Inicio (no es una 5.ª sección).
- 12/10/2026 — Fase 11: V8–V14 resueltos con datos reales; V15 (art. 112 del R.G.) pendiente. `add_2_calendar` fijado en 3.0.1 (la 3.1.x rompe el build con el AGP actual). `cached_network_image` solo en Android (en Web falla por CORS). Las instantáneas de fixtures van en carpeta aparte para no pisar las que usan los tests. Federal A no entra al catálogo sin un relevamiento propio (etapas mezcladas en la numeración).
- 12/10/2026 — Hito C v3 aprobado: reemplaza las etapas 10.2/10.3 por las Fases 11–19; D15 (tablas según el reglamento 2026: anual y zonas por torneo), D16 (historial a pedido, conservación, borrado manual), D17 (notificaciones fuera). Se descartó la «tabla general no oficial» y la purga automática de temporadas.
- 12/10/2026 — Fase 10.1: la Fase 10 se divide en etapas (10.1 pendientes, 10.2 uso, 10.3 datos; lo que depende de datos de nov–dic, cuando existan); notificaciones fuera. La URL del fixture se repone escuchando al router en vez de llevar la etapa a la ubicación del router (eso recrearía la pantalla). La ficha se pausa por visibilidad (`TickerMode`) y no al cambiar de ruta: la sección queda viva y retoma donde estaba. `syncRound` devuelve si consultó la red (antes `void`).
- 12/10/2026 — Fase 9: los anchos se deciden por la ventana (`Breakpoints`), no por el contenido; panel de detalle solo en el fixture (como dice el plan), con la selección como estado local; buscador de la barra como campo que abre `/equipos?q=` (sin sugerencias en la barra) y ubicado en `app/shell` para evitar el ciclo `teams ↔ favorites`; el Inicio espera a «Tus equipos» en vez de reservarle lugar; el aviso de 429 es global (envuelve la app) con un `RateLimitStatus` de `core` en lugar de pasar por los repositorios; «Ya está actualizado» se resuelve en presentación comparando horas de descarga (sin cambiar los estados de los BLoC).
- 12/10/2026 — Fase 8: `FavoritesRepository` devuelve listas (no `DataResult`: datos solo locales, sin vigencia ni errores de red); `FavoritesBloc` global con la suscripción y los toques en handlers separados; «Tus equipos» con su propio `HomeFavoritesBloc` y un stream local reactivo (`watchStoredTeamsMatches`) en lugar de sumar consultas al Inicio; la ficha también vive en `/favoritos/:teamId`; `teams → favorites` (solo la estrella, en presentación); la regla «disputado» y el etiquetado de partidos guardados pasan a servicios compartidos (`MatchGrouping.isPlayed`, `StoredMatchLabeler`).
- 12/10/2026 — Fase 7: `teams` depende de `competitions` y `matches` (la ficha necesita fases y etapas); el índice de equipos se deriva de los partidos guardados (sin store propio que mantener); las competiciones del equipo salen de los partidos de la temporada (no de `idLeague…` de `lookupteam`); la ficha sincroniza de a una ronda P2 y se detiene ante el primer error; el refresco manual de la ficha fuerza solo las rondas cercanas; la pausa en segundo plano afecta solo a P2 (P0/P1 son de la pantalla visible).
- 11/10/2026 — Fase 6: el Inicio carga la ronda del último partido + la etapa siguiente (no «actual/anterior»: con la fecha en curso ambas coinciden y se perdía la próxima fecha); `watchRound`/`getSchedulePointers` reciben prioridad (P1 Inicio, P0 refresco manual); feature `home` con `GetHomeFeed` como stream por competición.
- 11/10/2026 — Fase 5: feature `match_detail` (compone `competitions` y `matches`) en lugar de ubicar el detalle en `matches`; se agrega `url_launcher` para el video; `push` refleja la URL en Web.
- 11/10/2026 — Fase 4: `ScoreBox` y `KickoffText` integrados en `MatchCard`; rutas de competiciones hermanas; timeout de 5 s al abrir la base local; catálogo 2025 (Nacional 34 fechas; Copa: 200 = Final verificado); se descartó el riesgo de mojibake (error de inspección).
- 11/10/2026 — Fase 3: un partido sin cerrar de los últimos 2 días mantiene la ronda en TTL «hoy» (10 min); verificación de `orphaned` con `lookupevent` postergada a P3 (post-MVP), solo se registra en el log; si la base local no abre, se usa memoria.
- 11/10/2026 — Fase 2: `Match` no guarda la fase (la calcula `PhaseResolver`) para respetar la dirección de dependencias; sin caso de uso `GetMatchDetail` (sería un pasamanos); Clausura 2026 cargado «en curso» (sin fin ni eliminatorias hasta tener datos); duplicados de equipo en una fase → ambos `undetermined`; faltantes en respuestas parciales se verifican si no se ven hace > 24 h.
- 11/10/2026 — Fase 1: URLs Web con `#` (estrategia por defecto) hasta definir el hosting; `Clock` se creó en T1.2 (lo necesitaba el `RateLimiter`) en lugar de T1.3.
- 11/10/2026 — D12 cerrada con la evidencia de T0.2 (`docs/evidence/`).
- 11/10/2026 — Plan v2 aprobado. D5, D6, D9 ajustadas en revisión; D1 y D3 aprobadas explícitamente.
