import 'package:video_player_web/video_player_web.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void registerVideoPlayerWeb() {
  VideoPlayerPlatform.instance = VideoPlayerPlugin();
}
