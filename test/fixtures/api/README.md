# Fixtures reales de TheSportsDB

Respuestas **reales** de la clave gratuita `123` (`https://www.thesportsdb.com/api/v1/json/123/`), guardadas byte a byte con `curl`.

**No editar a mano.** Si hace falta un caso nuevo, grabar otra respuesta real y agregarla a esta tabla.
Los estados (`NS`, `1H`, `FT`…) reflejan el momento de la grabación.

| Archivo | Consulta | HTTP | Registros | Meses (dateEvent) | Grabado | SHA-256 (12) |
|---|---|---|---|---|---|---|
| `eventsround_4406_r0_s2026.json` | `eventsround.php?id=4406&r=0&s=2026` | 200 | `events` = 7 | 2026-05: 7 | 11/10/2026 20:10 UTC | `ee4c933ce9a2` |
| `eventsround_4406_r1_s2026.json` | `eventsround.php?id=4406&r=1&s=2026` | 200 | `events` = 30 | 2026-01: 15, 2026-07: 15 | 11/10/2026 20:10 UTC | `475f5d1203d2` |
| `eventsround_4406_r12_s2026.json` | `eventsround.php?id=4406&r=12&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-10: 15 | 11/10/2026 20:10 UTC | `336827065baa` |
| `eventsround_4406_r16_s2026.json` | `eventsround.php?id=4406&r=16&s=2026` | 200 | `events` = 38 | 2026-04: 15, 2026-05: 8, 2026-11: 15 | 11/10/2026 20:10 UTC | `fc969646b4ee` |
| `eventsround_4406_r17_s2026.json` | `eventsround.php?id=4406&r=17&s=2026` | 200 | `events` = null |  | 11/10/2026 20:10 UTC | `ac165cc3ca83` |
| `eventsround_4616_r1_s2026.json` | `eventsround.php?id=4616&r=1&s=2026` | 200 | `events` = 18 | 2026-02: 18 | 11/10/2026 20:10 UTC | `a58c8b0dc978` |
| `eventsround_4616_r33_s2026.json` | `eventsround.php?id=4616&r=33&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 11/10/2026 20:10 UTC | `cf69f4b8222b` |
| `eventsround_4500_r64_s2026.json` | `eventsround.php?id=4500&r=64&s=2026` | 200 | `events` = 32 | 2026-01: 4, 2026-02: 12, 2026-03: 9, 2026-04: 7 | 11/10/2026 20:10 UTC | `4a4a1a008ff5` |
| `eventsround_4500_r125_s2026.json` | `eventsround.php?id=4500&r=125&s=2026` | 200 | `events` = 4 | 2026-09: 3, 2026-10: 1 | 11/10/2026 20:10 UTC | `5cbfe5bc0684` |
| `eventsround_4500_r150_s2026.json` | `eventsround.php?id=4500&r=150&s=2026` | 200 | `events` = 2 | 2026-10: 2 | 11/10/2026 20:10 UTC | `963bdbdec7b3` |
| `eventsnextleague_4406.json` | `eventsnextleague.php?id=4406` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 20:10 UTC | `10258ee869e6` |
| `eventspastleague_4406.json` | `eventspastleague.php?id=4406` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 20:10 UTC | `af3c43731b35` |
| `eventsnextleague_4616.json` | `eventsnextleague.php?id=4616` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 20:10 UTC | `9466ab5b2484` |
| `eventspastleague_4616.json` | `eventspastleague.php?id=4616` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 20:10 UTC | `af87f3b38774` |
| `lookupevent_2397877.json` | `lookupevent.php?id=2397877` | 200 | `events` = 1 | 2026-03: 1 | 11/10/2026 20:10 UTC | `fefa9c604815` |
| `lookupteam_135156.json` | `lookupteam.php?id=135156` | 200 | `teams` = 1 |  | 11/10/2026 20:10 UTC | `40bd10bff5ea` |
| `lookupleague_4406.json` | `lookupleague.php?id=4406` | 200 | `leagues` = 1 |  | 11/10/2026 20:10 UTC | `6f0bd9a5c759` |
| `lookupleague_4500.json` | `lookupleague.php?id=4500` | 200 | `leagues` = 1 |  | 11/10/2026 20:10 UTC | `8aeae86f52d9` |
| `eventsround_4406_r2_s2026.json` | `eventsround.php?id=4406&r=2&s=2026` | 200 | `events` = 30 | 2026-01: 15, 2026-07: 12, 2026-08: 3 | 11/10/2026 20:35 UTC | `e54a57ca652a` |
| `eventsround_4406_r3_s2026.json` | `eventsround.php?id=4406&r=3&s=2026` | 200 | `events` = 30 | 2026-01: 2, 2026-02: 13, 2026-08: 15 | 11/10/2026 20:35 UTC | `e99cb47c3cb0` |
| `eventsround_4406_r4_s2026.json` | `eventsround.php?id=4406&r=4&s=2026` | 200 | `events` = 30 | 2026-02: 15, 2026-08: 15 | 11/10/2026 20:35 UTC | `10543559fafa` |
| `eventsround_4406_r5_s2026.json` | `eventsround.php?id=4406&r=5&s=2026` | 200 | `events` = 30 | 2026-02: 15, 2026-08: 15 | 11/10/2026 20:35 UTC | `de2e61b1f637` |
| `eventsround_4406_r6_s2026.json` | `eventsround.php?id=4406&r=6&s=2026` | 200 | `events` = 30 | 2026-02: 14, 2026-03: 1, 2026-08: 15 | 11/10/2026 20:35 UTC | `29f9feb8ca09` |
| `eventsround_4406_r7_s2026.json` | `eventsround.php?id=4406&r=7&s=2026` | 200 | `events` = 30 | 2026-02: 13, 2026-03: 2, 2026-08: 13, 2026-09: 2 | 11/10/2026 20:35 UTC | `dbe03d1aa98a` |
| `eventsround_4406_r8_s2026.json` | `eventsround.php?id=4406&r=8&s=2026` | 200 | `events` = 30 | 2026-02: 2, 2026-03: 13, 2026-09: 15 | 11/10/2026 20:35 UTC | `1715700c8f1c` |
| `eventsround_4406_r9_s2026.json` | `eventsround.php?id=4406&r=9&s=2026` | 200 | `events` = 30 | 2026-05: 15, 2026-09: 15 | 11/10/2026 20:35 UTC | `9a9688ea3265` |
| `eventsround_4406_r10_s2026.json` | `eventsround.php?id=4406&r=10&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-09: 15 | 11/10/2026 20:35 UTC | `3fed8f3578e3` |
| `eventsround_4406_r11_s2026.json` | `eventsround.php?id=4406&r=11&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-10: 15 | 11/10/2026 20:35 UTC | `35d0fc2dac21` |
| `eventsround_4406_r13_s2026.json` | `eventsround.php?id=4406&r=13&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-10: 15 | 11/10/2026 20:35 UTC | `4c6508ad5fb6` |
| `eventsround_4406_r14_s2026.json` | `eventsround.php?id=4406&r=14&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-10: 15 | 11/10/2026 20:35 UTC | `af7e9350d30e` |
| `eventsround_4406_r15_s2026.json` | `eventsround.php?id=4406&r=15&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-11: 15 | 11/10/2026 20:35 UTC | `088bd3284bcd` |
| `eventsround_4406_r0_s2025.json` | `eventsround.php?id=4406&r=0&s=2025` | 200 | `events` = null |  | 11/10/2026 20:35 UTC | `ac165cc3ca83` |
| `eventsround_4406_r1_s2025.json` | `eventsround.php?id=4406&r=1&s=2025` | 200 | `events` = 30 | 2025-01: 15, 2025-07: 15 | 11/10/2026 20:35 UTC | `eea84169f868` |
| `eventsround_4406_r2_s2025.json` | `eventsround.php?id=4406&r=2&s=2025` | 200 | `events` = 30 | 2025-01: 15, 2025-07: 15 | 11/10/2026 20:35 UTC | `9ceb6df1c041` |
| `eventsround_4406_r3_s2025.json` | `eventsround.php?id=4406&r=3&s=2025` | 200 | `events` = 30 | 2025-02: 14, 2025-03: 1, 2025-07: 15 | 11/10/2026 20:35 UTC | `5d1fd2b80709` |
| `eventsround_4406_r4_s2025.json` | `eventsround.php?id=4406&r=4&s=2025` | 200 | `events` = 30 | 2025-02: 15, 2025-08: 15 | 11/10/2026 20:35 UTC | `8031e2e5dd9d` |
| `eventsround_4406_r5_s2025.json` | `eventsround.php?id=4406&r=5&s=2025` | 200 | `events` = 30 | 2025-02: 15, 2025-08: 15 | 11/10/2026 20:35 UTC | `b22ee414ef37` |
| `eventsround_4406_r6_s2025.json` | `eventsround.php?id=4406&r=6&s=2025` | 200 | `events` = 30 | 2025-02: 15, 2025-08: 14, 2025-10: 1 | 11/10/2026 20:35 UTC | `6381a0a1adcb` |
| `eventsround_4406_r7_s2025.json` | `eventsround.php?id=4406&r=7&s=2025` | 200 | `events` = 30 | 2025-02: 14, 2025-03: 1, 2025-08: 11, 2025-09: 3, 2025-10: 1 | 11/10/2026 20:35 UTC | `c95335413cd5` |
| `eventsround_4406_r8_s2025.json` | `eventsround.php?id=4406&r=8&s=2025` | 200 | `events` = 30 | 2025-02: 1, 2025-03: 14, 2025-09: 15 | 11/10/2026 20:35 UTC | `11d6d039ad1b` |
| `eventsround_4406_r9_s2025.json` | `eventsround.php?id=4406&r=9&s=2025` | 200 | `events` = 30 | 2025-03: 15, 2025-09: 15 | 11/10/2026 20:35 UTC | `50099eafdbb2` |
| `eventsround_4406_r10_s2025.json` | `eventsround.php?id=4406&r=10&s=2025` | 200 | `events` = 30 | 2025-03: 15, 2025-09: 15 | 11/10/2026 20:35 UTC | `36f1ed633095` |
| `eventsround_4406_r11_s2025.json` | `eventsround.php?id=4406&r=11&s=2025` | 200 | `events` = 30 | 2025-03: 15, 2025-10: 15 | 11/10/2026 20:35 UTC | `9dc547cb7fd3` |
| `eventsround_4406_r12_s2025.json` | `eventsround.php?id=4406&r=12&s=2025` | 200 | `events` = 30 | 2025-04: 15, 2025-10: 15 | 11/10/2026 20:35 UTC | `6041de8c9e52` |
| `eventsround_4406_r13_s2025.json` | `eventsround.php?id=4406&r=13&s=2025` | 200 | `events` = 30 | 2025-04: 15, 2025-10: 15 | 11/10/2026 20:35 UTC | `f0ac66bfebab` |
| `eventsround_4406_r14_s2025.json` | `eventsround.php?id=4406&r=14&s=2025` | 200 | `events` = 30 | 2025-04: 14, 2025-05: 1, 2025-10: 1, 2025-11: 14 | 11/10/2026 20:35 UTC | `ed6e40e74b95` |
| `eventsround_4406_r15_s2025.json` | `eventsround.php?id=4406&r=15&s=2025` | 200 | `events` = 30 | 2025-04: 15, 2025-11: 15 | 11/10/2026 20:35 UTC | `215f4d99c32c` |
| `eventsround_4406_r16_s2025.json` | `eventsround.php?id=4406&r=16&s=2025` | 200 | `events` = 30 | 2025-05: 15, 2025-11: 15 | 11/10/2026 20:35 UTC | `e2a4eebf08f6` |
| `eventsround_4616_r34_s2026.json` | `eventsround.php?id=4616&r=34&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 11/10/2026 20:35 UTC | `23aabbb92568` |
| `eventsround_4616_r35_s2026.json` | `eventsround.php?id=4616&r=35&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 11/10/2026 20:35 UTC | `7feb8b15d171` |
| `eventsround_4616_r36_s2026.json` | `eventsround.php?id=4616&r=36&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 11/10/2026 20:35 UTC | `8ac6afba90b4` |
| `eventsround_4616_r37_s2026.json` | `eventsround.php?id=4616&r=37&s=2026` | 200 | `events` = null |  | 11/10/2026 20:35 UTC | `ac165cc3ca83` |
| `eventsround_4616_r1_s2025.json` | `eventsround.php?id=4616&r=1&s=2025` | 200 | `events` = 18 | 2025-02: 18 | 11/10/2026 21:45 UTC | `47d3660ec8a3` |
| `eventsround_4616_r35_s2025.json` | `eventsround.php?id=4616&r=35&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4616_r36_s2025.json` | `eventsround.php?id=4616&r=36&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r32_s2025.json` | `eventsround.php?id=4500&r=32&s=2025` | 200 | `events` = 16 | 2025-05: 5, 2025-06: 5, 2025-07: 5, 2025-08: 1 | 11/10/2026 21:45 UTC | `f9603e426ec7` |
| `eventsround_4500_r16_s2025.json` | `eventsround.php?id=4500&r=16&s=2025` | 200 | `events` = 4 | 2025-08: 4 | 11/10/2026 21:45 UTC | `75628e0e27e0` |
| `eventsround_4500_r125_s2025.json` | `eventsround.php?id=4500&r=125&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r150_s2025.json` | `eventsround.php?id=4500&r=150&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r160_s2025.json` | `eventsround.php?id=4500&r=160&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r170_s2025.json` | `eventsround.php?id=4500&r=170&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r175_s2025.json` | `eventsround.php?id=4500&r=175&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r180_s2025.json` | `eventsround.php?id=4500&r=180&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r190_s2025.json` | `eventsround.php?id=4500&r=190&s=2025` | 200 | `events` = null |  | 11/10/2026 21:45 UTC | `ac165cc3ca83` |
| `eventsround_4500_r200_s2025.json` | `eventsround.php?id=4500&r=200&s=2025` | 200 | `events` = 1 | 2025-11: 1 | 11/10/2026 21:45 UTC | `2c99bad75fca` |
| `eventsnextleague_4500.json` | `eventsnextleague.php?id=4500` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 23:34 UTC | `6f4bbc103a4e` |
| `eventspastleague_4500.json` | `eventspastleague.php?id=4500` | 200 | `events` = 1 | 2026-10: 1 | 11/10/2026 23:34 UTC | `29155decc8d3` |
| `eventsround_4500_r200_s2026.json` | `eventsround.php?id=4500&r=200&s=2026` | 200 | `events` = null |  | 11/10/2026 23:34 UTC | `ac165cc3ca83` |
| `eventsround_4500_r32_s2026.json` | `eventsround.php?id=4500&r=32&s=2026` | 200 | `events` = 16 | 2026-04: 2, 2026-05: 8, 2026-06: 1, 2026-07: 5 | 12/10/2026 14:44 UTC | `297e44b07320` |
| `eventsround_4500_r16_s2026.json` | `eventsround.php?id=4500&r=16&s=2026` | 200 | `events` = 8 | 2026-08: 7, 2026-09: 1 | 12/10/2026 14:44 UTC | `44c1f086f208` |
| `searchteams_River.json` | `searchteams.php?t=River` | 200 | `teams` = 1 (River-PI, Brasil) |  | 12/10/2026 14:44 UTC | `ecc04789fe25` |
| `searchteams_River_Plate.json` | `searchteams.php?t=River%20Plate` | 200 | `teams` = 1 (River Plate, Argentina) |  | 12/10/2026 14:44 UTC | `761453afc9b6` |
| `searchteams_Boca.json` | `searchteams.php?t=Boca` | 200 | `teams` = 1 (Boca Unidos, Argentina, Federal A) |  | 12/10/2026 14:44 UTC | `587d71762c7d` |
| `eventsround_4406_r1_s2027.json` | `eventsround.php?id=4406&r=1&s=2027` | 200 | `events` = null |  | 12/10/2026 14:48 UTC | `ac165cc3ca83` |

