import '../models/profile_video.dart';
import '../models/topic_model.dart';
import '../models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile(UserProfileModel profile);
  Future<List<TopicModel>> getTopics();
  Future<ProfileStats> getStats();
  Future<List<ProfileVideo>> getMyVideos();
  Future<List<ProfileVideo>> getSavedVideos();
  Future<List<ProfileVideo>> getLikedVideos();
}
