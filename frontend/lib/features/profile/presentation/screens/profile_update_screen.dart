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
            });
          },
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
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
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
    if (widget.isTab) {
      return Container(
        color: AppColors.backgroundCanvas,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Top Header for Tab
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appStrings.profileTitle,
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18.0,
                              height: 18.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: AppColors.periwinkle,
                              ),
                            )
                          : Text(
                              appStrings.saveChanges,
                              style: const TextStyle(
                                color: AppColors.periwinkle,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.periwinkle),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          children: [
                            _buildAvatarSection(),
                            const SizedBox(height: 24.0),
                            _buildDisplayNameField(),
                            const SizedBox(height: 20.0),
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
                            const SizedBox(height: 24.0),
                            _buildBioField(),
                            const SizedBox(height: 24.0),
                            _buildSaveButtonContent(),
                            const SizedBox(height: 120.0),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCanvas,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.onSurface, size: 20.0),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          appStrings.editProfile,
          style: const TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: AppColors.periwinkle,
                    ),
                  )
                : Text(
                    appStrings.saveChanges,
                    style: const TextStyle(
                      color: AppColors.periwinkle,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.periwinkle),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  children: [
                    // 1. Avatar Section
                    _buildAvatarSection(),
                    const SizedBox(height: 24.0),

                    // 2. Display Name Input
                    _buildDisplayNameField(),
                    const SizedBox(height: 20.0),

                    // 3. JLPT Level Selector
                    JlptLevelSelector(
                      selectedLevel: _selectedLevel,
                      onLevelSelected: (lvl) {
                        setState(() {
                          _selectedLevel = lvl;
                        });
                      },
                    ),
                    const SizedBox(height: 24.0),

                    // 4. Interests / Topics Selector
                    InterestTagsSelector(
                      availableTopics: _availableTopics,
                      selectedInterests: _selectedInterests,
                      onInterestsChanged: (tags) {
                        setState(() {
                          _selectedInterests = tags;
                        });
                      },
                    ),
                    const SizedBox(height: 24.0),

                    // 5. Bio Input Field
                    _buildBioField(),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildAvatarSection() {
    final avatarUrl = _selectedAvatarUrl.isNotEmpty
        ? _selectedAvatarUrl
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo glow border
          Container(
            width: 114.0,
            height: 114.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.periwinkle.withValues(alpha: 0.35),
                  blurRadius: 24.0,
                  spreadRadius: 2.0,
                ),
              ],
            ),
          ),
          // Avatar Image
          GestureDetector(
            onTap: _openAvatarPicker,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.periwinkle, AppColors.sakuraPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 52.0,
                backgroundColor: AppColors.surfaceCardSubtle,
                backgroundImage: NetworkImage(avatarUrl),
                onBackgroundImageError: (_, __) {},
                child: const Icon(
                  Icons.person_rounded,
                  size: 42.0,
                  color: AppColors.softSkyBlue,
                ),
              ),
            ),
          ),
          // Camera/Edit Icon Badge
          Positioned(
            bottom: 2.0,
            right: 2.0,
            child: GestureDetector(
              onTap: _openAvatarPicker,
              child: Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.periwinkle,
                  border: Border.all(
                    color: AppColors.backgroundCanvas,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.periwinkle.withValues(alpha: 0.45),
                      blurRadius: 8.0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 16.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.badge_rounded,
              color: AppColors.softSkyBlue,
              size: 20.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                appStrings.displayName,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        TextFormField(
          controller: _displayNameController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: appStrings.displayNamePlaceholder,
            hintStyle: TextStyle(
              color: AppColors.softSkyBlue.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppColors.surfaceCardSubtle,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 14.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(
                color: AppColors.softSkyBlue.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(
                color: AppColors.softSkyBlue.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: const BorderSide(
                color: AppColors.periwinkle,
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

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.warmPeach,
              size: 20.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                appStrings.bio,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.0),
          decoration: InputDecoration(
            hintText: appStrings.bioPlaceholder,
            hintStyle: TextStyle(
              color: AppColors.softSkyBlue.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppColors.surfaceCardSubtle,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 14.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(
                color: AppColors.softSkyBlue.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(
                color: AppColors.softSkyBlue.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: const BorderSide(
                color: AppColors.periwinkle,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButtonContent() {
    return Container(
      width: double.infinity,
      height: 52.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        gradient: const LinearGradient(
          colors: [AppColors.periwinkle, AppColors.lavender],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.periwinkle.withValues(alpha: 0.45),
            blurRadius: 18.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
        onPressed: _isSaving ? null : _saveProfile,
        child: _isSaving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    appStrings.saving,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                appStrings.saveChanges,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: SafeArea(
        top: false,
        child: _buildSaveButtonContent(),
      ),
    );
  }
}
