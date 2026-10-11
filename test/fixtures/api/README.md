# Fixtures reales de TheSportsDB

Respuestas **reales** grabadas el 11/10/2026 ~20:10 UTC con la clave gratuita `123`
(`https://www.thesportsdb.com/api/v1/json/123/`). Se guardaron byte a byte con `curl`.

**No editar a mano.** Si hace falta un caso nuevo, grabar otra respuesta real y agregarla a esta tabla.
Los estados (`NS`, `1H`, `FT`…) reflejan el momento de la grabación.

| Archivo | Consulta | HTTP | Registros | Meses (dateEvent) | SHA-256 (12) |
|---|---|---|---|---|---|
| `eventsround_4406_r0_s2026.json` | `eventsround.php?id=4406&r=0&s=2026` | 200 | `events` = 7 | 2026-05: 7 | `ee4c933ce9a2` |
| `eventsround_4406_r1_s2026.json` | `eventsround.php?id=4406&r=1&s=2026` | 200 | `events` = 30 | 2026-01: 15, 2026-07: 15 | `475f5d1203d2` |
| `eventsround_4406_r12_s2026.json` | `eventsround.php?id=4406&r=12&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-10: 15 | `336827065baa` |
| `eventsround_4406_r16_s2026.json` | `eventsround.php?id=4406&r=16&s=2026` | 200 | `events` = 38 | 2026-04: 15, 2026-05: 8, 2026-11: 15 | `fc969646b4ee` |
| `eventsround_4406_r17_s2026.json` | `eventsround.php?id=4406&r=17&s=2026` | 200 | `events` = null |  | `ac165cc3ca83` |
| `eventsround_4616_r1_s2026.json` | `eventsround.php?id=4616&r=1&s=2026` | 200 | `events` = 18 | 2026-02: 18 | `a58c8b0dc978` |
| `eventsround_4616_r33_s2026.json` | `eventsround.php?id=4616&r=33&s=2026` | 200 | `events` = 18 | 2026-10: 18 | `cf69f4b8222b` |
| `eventsround_4500_r64_s2026.json` | `eventsround.php?id=4500&r=64&s=2026` | 200 | `events` = 32 | 2026-01: 4, 2026-02: 12, 2026-03: 9, 2026-04: 7 | `4a4a1a008ff5` |
| `eventsround_4500_r125_s2026.json` | `eventsround.php?id=4500&r=125&s=2026` | 200 | `events` = 4 | 2026-09: 3, 2026-10: 1 | `5cbfe5bc0684` |
| `eventsround_4500_r150_s2026.json` | `eventsround.php?id=4500&r=150&s=2026` | 200 | `events` = 2 | 2026-10: 2 | `963bdbdec7b3` |
| `eventsnextleague_4406.json` | `eventsnextleague.php?id=4406` | 200 | `events` = 1 | 2026-10: 1 | `10258ee869e6` |
| `eventspastleague_4406.json` | `eventspastleague.php?id=4406` | 200 | `events` = 1 | 2026-10: 1 | `af3c43731b35` |
| `eventsnextleague_4616.json` | `eventsnextleague.php?id=4616` | 200 | `events` = 1 | 2026-10: 1 | `9466ab5b2484` |
| `eventspastleague_4616.json` | `eventspastleague.php?id=4616` | 200 | `events` = 1 | 2026-10: 1 | `af87f3b38774` |
| `lookupevent_2397877.json` | `lookupevent.php?id=2397877` | 200 | `events` = 1 | 2026-03: 1 | `fefa9c604815` |
| `lookupteam_135156.json` | `lookupteam.php?id=135156` | 200 | `teams` = 1 |  | `40bd10bff5ea` |
| `lookupleague_4406.json` | `lookupleague.php?id=4406` | 200 | `leagues` = 1 |  | `6f0bd9a5c759` |
| `lookupleague_4500.json` | `lookupleague.php?id=4500` | 200 | `leagues` = 1 |  | `8aeae86f52d9` |
