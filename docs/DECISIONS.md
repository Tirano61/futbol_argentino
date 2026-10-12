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
| D8 | Otras competiciones del equipo | post-MVP como «información parcial» |
| D9 | Sincronización | **Ajustada**: `SyncScheduler` incremental, priorizado, cancelable, reanudable, con cupos |
| D10 | Temporadas | actual y anterior (`YYYY`) |
| D11 | En juego | estado + «actualizado hh:mm», refresco manual; auto-refresco post-MVP |
| D12 | Escudos en Web | ✅ **Cerrada tras T0.2**: `Image.network(..., webHtmlElementStrategy: WebHtmlElementStrategy.fallback)` + placeholder con iniciales si falla la red. Sin proxy. |
| D13 | `matches` como núcleo; fixtures dentro de `competitions` | recomendada |
| D14 | Datos y caché antes que pantallas; Copa en el fixture desde el inicio | recomendada |

---


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
