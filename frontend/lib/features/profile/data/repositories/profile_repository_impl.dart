import 'dart:typed_data';

import '../../domain/models/profile_video.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserProfileModel> getProfile() {
    return remoteDataSource.fetchProfile();
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel profile) {
    return remoteDataSource.updateProfile(profile);
  }

  @override
  Future<List<TopicModel>> getTopics() {
    return remoteDataSource.fetchTopics();
  }

  @override
  Future<ProfileStats> getStats() => remoteDataSource.fetchStats();

  @override
  Future<List<ProfileVideo>> getMyVideos() => remoteDataSource.fetchMyVideos();

  @override
  Future<List<ProfileVideo>> getSavedVideos() =>
      remoteDataSource.fetchSavedVideos();

  @override
  Future<List<ProfileVideo>> getLikedVideos() =>
      remoteDataSource.fetchLikedVideos();

  @override
  Future<String> uploadAvatar(Uint8List bytes, String filename) =>
      remoteDataSource.uploadAvatar(bytes, filename);
}
