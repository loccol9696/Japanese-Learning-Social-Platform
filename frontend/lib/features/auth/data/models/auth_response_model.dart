import 'user_model.dart';

class AuthResponseModel {
  final String? tokenType;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final UserModel? user;

  const AuthResponseModel({
    this.tokenType,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : (json['expiresIn'] != null ? int.tryParse(json['expiresIn'].toString()) : null),
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tokenType': tokenType,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
      'user': user?.toJson(),
    };
  }
}
