import 'package:media_kit/media_kit.dart';
import 'package:crispy_tivi/app/app.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(CrispyTiviApp());
}