## Fase 11 (12/10/2026) — validaciones post-MVP

Grabadas con `curl` a ~17 consultas por minuto (V8–V10, V12, V14).

- `snapshot_20261012/`: **instantánea** de Primera 2026 (r0–r16) y de Nacional r33–r36 del mismo momento que `lookuptable_*_s2026.json`, para contrastar tablas. No reemplaza a los archivos del 11/10 que usan los tests actuales (r0, r1 y r2 de Primera no cambiaron: mismo SHA-256).
- `eventsnext_*` / `eventslast_*`: próximo y último partido de Boca (135156), River (135171) y Chacarita (135899). `eventslast` usa la clave `results`, no `events`.
- `lookuptable_*`: 5 filas, por zona (`strGroup`).

| Archivo | Consulta | HTTP | Registros | Meses (dateEvent) | Grabado | SHA-256 (12) |
|---|---|---|---|---|---|---|
| `lookupleague_5215.json` | `lookupleague.php?id=5215` | 200 | `leagues` = 1 |  | 12/10/2026 21:59 UTC | `90a606e3db9d` |
| `lookupleague_5523.json` | `lookupleague.php?id=5523` | 200 | `leagues` = 1 |  | 12/10/2026 21:59 UTC | `495196d8ec22` |
| `lookupleague_5524.json` | `lookupleague.php?id=5524` | 200 | `leagues` = 1 |  | 12/10/2026 21:59 UTC | `7e1b12c57d3f` |
| `lookupleague_5428.json` | `lookupleague.php?id=5428` | 200 | `leagues` = 1 |  | 12/10/2026 21:59 UTC | `a4eb9f82f68b` |
| `lookupleague_4724.json` | `lookupleague.php?id=4724` | 200 | `leagues` = 1 |  | 12/10/2026 21:59 UTC | `3e7c7a577c47` |
| `search_all_leagues_Argentina.json` | `search_all_leagues.php?c=Argentina` | 200 | `countries` = 5 |  | 12/10/2026 21:59 UTC | `d84113f69448` |
| `eventsnextleague_5215.json` | `eventsnextleague.php?id=5215` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 21:59 UTC | `554f0b545a7f` |
| `eventspastleague_5215.json` | `eventspastleague.php?id=5215` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 21:59 UTC | `cdafcb590511` |
| `eventsnextleague_5523.json` | `eventsnextleague.php?id=5523` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 21:59 UTC | `666e6af32a7e` |
| `eventspastleague_5523.json` | `eventspastleague.php?id=5523` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 21:59 UTC | `3ac3a3479171` |
| `eventsnextleague_5524.json` | `eventsnextleague.php?id=5524` | 200 | `events` = null |  | 12/10/2026 21:59 UTC | `ac165cc3ca83` |
| `eventspastleague_5524.json` | `eventspastleague.php?id=5524` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `78d9ef1942d3` |
| `eventsnextleague_5428.json` | `eventsnextleague.php?id=5428` | 200 | `events` = null |  | 12/10/2026 22:00 UTC | `ac165cc3ca83` |
| `eventspastleague_5428.json` | `eventspastleague.php?id=5428` | 200 | `events` = 1 | 2024-05: 1 | 12/10/2026 22:00 UTC | `7d5bb894f846` |
| `eventsnext_135156.json` | `eventsnext.php?id=135156` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `2009b3529f70` |
| `eventslast_135156.json` | `eventslast.php?id=135156` | 200 | `results` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `dc80bb8500a5` |
| `eventsnext_135171.json` | `eventsnext.php?id=135171` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `944076ebd843` |
| `eventslast_135171.json` | `eventslast.php?id=135171` | 200 | `results` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `9af5ae4929a0` |
| `eventsnext_135899.json` | `eventsnext.php?id=135899` | 200 | `events` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `67ea9f123162` |
| `eventslast_135899.json` | `eventslast.php?id=135899` | 200 | `results` = 1 | 2026-10: 1 | 12/10/2026 22:00 UTC | `47150938d6df` |
| `lookuptable_4406_s2026.json` | `lookuptable.php?l=4406&s=2026` | 200 | `table` = 5 |  | 12/10/2026 22:00 UTC | `4c945b0544b2` |
| `lookuptable_4616_s2026.json` | `lookuptable.php?l=4616&s=2026` | 200 | `table` = 5 |  | 12/10/2026 22:00 UTC | `eb6ca3de645c` |
| `snapshot_20261012/eventsround_4406_r0_s2026.json` | `eventsround.php?id=4406&r=0&s=2026` | 200 | `events` = 7 | 2026-05: 7 | 12/10/2026 22:01 UTC | `ee4c933ce9a2` |
| `snapshot_20261012/eventsround_4406_r1_s2026.json` | `eventsround.php?id=4406&r=1&s=2026` | 200 | `events` = 30 | 2026-01: 15, 2026-07: 15 | 12/10/2026 22:01 UTC | `475f5d1203d2` |
| `snapshot_20261012/eventsround_4406_r2_s2026.json` | `eventsround.php?id=4406&r=2&s=2026` | 200 | `events` = 30 | 2026-01: 15, 2026-07: 12, 2026-08: 3 | 12/10/2026 22:01 UTC | `e54a57ca652a` |
| `snapshot_20261012/eventsround_4406_r3_s2026.json` | `eventsround.php?id=4406&r=3&s=2026` | 200 | `events` = 30 | 2026-01: 2, 2026-02: 13, 2026-08: 15 | 12/10/2026 22:01 UTC | `e99cb47c3cb0` |
| `snapshot_20261012/eventsround_4406_r4_s2026.json` | `eventsround.php?id=4406&r=4&s=2026` | 200 | `events` = 30 | 2026-02: 15, 2026-08: 15 | 12/10/2026 22:01 UTC | `10543559fafa` |
| `snapshot_20261012/eventsround_4406_r5_s2026.json` | `eventsround.php?id=4406&r=5&s=2026` | 200 | `events` = 30 | 2026-02: 15, 2026-08: 15 | 12/10/2026 22:01 UTC | `de2e61b1f637` |
| `snapshot_20261012/eventsround_4406_r6_s2026.json` | `eventsround.php?id=4406&r=6&s=2026` | 200 | `events` = 30 | 2026-02: 14, 2026-03: 1, 2026-08: 15 | 12/10/2026 22:01 UTC | `29f9feb8ca09` |
| `snapshot_20261012/eventsround_4406_r7_s2026.json` | `eventsround.php?id=4406&r=7&s=2026` | 200 | `events` = 30 | 2026-02: 13, 2026-03: 2, 2026-08: 13, 2026-09: 2 | 12/10/2026 22:01 UTC | `dbe03d1aa98a` |
| `snapshot_20261012/eventsround_4406_r8_s2026.json` | `eventsround.php?id=4406&r=8&s=2026` | 200 | `events` = 30 | 2026-02: 2, 2026-03: 13, 2026-09: 15 | 12/10/2026 22:01 UTC | `1715700c8f1c` |
| `snapshot_20261012/eventsround_4406_r9_s2026.json` | `eventsround.php?id=4406&r=9&s=2026` | 200 | `events` = 30 | 2026-05: 15, 2026-09: 15 | 12/10/2026 22:01 UTC | `9a9688ea3265` |
| `snapshot_20261012/eventsround_4406_r10_s2026.json` | `eventsround.php?id=4406&r=10&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-09: 15 | 12/10/2026 22:01 UTC | `3fed8f3578e3` |
| `snapshot_20261012/eventsround_4406_r11_s2026.json` | `eventsround.php?id=4406&r=11&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-10: 15 | 12/10/2026 22:02 UTC | `35d0fc2dac21` |
| `snapshot_20261012/eventsround_4406_r12_s2026.json` | `eventsround.php?id=4406&r=12&s=2026` | 200 | `events` = 30 | 2026-03: 15, 2026-10: 15 | 12/10/2026 22:02 UTC | `2fdf27c60c1e` |
| `snapshot_20261012/eventsround_4406_r13_s2026.json` | `eventsround.php?id=4406&r=13&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-10: 15 | 12/10/2026 22:02 UTC | `0eeee87e4e25` |
| `snapshot_20261012/eventsround_4406_r14_s2026.json` | `eventsround.php?id=4406&r=14&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-10: 15 | 12/10/2026 22:02 UTC | `61f0e30c7095` |
| `snapshot_20261012/eventsround_4406_r15_s2026.json` | `eventsround.php?id=4406&r=15&s=2026` | 200 | `events` = 30 | 2026-04: 15, 2026-11: 15 | 12/10/2026 22:02 UTC | `874434b7392a` |
| `snapshot_20261012/eventsround_4406_r16_s2026.json` | `eventsround.php?id=4406&r=16&s=2026` | 200 | `events` = 38 | 2026-04: 15, 2026-05: 8, 2026-11: 15 | 12/10/2026 22:02 UTC | `fc969646b4ee` |
| `snapshot_20261012/eventsround_4616_r33_s2026.json` | `eventsround.php?id=4616&r=33&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 12/10/2026 22:02 UTC | `7afffb6b4a81` |
| `snapshot_20261012/eventsround_4616_r34_s2026.json` | `eventsround.php?id=4616&r=34&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 12/10/2026 22:02 UTC | `23aabbb92568` |
| `snapshot_20261012/eventsround_4616_r35_s2026.json` | `eventsround.php?id=4616&r=35&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 12/10/2026 22:02 UTC | `7feb8b15d171` |
| `snapshot_20261012/eventsround_4616_r36_s2026.json` | `eventsround.php?id=4616&r=36&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 12/10/2026 22:02 UTC | `8ac6afba90b4` |
| `eventsround_4616_r2_s2026.json` | `eventsround.php?id=4616&r=2&s=2026` | 200 | `events` = 18 | 2026-02: 18 | 12/10/2026 22:02 UTC | `23aa5925f7f2` |
| `eventsround_4616_r3_s2026.json` | `eventsround.php?id=4616&r=3&s=2026` | 200 | `events` = 18 | 2026-02: 5, 2026-03: 13 | 12/10/2026 22:02 UTC | `bce5cbf8341c` |
| `eventsround_4616_r4_s2026.json` | `eventsround.php?id=4616&r=4&s=2026` | 200 | `events` = 18 | 2026-06: 18 | 12/10/2026 22:02 UTC | `396ef37d15cf` |
| `eventsround_4616_r5_s2026.json` | `eventsround.php?id=4616&r=5&s=2026` | 200 | `events` = 18 | 2026-03: 18 | 12/10/2026 22:02 UTC | `d129bac85f17` |
| `eventsround_4616_r6_s2026.json` | `eventsround.php?id=4616&r=6&s=2026` | 200 | `events` = 18 | 2026-03: 18 | 12/10/2026 22:02 UTC | `8ec14c25f917` |
| `eventsround_4616_r7_s2026.json` | `eventsround.php?id=4616&r=7&s=2026` | 200 | `events` = 18 | 2026-03: 17, 2026-04: 1 | 12/10/2026 22:03 UTC | `4e7add80dbc7` |
| `eventsround_4616_r8_s2026.json` | `eventsround.php?id=4616&r=8&s=2026` | 200 | `events` = 18 | 2026-04: 18 | 12/10/2026 22:03 UTC | `f93d4e1c4dce` |
| `eventsround_4616_r9_s2026.json` | `eventsround.php?id=4616&r=9&s=2026` | 200 | `events` = 18 | 2026-04: 18 | 12/10/2026 22:03 UTC | `73d0f8b873dc` |
| `eventsround_4616_r10_s2026.json` | `eventsround.php?id=4616&r=10&s=2026` | 200 | `events` = 18 | 2026-04: 18 | 12/10/2026 22:03 UTC | `193b002d6a3d` |
| `eventsround_4616_r11_s2026.json` | `eventsround.php?id=4616&r=11&s=2026` | 200 | `events` = 18 | 2026-04: 18 | 12/10/2026 22:03 UTC | `df57bb02493b` |
| `eventsround_4616_r12_s2026.json` | `eventsround.php?id=4616&r=12&s=2026` | 200 | `events` = 18 | 2026-04: 1, 2026-05: 17 | 12/10/2026 22:03 UTC | `1fcba4bf6889` |
| `eventsround_4616_r13_s2026.json` | `eventsround.php?id=4616&r=13&s=2026` | 200 | `events` = 18 | 2026-05: 18 | 12/10/2026 22:03 UTC | `4a0fa703da8b` |
| `eventsround_4616_r14_s2026.json` | `eventsround.php?id=4616&r=14&s=2026` | 200 | `events` = 18 | 2026-05: 18 | 12/10/2026 22:03 UTC | `ae860ce6e1d6` |
| `eventsround_4616_r15_s2026.json` | `eventsround.php?id=4616&r=15&s=2026` | 200 | `events` = 18 | 2026-05: 18 | 12/10/2026 22:03 UTC | `3f6ec2420fcd` |
| `eventsround_4616_r16_s2026.json` | `eventsround.php?id=4616&r=16&s=2026` | 200 | `events` = 18 | 2026-05: 17, 2026-06: 1 | 12/10/2026 22:03 UTC | `cdf106f181cf` |
| `eventsround_4616_r17_s2026.json` | `eventsround.php?id=4616&r=17&s=2026` | 200 | `events` = 18 | 2026-06: 17, 2026-08: 1 | 12/10/2026 22:03 UTC | `8f128d6b9d58` |
| `eventsround_4616_r18_s2026.json` | `eventsround.php?id=4616&r=18&s=2026` | 200 | `events` = 18 | 2026-06: 18 | 12/10/2026 22:03 UTC | `bfdef92374f7` |
| `eventsround_4616_r19_s2026.json` | `eventsround.php?id=4616&r=19&s=2026` | 200 | `events` = 18 | 2026-07: 18 | 12/10/2026 22:03 UTC | `35f1095f996e` |
| `eventsround_4616_r20_s2026.json` | `eventsround.php?id=4616&r=20&s=2026` | 200 | `events` = 18 | 2026-07: 18 | 12/10/2026 22:03 UTC | `abb2049656b6` |
| `eventsround_4616_r21_s2026.json` | `eventsround.php?id=4616&r=21&s=2026` | 200 | `events` = 18 | 2026-07: 7, 2026-08: 8, 2026-09: 3 | 12/10/2026 22:03 UTC | `d69806f19768` |
| `eventsround_4616_r22_s2026.json` | `eventsround.php?id=4616&r=22&s=2026` | 200 | `events` = 18 | 2026-07: 18 | 12/10/2026 22:03 UTC | `41a5190ade37` |
| `eventsround_4616_r23_s2026.json` | `eventsround.php?id=4616&r=23&s=2026` | 200 | `events` = 18 | 2026-08: 18 | 12/10/2026 22:04 UTC | `8ec108c839d5` |
| `eventsround_4616_r24_s2026.json` | `eventsround.php?id=4616&r=24&s=2026` | 200 | `events` = 18 | 2026-08: 18 | 12/10/2026 22:04 UTC | `ffdc974708f0` |
| `eventsround_4616_r25_s2026.json` | `eventsround.php?id=4616&r=25&s=2026` | 200 | `events` = 18 | 2026-08: 18 | 12/10/2026 22:04 UTC | `e280f780d743` |
| `eventsround_4616_r26_s2026.json` | `eventsround.php?id=4616&r=26&s=2026` | 200 | `events` = 18 | 2026-08: 18 | 12/10/2026 22:04 UTC | `a0b5760e0cdd` |
| `eventsround_4616_r27_s2026.json` | `eventsround.php?id=4616&r=27&s=2026` | 200 | `events` = 18 | 2026-08: 17, 2026-09: 1 | 12/10/2026 22:04 UTC | `a9823c0f7251` |
| `eventsround_4616_r28_s2026.json` | `eventsround.php?id=4616&r=28&s=2026` | 200 | `events` = 18 | 2026-09: 18 | 12/10/2026 22:04 UTC | `7e2c492d951f` |
| `eventsround_4616_r29_s2026.json` | `eventsround.php?id=4616&r=29&s=2026` | 200 | `events` = 18 | 2026-09: 18 | 12/10/2026 22:04 UTC | `eb064d05eb2b` |
| `eventsround_4616_r30_s2026.json` | `eventsround.php?id=4616&r=30&s=2026` | 200 | `events` = 18 | 2026-09: 18 | 12/10/2026 22:04 UTC | `3ae698d6d961` |
| `eventsround_4616_r31_s2026.json` | `eventsround.php?id=4616&r=31&s=2026` | 200 | `events` = 18 | 2026-09: 18 | 12/10/2026 22:04 UTC | `b4efd225060f` |
| `eventsround_4616_r32_s2026.json` | `eventsround.php?id=4616&r=32&s=2026` | 200 | `events` = 18 | 2026-10: 18 | 12/10/2026 22:04 UTC | `1e2e9f5971ea` |
| `eventsround_5215_r1_s2026.json` | `eventsround.php?id=5215&r=1&s=2026` | 200 | `events` = 11 | 2026-02: 11 | 12/10/2026 22:04 UTC | `69fdc3d6261c` |
| `eventsround_5215_r39_s2026.json` | `eventsround.php?id=5215&r=39&s=2026` | 200 | `events` = 11 | 2026-10: 11 | 12/10/2026 22:04 UTC | `92bf8e7d10ca` |
| `eventsround_5523_r1_s2026.json` | `eventsround.php?id=5523&r=1&s=2026` | 200 | `events` = 35 | 2026-03: 18, 2026-08: 17 | 12/10/2026 22:04 UTC | `fe846e72024e` |
| `eventsround_5523_r32_s2026.json` | `eventsround.php?id=5523&r=32&s=2026` | 200 | `events` = 24 | 2026-10: 24 | 12/10/2026 22:04 UTC | `29cd2d6ed732` |
| `eventsround_5524_r1_s2026.json` | `eventsround.php?id=5524&r=1&s=2026` | 200 | `events` = 14 | 2026-02: 13, 2026-03: 1 | 12/10/2026 22:04 UTC | `88e80c44346e` |
| `eventsround_5524_r32_s2026.json` | `eventsround.php?id=5524&r=32&s=2026` | 200 | `events` = 14 | 2026-10: 14 | 12/10/2026 22:04 UTC | `9cf26b3c7969` |

