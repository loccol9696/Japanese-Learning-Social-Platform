import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/topic_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/interest_tags_selector.dart';
import '../widgets/jlpt_level_selector.dart';

/// Sửa hồ sơ (cùng phong cách tối với màn Profile). Lưu thành công -> quay lại.
class ProfileUpdateScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const ProfileUpdateScreen({super.key, this.repository});

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  // Giới hạn trùng với UpdateUserRequest ở backend.
  static const int _maxDisplayName = 100;
  static const int _maxBio = 500;

  late final ProfileRepository _repository;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  bool _isLoading = true;
  bool _isSaving = false;

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

  // Hồ sơ không có id = không tải được (offline, chưa có bản lưu): không cho lưu đè lên server.
  bool get _loadFailed => !_isLoading && _profile.id == null;

  Future<void> _loadData() async {
    if (!_isLoading) setState(() => _isLoading = true);
    final results = await Future.wait([
      _repository.getProfile(),
      _repository.getTopics(),
    ]);
    if (!mounted) return;

    final profile = results[0] as UserProfileModel;
    setState(() {
      _profile = profile;
      _availableTopics = results[1] as List<TopicModel>;
      _selectedAvatarUrl = profile.avatarUrl;
      _selectedLevel = profile.currentLevel;
      _selectedInterests = List<String>.from(profile.interests);
      _displayNameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _isLoading = false;
    });
  }

  void _openAvatarPicker() {
    showAvatarPickerSheet(
      context,
      currentAvatarUrl: _selectedAvatarUrl,
      onAvatarSelected: (url) => setState(() => _selectedAvatarUrl = url),
      onUpload: _repository.uploadAvatar,
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = _profile.copyWith(
      displayName: _displayNameController.text.trim(),
      avatarUrl: _selectedAvatarUrl,
      currentLevel: _selectedLevel,
      bio: _bioController.text.trim(),
      topics: _availableTopics.where((t) => _selectedInterests.contains(t.name)).toList(),
      interests: _selectedInterests,
    );

    try {
      await _repository.updateProfile(updated);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(appStrings.profileUpdatedSuccessfully),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appStrings.updateFailed),
          backgroundColor: AppColors.socialRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.socialBackground,
      appBar: AppBar(
        backgroundColor: AppColors.socialBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20.0),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          appStrings.profileEdit,
          style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white70),
                    ),
                  )
                : TextButton(
                    onPressed: _isLoading || _loadFailed ? null : _saveProfile,
                    style: TextButton.styleFrom(foregroundColor: AppColors.socialCyan),
                    child: Text(
                      appStrings.save,
                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(height: 1.0, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.socialTextMuted))
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appStrings.profileLoadFailed,
                    style: const TextStyle(color: Colors.white, fontSize: 15.0),
                  ),
                  const SizedBox(height: 12.0),
                  OutlinedButton(
                    onPressed: _loadData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.socialDivider),
                    ),
                    child: Text(appStrings.profileRetry),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 32.0),
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 28.0),
                  _SectionLabel(appStrings.displayName),
                  _buildTextField(
                    controller: _displayNameController,
                    hint: appStrings.displayNamePlaceholder,
                    maxLength: _maxDisplayName,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? appStrings.displayNameRequired
                        : null,
                  ),
                  const SizedBox(height: 20.0),
                  _SectionLabel(appStrings.bio),
                  _buildTextField(
                    controller: _bioController,
                    hint: appStrings.bioPlaceholder,
                    maxLength: _maxBio,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20.0),
                  _SectionLabel(appStrings.selectJlptLevel),
                  JlptLevelSelector(
                    selectedLevel: _selectedLevel,
                    onLevelSelected: (level) => setState(() => _selectedLevel = level),
                  ),
                  const SizedBox(height: 28.0),
                  _SectionLabel(appStrings.selectInterests, hint: appStrings.interestsHint),
                  InterestTagsSelector(
                    availableTopics: _availableTopics,
                    selectedInterests: _selectedInterests,
                    onInterestsChanged: (list) => setState(() => _selectedInterests = list),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final url = _selectedAvatarUrl;
    return Column(
      children: [
        GestureDetector(
          onTap: _openAvatarPicker,
          child: CircleAvatar(
            radius: 48.0,
            backgroundColor: AppColors.socialSurface,
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            onBackgroundImageError: url.isNotEmpty ? (_, _) {} : null,
            child: url.isEmpty
                ? const Icon(Icons.person_rounded, size: 48.0, color: AppColors.socialTextMuted)
                : null,
          ),
        ),
        TextButton(
          onPressed: _openAvatarPicker,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: Text(
            appStrings.changeAvatar,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15.0),
      cursorColor: AppColors.socialCyan,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.socialTextMuted),
        filled: true,
        fillColor: AppColors.socialSurface,
        counterStyle: const TextStyle(color: AppColors.socialTextMuted, fontSize: 11.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.socialCyan),
        errorBorder: border(AppColors.socialRed),
        focusedErrorBorder: border(AppColors.socialRed),
      ),
    );
  }
}

/// Nhãn của một mục, có thể kèm dòng gợi ý nhỏ.
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? hint;

  const _SectionLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2.0),
            Text(
              hint!,
              style: const TextStyle(color: AppColors.socialTextMuted, fontSize: 12.0),
            ),
          ],
        ],
      ),
    );
  }
}
