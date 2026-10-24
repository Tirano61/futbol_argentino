import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/shell/rate_limit_notice.dart';
import 'package:futbol_argentino/app/theme/app_theme.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/rate_limit_status.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/observed_sync_scheduler.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/shared/presentation/widgets/info_banner.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/text_layout.dart';

/// Reloj del tiempo simulado de `pump` (17:00 de Argentina al empezar).
class _PumpedClock implements Clock {
  _PumpedClock(this._tester) : _origin = _tester.binding.clock.now();

  final WidgetTester _tester;
  final DateTime _origin;

  @override
  DateTime now() => DateTime.utc(
    2026,
    10,
    11,
    20,
  ).add(_tester.binding.clock.now().difference(_origin));
}

const throttleText =
    'Muchas consultas seguidas: para no pasar el límite de TheSportsDB, se '
    'sigue en menos de un minuto.';

/// Fase R3: la recuperación automática dice a qué hora se reintenta.
String recoveryText(String time) =>
    'Límite temporal de consultas de TheSportsDB. Se reintentará '
    'automáticamente a las $time.';

/// Fase R3: el scheduler dejó de reintentar; no se promete otro intento.
const exhaustedText =
    'Demasiadas consultas: no fue posible completar la actualización. '
    'Probá de nuevo en unos minutos.';

/// Fase R3.1: bloqueo persistente con algo pendiente: un último intento.
String lastAttemptText(String time) =>
    'TheSportsDB sigue limitando las consultas. Último intento automático '
    'a las $time.';

/// Fase R3.1: hay una pausa pero nada la espera: no se promete nada.
String idleText(String time) =>
    'Límite temporal de consultas de TheSportsDB hasta las $time.';

/// Versiones cortas: con texto grande en un teléfono, el texto completo
/// pasa de 4 renglones.
String compactLastAttemptText(String time) =>
    'Límite persistente. Último intento a las $time.';
String compactRecoveryText(String time) =>
    'Límite de TheSportsDB. Reintento automático a las $time.';
const compactExhaustedText =
    'Demasiadas consultas. Probá de nuevo en unos minutos.';
const compactThrottleText =
    'Muchas consultas seguidas: se sigue en menos de un minuto.';

