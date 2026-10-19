import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../../video/domain/models/user_video_model.dart';

abstract class ProfileRepository {
  Future<UserProfileModel> getProfile({int? userId});
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId});
  Future<List<TopicModel>> getTopics();
  Future<List<UserVideoModel>> getUserVideos({int? userId});
  Future<List<UserVideoModel>> getMyVideosStatus();
  Future<List<UserVideoModel>> getLikedVideos();
  Future<List<UserVideoModel>> getSavedVideos();
  Future<List<UserVideoModel>> getModerationVideos({String status = 'PENDING'});
  Future<void> approveVideo(int videoId);
  Future<void> rejectVideo(int videoId, String reason);
}
