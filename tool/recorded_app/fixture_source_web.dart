import 'package:http/http.dart' as http;

/// Web: los JSON servidos junto a la app (`build/web/fixtures/`).
Future<List<int>?> readFixture(String name) async {
  final response = await http.get(Uri.base.resolve('fixtures/$name.json'));
  return response.statusCode == 200 ? response.bodyBytes : null;
}
