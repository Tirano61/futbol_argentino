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
