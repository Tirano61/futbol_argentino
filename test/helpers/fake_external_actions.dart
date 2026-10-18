import 'package:futbol_argentino/core/calendar/calendar_event.dart';
import 'package:futbol_argentino/core/platform/external_actions.dart';

/// Registra lo que la pantalla pide compartir, agendar o abrir y responde
/// con [shareOutcome] / [calendarOutcome] / [linkOpens].
class FakeExternalActions implements ExternalActions {
  FakeExternalActions({
    this.shareOutcome = ShareOutcome.shared,
    this.calendarOutcome = CalendarOutcome.opened,
    this.linkOpens = true,
  });

  final ShareOutcome shareOutcome;
  final CalendarOutcome calendarOutcome;
  final bool linkOpens;
  final shared = <({String text, String? subject})>[];
  final events = <({CalendarEvent event, String fileName})>[];
  final links = <Uri>[];

  @override
  Future<ShareOutcome> share(String text, {String? subject}) async {
    shared.add((text: text, subject: subject));
    return shareOutcome;
  }

  @override
  Future<CalendarOutcome> addToCalendar(
    CalendarEvent event, {
    required String fileName,
  }) async {
    events.add((event: event, fileName: fileName));
    return calendarOutcome;
  }

  @override
  Future<bool> openLink(Uri uri) async {
    links.add(uri);
    return linkOpens;
  }
}
