import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<UserProfileModel> getProfile({int? userId});
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId});
  Future<List<TopicModel>> getTopics();
}