Grabadas en la Fase 15 (13/10/2026 01:26 UTC): fecha siguiente y fin de temporada de la Primera B Metropolitana, primera fecha 2025 de B Metro y de Primera C, y la fecha 33 de Primera C (vacía).

| Archivo | Consulta | HTTP | Registros | Meses (dateEvent) | Grabado | SHA-256 (12) |
|---|---|---|---|---|---|---|
| `eventsround_5215_r40_s2026.json` | `eventsround.php?id=5215&r=40&s=2026` | 200 | `events` = 11 | 2026-10: 11 | 13/10/2026 01:26 UTC | `4c1b39ff420a` |
| `eventsround_5215_r42_s2026.json` | `eventsround.php?id=5215&r=42&s=2026` | 200 | `events` = 11 | 2026-10: 11 | 13/10/2026 01:26 UTC | `2c786fbe2d9d` |
| `eventsround_5215_r43_s2026.json` | `eventsround.php?id=5215&r=43&s=2026` | 200 | `events` = null |  | 13/10/2026 01:26 UTC | `ac165cc3ca83` |
| `eventsround_5215_r1_s2025.json` | `eventsround.php?id=5215&r=1&s=2025` | 200 | `events` = 20 | 2025-02: 10, 2025-06: 10 | 13/10/2026 01:26 UTC | `5e33f103cc19` |
| `eventsround_5524_r33_s2026.json` | `eventsround.php?id=5524&r=33&s=2026` | 200 | `events` = null |  | 13/10/2026 01:26 UTC | `ac165cc3ca83` |
| `eventsround_5524_r1_s2025.json` | `eventsround.php?id=5524&r=1&s=2025` | 200 | `events` = 13 | 2025-03: 12, 2025-04: 1 | 13/10/2026 01:26 UTC | `2e343109ddf9` |

