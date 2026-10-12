import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:http/http.dart' as http;

import '../helpers/recorded_app.dart';

void main() {
  testWidgets('HTTP 429: avisa la pausa mientras las consultas esperan', (
    tester,
  ) async {
    var limited = false;
    await pumpApp(
      tester,
      const Size(768, 1024),
      respond: (url) {
        // Solo la primera petición choca con el límite.
        if (limited) return null;
        limited = true;
        return http.Response('{"error": "Too Many Requests"}', 429);
      },
      settle: false,
    );
    // Las demás consultas esperan la pausa de 60 s.
    await tester.pump(const Duration(seconds: 1));

    // 17:00 + 60 s de pausa = 17:01 (hora argentina).
    const notice =
        'TheSportsDB pidió esperar por el límite de consultas. '
        'Se sigue a las 17:01.';
    expect(find.text(notice), findsOne);

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();

    expect(find.text(notice), findsNothing);
    expect(find.byType(MatchCard), findsWidgets);
  });
}
