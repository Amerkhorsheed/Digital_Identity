import 'package:flutter/widgets.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 64 * 1024 * 1024;
  runApp(const ADigitalIdApp());
}