void main() {
  setUpAll(loadRealFonts);

  late _PumpedClock clock;
  late RateLimiter limiter;
  late ObservedSyncScheduler scheduler;

  Future<void> pumpNotice(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    clock = _PumpedClock(tester);
    // Tope de 2 por minuto para llegar enseguida a la espera.
    limiter = RateLimiter(maxRequests: 2, clock: clock);
    scheduler = ObservedSyncScheduler(clock: clock, rateLimit: limiter);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RateLimitStatus>.value(value: limiter),
          RepositoryProvider<RateLimitRecovery>.value(value: scheduler),
          RepositoryProvider<Clock>.value(value: clock),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const RateLimitNotice(child: Scaffold(body: Text('contenido'))),
        ),
      ),
    );
  }

  /// Un trabajo del scheduler cuya consulta responde 429 las primeras
  /// [failures] veces (como el cliente: avisa al limitador y falla) y
  /// después sale bien. Devuelve el futuro del trabajo y sus intentos.
  ({Future<void> done, List<DateTime> attempts}) runJob(
    String key, {
    int failures = 1,
    CancelToken? cancelToken,
    void Function()? onFailure,
  }) {
    final attempts = <DateTime>[];
    final done = scheduler.run(key, SyncPriority.visible, () async {
      attempts.add(clock.now());
      if (attempts.length > failures) return;
      limiter.rateLimited(sentAt: clock.now());
      onFailure?.call();
      throw const RateLimitFailure(detail: 'HTTP 429');
    }, cancelToken: cancelToken);
    done.ignore();
    return (done: done, attempts: attempts);
  }

  /// Deja llegar los avisos del limitador y del scheduler (streams).
  Future<void> settleStreams(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('avisa la espera por el tope propio mientras dura', (
    tester,
  ) async {
    await pumpNotice(tester);
    var done = 0;
    for (var i = 0; i < 3; i++) {
      unawaited(limiter.acquire().then((_) => done++));
    }
    await tester.pump();

    expect(done, 2, reason: 'la tercera espera 1 min');
    expect(find.text(throttleText), findsOne);
    expect(find.text('contenido'), findsOne);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text(throttleText), findsOne);

    await tester.pump(const Duration(seconds: 1));
    expect(done, 3);
    expect(find.text(throttleText), findsNothing);
  });

  testWidgets('un 429 avisa a qué hora se reintenta y se recupera solo', (
    tester,
  ) async {
    await pumpNotice(tester);
    final job = runJob('ronda');
    await settleStreams(tester);

    // 17:00 + 60 s de pausa.
    expect(find.text(recoveryText('17:01')), findsOne);
    expect(find.byIcon(Icons.hourglass_top), findsOne);
    expect(find.text('contenido'), findsOne);
    // Sin cuenta regresiva: mientras espera no se redibuja nada.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(seconds: 59));
    await job.done;
    expect(job.attempts, hasLength(2));
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('la hora cambia si la pausa se alarga o se repite', (
    tester,
  ) async {
    await pumpNotice(tester);
    final job = runJob('ronda', failures: 2);
    await settleStreams(tester);
    expect(find.text(recoveryText('17:01')), findsOne);

    // Un `Retry-After` más largo a las 17:00:30: hasta las 17:02.
    await tester.pump(const Duration(seconds: 30));
    limiter.pauseFor(const Duration(seconds: 90));
    await settleStreams(tester);
    expect(find.text(recoveryText('17:02')), findsOne);
    expect(find.textContaining('17:01'), findsNothing);

    // 17:02: el reintento vuelve a dar 429 y la pausa sube a 120 s.
    await tester.pump(const Duration(seconds: 90));
    await settleStreams(tester);
    expect(job.attempts, hasLength(2));
    expect(find.text(recoveryText('17:04')), findsOne);
    expect(find.text(exhaustedText), findsNothing);

    await tester.pump(const Duration(minutes: 2));
    await job.done;
    expect(job.attempts, hasLength(3));
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('agotados los reintentos no promete otro intento automático; '
      'una pausa posterior con reintento vuelve a avisarlo', (tester) async {
    await pumpNotice(tester);
    final job = runJob('ronda', failures: 99);
    await settleStreams(tester);
    expect(find.text(recoveryText('17:01')), findsOne);

    // 17:01: segundo 429, pausa de 120 s.
    await tester.pump(const Duration(minutes: 1));
    await settleStreams(tester);
    expect(find.text(recoveryText('17:03')), findsOne);

    // 17:03: tercer 429 (pausa de 240 s, hasta las 17:07); el scheduler
    // deja de reintentar y la pantalla recibe el error.
    await tester.pump(const Duration(minutes: 2));
    await settleStreams(tester);
    await expectLater(job.done, throwsA(isA<RateLimitFailure>()));
    expect(job.attempts, hasLength(3));
    expect(find.text(exhaustedText), findsOne);
    expect(find.textContaining('reintentará'), findsNothing);
    expect(find.byIcon(Icons.sync_problem), findsOne);

    // 17:07:10, dentro de la ventana sin reintentos que sigue: un 429 abre
    // otra pausa, pero tampoco se reintenta.
    await tester.pump(const Duration(minutes: 4, seconds: 10));
    expect(find.byType(InfoBanner), findsNothing);
    final inWindow = runJob('otra');
    await settleStreams(tester);
    await expectLater(inWindow.done, throwsA(isA<RateLimitFailure>()));
    expect(inWindow.attempts, hasLength(1));
    expect(find.text(exhaustedText), findsOne);

    // 17:11:10 + 1 min: pasó la ventana; el 429 siguiente se reintenta.
    await tester.pump(const Duration(minutes: 5, seconds: 10));
    final next = runJob('siguiente');
    await settleStreams(tester);
    // 17:12:20 + 240 s (el limitador sigue en el escalón más alto).
    expect(find.text(recoveryText('17:16')), findsOne);
    expect(find.text(exhaustedText), findsNothing);
    await tester.pump(const Duration(minutes: 4));
    await next.done;
    expect(next.attempts, hasLength(2));
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('un trabajo cancelado no cuenta como reintentos agotados', (
    tester,
  ) async {
    await pumpNotice(tester);
    final token = CancelToken();
    final job = runJob('ronda', cancelToken: token, onFailure: token.cancel);
    await settleStreams(tester);
    await expectLater(job.done, throwsA(isA<RateLimitFailure>()));
    await settleStreams(tester);

    // Nada espera la pausa: ni promesa ni fracaso (Fase R3.1).
    expect(find.text(idleText('17:01')), findsOne);
    expect(find.text(exhaustedText), findsNothing);
    expect(find.textContaining('reintentará'), findsNothing);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('Fase R3.1: con el bloqueo persistente y algo pendiente, '
      '«último intento»; si la sonda falla, el aviso de agotado', (
    tester,
  ) async {
    await pumpNotice(tester);
    final first = runJob('a', failures: 99);
    await settleStreams(tester);
    // Llega otra pantalla durante la pausa.
    final second = runJob('b', failures: 99);
    await settleStreams(tester);
    expect(find.text(recoveryText('17:01')), findsOne);

    // 17:01: segundo 429 (de a uno: sale solo «a»).
    await tester.pump(const Duration(minutes: 1));
    await settleStreams(tester);
    expect(find.text(recoveryText('17:03')), findsOne);
    expect(second.attempts, isEmpty);

    // 17:03: tercer 429 seguido: «a» se rinde, el bloqueo queda confirmado
    // y «b» espera un último intento.
    await tester.pump(const Duration(minutes: 2));
    await settleStreams(tester);
    await expectLater(first.done, throwsA(isA<RateLimitFailure>()));
    expect(find.text(lastAttemptText('17:07')), findsOne);
    expect(find.byIcon(Icons.hourglass_bottom), findsOne);
    expect(find.text(exhaustedText), findsNothing);

    // 17:07: la sonda («b») vuelve a dar 429: no queda nada pendiente.
    await tester.pump(const Duration(minutes: 4));
    await settleStreams(tester);
    await expectLater(second.done, throwsA(isA<RateLimitFailure>()));
    expect(second.attempts, hasLength(1));
    expect(find.text(exhaustedText), findsOne);
    expect(find.textContaining('intento'), findsNothing);
    await tester.pump(const Duration(minutes: 5));
  });

  testWidgets('Fase R3.1: uno se rinde por una pausa larga y otro espera: '
      'se promete el reintento, no el fracaso', (tester) async {
    await pumpNotice(tester);
    final long = runJob(
      'largo',
      onFailure: () => limiter.pauseFor(const Duration(minutes: 6)),
    );
    final other = runJob('otro', failures: 0);
    await settleStreams(tester);
    await expectLater(long.done, throwsA(isA<RateLimitFailure>()));
    await settleStreams(tester);

    expect(find.text(recoveryText('17:06')), findsOne);
    expect(find.text(exhaustedText), findsNothing);

    await tester.pump(const Duration(minutes: 6));
    await other.done;
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('la pausa por 429 tiene prioridad sobre la espera por el tope', (
    tester,
  ) async {
    await pumpNotice(tester);
    for (var i = 0; i < 3; i++) {
      unawaited(limiter.acquire());
    }
    await tester.pump(const Duration(seconds: 10));
    expect(find.text(throttleText), findsOne);

    // 17:00:10 + 20 s: la pausa termina antes que la espera por el tope.
    limiter.pauseFor(const Duration(seconds: 20));
    // La pausa llega por un stream después del cuadro: otro para dibujarla.
    await settleStreams(tester);
    expect(find.text(idleText('17:00')), findsOne);
    expect(find.text(throttleText), findsNothing);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text(idleText('17:00')), findsNothing);
    expect(find.text(throttleText), findsOne);

    await tester.pump(const Duration(seconds: 30));
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
  });

  group('accesibilidad', () {
    /// Lleva el aviso a la recuperación o, con [exhausted], al estado de
    /// reintentos agotados (pausa de más de 5 min: no se reintenta).
    /// Bloqueo confirmado con un trabajo pendiente: «último intento».
    Future<String> showLastAttempt(WidgetTester tester) async {
      runJob('a', failures: 99);
      await settleStreams(tester);
      runJob('b', failures: 99);
      await tester.pump(const Duration(minutes: 1));
      await settleStreams(tester);
      await tester.pump(const Duration(minutes: 2));
      await settleStreams(tester);
      return lastAttemptText('17:07');
    }

    Future<String> showNotice(WidgetTester tester, {bool exhausted = false}) {
      if (exhausted) {
        runJob(
          'ronda',
          onFailure: () => limiter.pauseFor(const Duration(minutes: 6)),
        );
      } else {
        runJob('ronda');
      }
      return settleStreams(
        tester,
      ).then((_) => exhausted ? exhaustedText : recoveryText('17:01'));
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('tema ${mode.name}, último intento: contraste y nombres', (
        tester,
      ) async {
        await pumpNotice(tester, themeMode: mode);
        final text = await showLastAttempt(tester);
        expect(find.text(text), findsOne);
        await expectGuidelines(tester);
        await tester.pump(const Duration(minutes: 10));
      });
      for (final exhausted in [false, true]) {
        final state = exhausted ? 'agotado' : 'recuperación';
        testWidgets('tema ${mode.name}, $state: contraste, nombres y '
            'anuncio a los lectores de pantalla', (tester) async {
          await pumpNotice(tester, themeMode: mode);
          final text = await showNotice(tester, exhausted: exhausted);
          expect(find.text(text), findsOne);

          await expectGuidelines(tester);
          final node = tester.getSemantics(find.text(text));
          expect(node.label, text);
          final banner = tester.renderObject(
            find
                .descendant(
                  of: find.byType(InfoBanner),
                  matching: find.byType(Semantics),
                )
                .first,
          );
          expect(
            (banner as RenderSemanticsAnnotations).properties.liveRegion,
            isTrue,
          );
          await tester.pump(const Duration(minutes: 7));
        });
      }
    }

    testWidgets('tema claro: la espera por el tope se lee (contraste)', (
      tester,
    ) async {
      await pumpNotice(tester);
      for (var i = 0; i < 3; i++) {
        unawaited(limiter.acquire());
      }
      await tester.pump();
      expect(find.text(throttleText), findsOne);
      await expectGuidelines(tester);
      await tester.pump(const Duration(minutes: 1));
    });

    // Teléfonos de 360 y 411 dp con el texto al 200 %: palabras enteras y
    // un aviso que deja lugar al contenido. Si el texto completo pasa de 4
    // renglones se ve la versión corta; los lectores leen el completo.
    for (final (width, state, shown) in [
      (360.0, 'recuperación', compactRecoveryText('17:01')),
      (360.0, 'agotado', compactExhaustedText),
      (360.0, 'tope propio', compactThrottleText),
      (360.0, 'último intento', compactLastAttemptText('17:07')),
      (411.0, 'recuperación', compactRecoveryText('17:01')),
      (411.0, 'último intento', lastAttemptText('17:07')),
      (411.0, 'agotado', exhaustedText),
      (411.0, 'tope propio', compactThrottleText),
    ]) {
      testWidgets('${width.toInt()} dp al 200 %, $state: «$shown»', (
        tester,
      ) async {
        tester.view
          ..physicalSize = Size(width, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpNotice(tester);
        final String full;
        if (state == 'tope propio') {
          for (var i = 0; i < 3; i++) {
            unawaited(limiter.acquire());
          }
          await tester.pump();
          full = throttleText;
        } else if (state == 'último intento') {
          full = await showLastAttempt(tester);
        } else {
          full = await showNotice(tester, exhausted: state == 'agotado');
        }

        final banner = find.byType(InfoBanner);
        expect(find.text(shown), findsOne);
        expect(find.bySemanticsLabel(full), findsOne);
        expectWholeWords(tester, banner);
        final paragraph = paragraphsIn(
          banner,
        ).singleWhere((p) => p.text.toPlainText() == shown);
        final lines = linesOf(
          paragraph,
          0,
          paragraph.text.toPlainText().length,
        ).length;
        expect(lines, lessThanOrEqualTo(InfoBanner.compactAfterLines));
        expect(tester.getSize(banner).height, lessThan(640 * 0.3));
        expect(
          tester.getRect(find.text('contenido')).top,
          greaterThanOrEqualTo(tester.getRect(banner).bottom),
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(minutes: 7));
      });
    }

    testWidgets('768 px al 200 %: entra el texto completo', (tester) async {
      tester.view
        ..physicalSize = const Size(768, 1024)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpNotice(tester);
      final text = await showNotice(tester);
      expect(find.text(text), findsOne);
      await tester.pump(const Duration(minutes: 2));
    });
  });
}
