import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Descarga [content] como archivo desde el navegador (Blob + enlace).
bool downloadTextFile({
  required String fileName,
  required String mimeType,
  required String content,
}) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
  return true;
}
