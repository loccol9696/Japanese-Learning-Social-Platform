import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/interest_tags_selector.dart';
import '../widgets/jlpt_level_selector.dart';

class ProfileUpdateScreen extends StatefulWidget {
  final ProfileRepository? repository;
  final bool isTab;

  const ProfileUpdateScreen({
    super.key,
    this.repository,
    this.isTab = false,
  });

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  /// Xanh dương nhạt cho liên kết "Đổi ảnh đại diện".
  static Color get _linkBlue => AppPalette.info;

  late final ProfileRepository _repository;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  Uint8List? _localAvatarBytes;

  UserProfileModel _profile = const UserProfileModel();
  List<TopicModel> _availableTopics = [];
  String _selectedAvatarUrl = '';
  String _selectedLevel = 'N5';
  List<String> _selectedInterests = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait([
      _repository.getProfile(),
      _repository.getTopics(),
    ]);

    if (!mounted) return;

    final profile = results[0] as UserProfileModel;
    final topics = results[1] as List<TopicModel>;

    setState(() {
      _profile = profile;
      _availableTopics = topics;
      _selectedAvatarUrl = profile.avatarUrl;
      _selectedLevel = profile.currentLevel;
      _selectedInterests = List<String>.from(profile.interests);
      _displayNameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _isLoading = false;
    });
  }

  Future<void> _pickImageFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && !kIsWeb && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null) {
        return;
      }

      setState(() {
        _localAvatarBytes = bytes;
        _isUploadingAvatar = true;
      });

      // Upload to Cloudinary media endpoint
      try {
        final uri = Uri.parse('${ApiConstants.baseUrl}/media/upload?folder=jlsp/avatars');
        // ApiClient tự gắn access token (API upload yêu cầu đăng nhập).
        final imageBytes = bytes;
        final response = await ApiClient.instance.sendMultipart(
          () => http.MultipartRequest('POST', uri)
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                imageBytes,
                filename: file.name.isNotEmpty ? file.name : 'avatar.png',
              ),
            ),
          timeout: const Duration(seconds: 60),
        );

        {
          final data = ApiClient.decodeResponse(response);
          final uploadedUrl = data is Map
              ? (data['secureUrl'] ?? data['url']) as String?
              : null;

          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _selectedAvatarUrl = uploadedUrl;
              _isUploadingAvatar = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Đã tải ảnh lên thành công!'),
                  ],
                ),
                backgroundColor: AppColors.surfaceContainerHigh,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        }
      } catch (uploadErr) {
        debugPrint('[ProfileUpdateScreen] Cloud upload error: $uploadErr');
      }

      // Fallback: encode as base64 data URI so it can be saved and displayed anywhere
      if (!mounted) return;
      final extension = file.extension ?? 'png';
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/$extension;base64,$base64String';
      setState(() {
        _selectedAvatarUrl = dataUri;
        _isUploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Text('Đã chọn ảnh từ thiết bị!'),
            ],
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AvatarPickerSheet(
          currentAvatarUrl: _selectedAvatarUrl,
          onAvatarSelected: (newUrl) {
            setState(() {
              _selectedAvatarUrl = newUrl;
              _localAvatarBytes = null;
            });
          },
          onPickFromDevice: _pickImageFromDevice,
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final selectedTopicModels = _availableTopics
        .where((t) => _selectedInterests.contains(t.name))
        .toList();

    final updated = _profile.copyWith(
      displayName: _displayNameController.text.trim(),
      avatarUrl: _selectedAvatarUrl,
      currentLevel: _selectedLevel,
      bio: _bioController.text.trim(),
      topics: selectedTopicModels,
      interests: _selectedInterests,
    );

    try {
      final savedProfile = await _repository.updateProfile(updated);
      if (!mounted) return;

      setState(() {
        _profile = savedProfile;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  appStrings.profileUpdatedSuccessfully,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          duration: const Duration(seconds: 2),
        ),
      );

      // Thoát khỏi màn hình cập nhật và điều hướng về trang cá nhân
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appStrings.updateFailed),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppPalette.accent),
          )
        : Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 24.0),
              children: [
                _buildAvatarSection(),
                const SizedBox(height: 28.0),
                _buildDisplayNameField(),
                const SizedBox(height: 20.0),
                _buildUsernameField(),
                const SizedBox(height: 24.0),
                JlptLevelSelector(
                  selectedLevel: _selectedLevel,
                  onLevelSelected: (lvl) {
                    setState(() {
                      _selectedLevel = lvl;
                    });
                  },
                ),
                const SizedBox(height: 24.0),
                InterestTagsSelector(
                  availableTopics: _availableTopics,
                  selectedInterests: _selectedInterests,
                  onInterestsChanged: (tags) {
                    setState(() {
                      _selectedInterests = tags;
                    });
                  },
                ),
              ],
            ),
          );

    if (widget.isTab) {
      return Container(
        color: AppPalette.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                child: _buildTitle(),
              ),
              Expanded(child: content),
              _buildSaveBar(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppPalette.textPrimary,
                  size: 18.0,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: _buildTitle(),
      ),
      body: SafeArea(child: content),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  Widget _buildTitle() {
    return Text(
      appStrings.editProfile,
      style: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w700,
        color: AppPalette.textPrimary,
      ),
    );
  }

  Widget _buildAvatarSection() {
    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : (_profile.displayName.isNotEmpty
              ? _profile.displayName
              : _profile.username);
    final initial = displayName.isEmpty
        ? '?'
        : String.fromCharCode(displayName.runes.first).toUpperCase();

    ImageProvider? avatarImage;
    if (_localAvatarBytes != null) {
      avatarImage = MemoryImage(_localAvatarBytes!);
    } else if (_selectedAvatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(_selectedAvatarUrl);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingAvatar ? null : _openAvatarPicker,
          child: CircleAvatar(
            radius: 36.0,
            backgroundColor: AppPalette.surface,
            backgroundImage: avatarImage,
            onBackgroundImageError: avatarImage == null
                ? null
                : (context, error) {},
            child: _isUploadingAvatar
                ? SizedBox(
                    width: 24.0,
                    height: 24.0,
                    child: CircularProgressIndicator(
                      color: AppPalette.textPrimary,
                      strokeWidth: 2.5,
                    ),
                  )
                : (avatarImage == null
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 30.0,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null),
          ),
        ),
        const SizedBox(height: 12.0),
        GestureDetector(
          onTap: _isUploadingAvatar ? null : _openAvatarPicker,
          child: Text(
            'Đổi ảnh đại diện',
            style: TextStyle(
              color: _linkBlue,
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.0,
          color: AppPalette.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(appStrings.displayName),
        TextFormField(
          controller: _displayNameController,
          cursorColor: AppPalette.accent,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: appStrings.displayNamePlaceholder,
            hintStyle: TextStyle(color: AppPalette.textSecondary),
            filled: true,
            fillColor: AppPalette.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 15.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: AppPalette.accent,
                width: 1.5,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Tên hiển thị không được để trống';
            }
            if (value.trim().length > 100) {
              return 'Tên hiển thị không được quá 100 ký tự';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Tên người dùng không đổi được: hiển thị dạng chỉ đọc.
  Widget _buildUsernameField() {
    if (_profile.username.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Tên người dùng'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
          decoration: BoxDecoration(
            color: AppPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '@ ',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
                TextSpan(
                  text: _profile.username,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      ],
    );
  }

  /// Nút lưu cố định ở đáy màn hình, có đường kẻ mảnh phía trên.
  Widget _buildSaveBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background,
        border: Border(top: BorderSide(color: AppPalette.surface)),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 14.0),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              disabledBackgroundColor: AppPalette.accent.withValues(alpha: 0.6),
              foregroundColor: AppPalette.onAccent,
              disabledForegroundColor: AppPalette.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        appStrings.saving,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Text(
                    appStrings.saveChanges,
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
