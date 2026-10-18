import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/video/video_player_registration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerVideoPlayerWeb();
  runApp(const App());
}
