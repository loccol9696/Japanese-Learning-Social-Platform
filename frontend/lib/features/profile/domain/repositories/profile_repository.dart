import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile(UserProfileModel profile);
  Future<List<TopicModel>> getTopics();
}