## Hito D · Fase D1 (14/10/2026, ~21:40 ART) — Copa Libertadores (4501) y Copa Sudamericana (4724)

Grabadas con `curl` a ~17 consultas por minuto. Temporadas 2025 (completa) y 2026 (semifinales en curso, finales sin cargar: `r=200` vacío).

- Rondas por temporada: ver `docs/API.md` (V16). En 2026 `r=1/2/3` mezclan fases previas (feb–mar) con las fechas 1–3 de grupos (abr–may).
- `lookuptable_*`: la API responde HTTP 200 con **cuerpo vacío** (no hay tabla para estas copas).
- `lookupevent_*`: casos testigo: 2399234 (U. Católica–Juventud, `PEN` 3-4 con tanda 3-4), 2405728 (Táchira–The Strongest, `PEN` con tanda), 2600657 (Atlético Mineiro–Santos, `PEN` **sin** tanda), 2478540 (Ind. Rivadavia–Fluminense, `PEN` con tanda), 2453080 (grupo con `strGroup` «A»), 2239192 (`WO`), 2453109 (`AWD`).

| Archivo | Consulta | HTTP | Registros | Meses (dateEvent) | Grabado | SHA-256 (12) |
|---|---|---|---|---|---|---|
| `lookupleague_4501.json` | `lookupleague.php?id=4501` | 200 | `leagues` = 1 |  | 15/10/2026 00:38 UTC | `6392552b7b45` |
| `eventsnextleague_4501.json` | `eventsnextleague.php?id=4501` | 200 | `events` = 1 | 2026-10: 1 | 15/10/2026 00:38 UTC | `d830a53488a8` |
| `eventspastleague_4501.json` | `eventspastleague.php?id=4501` | 200 | `events` = 1 | 2026-10: 1 | 15/10/2026 00:38 UTC | `17eabbfdb26f` |
| `eventsnextleague_4724.json` | `eventsnextleague.php?id=4724` | 200 | `events` = 1 | 2026-10: 1 | 15/10/2026 00:38 UTC | `106cd0d13a7d` |
| `eventspastleague_4724.json` | `eventspastleague.php?id=4724` | 200 | `events` = 1 | 2026-10: 1 | 15/10/2026 00:38 UTC | `7ef4b9e0a719` |
| `eventsround_4501_r400_s2025.json` | `eventsround.php?id=4501&r=400&s=2025` | 200 | `events` = 30 | 2025-02: 22, 2025-03: 8 | 15/10/2026 00:38 UTC | `450205f52891` |
| `eventsround_4501_r1_s2025.json` | `eventsround.php?id=4501&r=1&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:38 UTC | `d5cd125c7d05` |
| `eventsround_4501_r2_s2025.json` | `eventsround.php?id=4501&r=2&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:38 UTC | `ca514ca1acdd` |
| `eventsround_4501_r3_s2025.json` | `eventsround.php?id=4501&r=3&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:38 UTC | `0d0045f0e6a7` |
| `eventsround_4501_r4_s2025.json` | `eventsround.php?id=4501&r=4&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:38 UTC | `7eb58c2472cc` |
| `eventsround_4501_r5_s2025.json` | `eventsround.php?id=4501&r=5&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:38 UTC | `c474a6d2c124` |
| `eventsround_4501_r6_s2025.json` | `eventsround.php?id=4501&r=6&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:38 UTC | `0956344c92f8` |
| `eventsround_4501_r16_s2025.json` | `eventsround.php?id=4501&r=16&s=2025` | 200 | `events` = 16 | 2025-08: 16 | 15/10/2026 00:38 UTC | `e903b0437b08` |
| `eventsround_4501_r125_s2025.json` | `eventsround.php?id=4501&r=125&s=2025` | 200 | `events` = 8 | 2025-09: 8 | 15/10/2026 00:38 UTC | `cac377108ccd` |
| `eventsround_4501_r150_s2025.json` | `eventsround.php?id=4501&r=150&s=2025` | 200 | `events` = 4 | 2025-10: 4 | 15/10/2026 00:38 UTC | `e807ce1b75bf` |
| `eventsround_4501_r200_s2025.json` | `eventsround.php?id=4501&r=200&s=2025` | 200 | `events` = 1 | 2025-11: 1 | 15/10/2026 00:39 UTC | `f40fed114f5e` |
| `eventsround_4501_r1_s2026.json` | `eventsround.php?id=4501&r=1&s=2026` | 200 | `events` = 22 | 2026-02: 6, 2026-04: 16 | 15/10/2026 00:39 UTC | `fe32f0873b2a` |
| `eventsround_4501_r2_s2026.json` | `eventsround.php?id=4501&r=2&s=2026` | 200 | `events` = 32 | 2026-02: 16, 2026-04: 16 | 15/10/2026 00:39 UTC | `d0c309ccaf2c` |
| `eventsround_4501_r3_s2026.json` | `eventsround.php?id=4501&r=3&s=2026` | 200 | `events` = 24 | 2026-03: 8, 2026-04: 14, 2026-05: 2 | 15/10/2026 00:39 UTC | `292b9f837e30` |
| `eventsround_4501_r4_s2026.json` | `eventsround.php?id=4501&r=4&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:39 UTC | `60f042d019a2` |
| `eventsround_4501_r5_s2026.json` | `eventsround.php?id=4501&r=5&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:39 UTC | `5536a812daae` |
| `eventsround_4501_r6_s2026.json` | `eventsround.php?id=4501&r=6&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:39 UTC | `9514ab4242e3` |
| `eventsround_4501_r16_s2026.json` | `eventsround.php?id=4501&r=16&s=2026` | 200 | `events` = 16 | 2026-08: 16 | 15/10/2026 00:39 UTC | `a0a537314ab3` |
| `eventsround_4501_r125_s2026.json` | `eventsround.php?id=4501&r=125&s=2026` | 200 | `events` = 8 | 2026-09: 8 | 15/10/2026 00:39 UTC | `d3b05f28f3e2` |
| `eventsround_4501_r150_s2026.json` | `eventsround.php?id=4501&r=150&s=2026` | 200 | `events` = 4 | 2026-10: 4 | 15/10/2026 00:39 UTC | `cd3afa1f07e3` |
| `eventsround_4501_r200_s2026.json` | `eventsround.php?id=4501&r=200&s=2026` | 200 | `events` = null |  | 15/10/2026 00:39 UTC | `ac165cc3ca83` |
| `eventsround_4724_r400_s2025.json` | `eventsround.php?id=4724&r=400&s=2025` | 200 | `events` = 16 | 2025-03: 16 | 15/10/2026 00:39 UTC | `22b64460d634` |
| `eventsround_4724_r1_s2025.json` | `eventsround.php?id=4724&r=1&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:39 UTC | `58cb33dbc679` |
| `eventsround_4724_r2_s2025.json` | `eventsround.php?id=4724&r=2&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:39 UTC | `ea253c35db66` |
| `eventsround_4724_r3_s2025.json` | `eventsround.php?id=4724&r=3&s=2025` | 200 | `events` = 16 | 2025-04: 16 | 15/10/2026 00:39 UTC | `1c1571f1842c` |
| `eventsround_4724_r4_s2025.json` | `eventsround.php?id=4724&r=4&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:40 UTC | `02ee43d229d9` |
| `eventsround_4724_r5_s2025.json` | `eventsround.php?id=4724&r=5&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:40 UTC | `9a74c2b02137` |
| `eventsround_4724_r6_s2025.json` | `eventsround.php?id=4724&r=6&s=2025` | 200 | `events` = 16 | 2025-05: 16 | 15/10/2026 00:40 UTC | `b1a2a4dec446` |
| `eventsround_4724_r160_s2025.json` | `eventsround.php?id=4724&r=160&s=2025` | 200 | `events` = 16 | 2025-07: 16 | 15/10/2026 00:40 UTC | `3ed5215760d8` |
| `eventsround_4724_r16_s2025.json` | `eventsround.php?id=4724&r=16&s=2025` | 200 | `events` = 16 | 2025-08: 16 | 15/10/2026 00:40 UTC | `7ed73b6b011a` |
| `eventsround_4724_r125_s2025.json` | `eventsround.php?id=4724&r=125&s=2025` | 200 | `events` = 8 | 2025-09: 8 | 15/10/2026 00:40 UTC | `baecaea75e29` |
| `eventsround_4724_r150_s2025.json` | `eventsround.php?id=4724&r=150&s=2025` | 200 | `events` = 4 | 2025-10: 4 | 15/10/2026 00:40 UTC | `a463d5533863` |
| `eventsround_4724_r200_s2025.json` | `eventsround.php?id=4724&r=200&s=2025` | 200 | `events` = 1 | 2025-11: 1 | 15/10/2026 00:40 UTC | `1d1bb769d96f` |
| `eventsround_4724_r1_s2026.json` | `eventsround.php?id=4724&r=1&s=2026` | 200 | `events` = 32 | 2026-03: 16, 2026-04: 16 | 15/10/2026 00:40 UTC | `8a8e0c30c67c` |
| `eventsround_4724_r2_s2026.json` | `eventsround.php?id=4724&r=2&s=2026` | 200 | `events` = 16 | 2026-04: 16 | 15/10/2026 00:40 UTC | `98fb672bf00c` |
| `eventsround_4724_r3_s2026.json` | `eventsround.php?id=4724&r=3&s=2026` | 200 | `events` = 16 | 2026-04: 13, 2026-05: 3 | 15/10/2026 00:40 UTC | `24cd3f061c19` |
| `eventsround_4724_r4_s2026.json` | `eventsround.php?id=4724&r=4&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:40 UTC | `bf993d58d156` |
| `eventsround_4724_r5_s2026.json` | `eventsround.php?id=4724&r=5&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:40 UTC | `75ad9cf1d86d` |
| `eventsround_4724_r6_s2026.json` | `eventsround.php?id=4724&r=6&s=2026` | 200 | `events` = 16 | 2026-05: 16 | 15/10/2026 00:40 UTC | `ef6b872842ce` |
| `eventsround_4724_r32_s2026.json` | `eventsround.php?id=4724&r=32&s=2026` | 200 | `events` = 16 | 2026-07: 16 | 15/10/2026 00:40 UTC | `3c394aae4307` |
| `eventsround_4724_r16_s2026.json` | `eventsround.php?id=4724&r=16&s=2026` | 200 | `events` = 16 | 2026-08: 16 | 15/10/2026 00:41 UTC | `f2d5895de86c` |
| `eventsround_4724_r125_s2026.json` | `eventsround.php?id=4724&r=125&s=2026` | 200 | `events` = 8 | 2026-09: 8 | 15/10/2026 00:41 UTC | `3dd5d5ddb9c6` |
| `eventsround_4724_r150_s2026.json` | `eventsround.php?id=4724&r=150&s=2026` | 200 | `events` = 4 | 2026-10: 4 | 15/10/2026 00:41 UTC | `bd90998a7dbe` |
| `eventsround_4724_r200_s2026.json` | `eventsround.php?id=4724&r=200&s=2026` | 200 | `events` = null |  | 15/10/2026 00:41 UTC | `ac165cc3ca83` |
| `lookuptable_4501_s2026.json` | `lookuptable.php?l=4501&s=2026` | 200 | cuerpo vacío (0 bytes) |  | 15/10/2026 00:41 UTC | `e3b0c44298fc` |
| `lookuptable_4724_s2026.json` | `lookuptable.php?l=4724&s=2026` | 200 | cuerpo vacío (0 bytes) |  | 15/10/2026 00:41 UTC | `e3b0c44298fc` |
| `lookupevent_2399234.json` | `lookupevent.php?id=2399234` | 200 | `events` = 1 | 2026-02: 1 | 15/10/2026 00:41 UTC | `7c9b7cd24775` |
| `lookupevent_2405728.json` | `lookupevent.php?id=2405728` | 200 | `events` = 1 | 2026-02: 1 | 15/10/2026 00:41 UTC | `f14ffc5e8fd0` |
| `lookupevent_2600657.json` | `lookupevent.php?id=2600657` | 200 | `events` = 1 | 2026-09: 1 | 15/10/2026 00:41 UTC | `aa91a0aeb090` |
| `lookupevent_2478540.json` | `lookupevent.php?id=2478540` | 200 | `events` = 1 | 2026-08: 1 | 15/10/2026 00:41 UTC | `1378ef0869f0` |
| `lookupevent_2453080.json` | `lookupevent.php?id=2453080` | 200 | `events` = 1 | 2026-04: 1 | 15/10/2026 00:41 UTC | `8f65f5cd9fe4` |
| `lookupevent_2239192.json` | `lookupevent.php?id=2239192` | 200 | `events` = 1 | 2025-04: 1 | 15/10/2026 00:41 UTC | `3ebc4b1e8045` |
| `lookupevent_2453109.json` | `lookupevent.php?id=2453109` | 200 | `events` = 1 | 2026-05: 1 | 15/10/2026 00:42 UTC | `9f521455fd34` |
