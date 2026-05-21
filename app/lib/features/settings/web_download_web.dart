import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytesAsFile(List<int> bytes, String filename) {
  final array = Uint8List.fromList(bytes).toJS;
  final blob = web.Blob(
    <JSAny>[array].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', filename)
    ..click();
  web.URL.revokeObjectURL(url);
  anchor.remove();
}
