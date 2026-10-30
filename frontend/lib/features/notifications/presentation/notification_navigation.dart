import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../chat/presentation/screens/shared_video_screen.dart';
import '../data/models/notification_models.dart';

/// Mở màn hình ứng với thông báo: video bị từ chối thì mở màn trạng thái video
/// (xem lý do và gửi lại), các loại còn lại mở thẳng video; thông báo bình luận mở
/// sẵn bảng bình luận.
Future<void> openNotificationTarget(
  BuildContext context,
  NotificationTarget target,
) async {
  final navigator = Navigator.of(context);
  if (target.type == NotificationType.videoRejected) {
    await navigator.pushNamed(AppRoutes.myVideosStatus);
    return;
  }
  final videoId = target.videoId;
  if (videoId == null) return;
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => SharedVideoScreen(
        videoId: videoId,
        openComments: target.type == NotificationType.videoCommented,
      ),
    ),
  );
}
