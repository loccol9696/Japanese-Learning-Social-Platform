import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserProfileModel> getProfile({int? userId}) {
    return remoteDataSource.fetchProfile(userId: userId);
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId}) {
    return remoteDataSource.updateProfile(profile, userId: userId);
  }

  @override
  Future<List<TopicModel>> getTopics() {
    return remoteDataSource.fetchTopics();
  }
}
