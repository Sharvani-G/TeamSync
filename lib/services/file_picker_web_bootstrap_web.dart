import 'package:file_picker/src/platform/web/file_picker_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter/foundation.dart';

var _filePickerWebRegistered = false;

void ensureFilePickerWebInitialized() {
  if (_filePickerWebRegistered) {
    return;
  }

  debugPrint('Initializing file_picker web platform');
  FilePickerWeb.registerWith(Registrar());
  _filePickerWebRegistered = true;
}
