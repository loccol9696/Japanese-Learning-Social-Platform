import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/services/auth_service.dart';
import '../password_policy.dart';

/// Đổi mật khẩu cho người đang đăng nhập. Server thu hồi phiên ở các thiết bị
/// khác và trả cặp token mới cho thiết bị này (AuthService đã lưu lại).
/// Tài khoản đăng nhập bằng Google chưa có mật khẩu: server trả lỗi hướng dẫn
/// dùng "Quên mật khẩu", thông điệp đó được hiển thị nguyên văn.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {

  final _formKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.changePassword(
        oldPassword: _oldController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      AppToast.showSuccess('Đổi mật khẩu thành công', context: context);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          'Không thể kết nối máy chủ. Vui lòng thử lại.',
          context: context,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(
    String label, {
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppPalette.textSecondary),
      filled: true,
      fillColor: AppPalette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppPalette.accent, width: 1.5),
      ),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppPalette.textSecondary,
        ),
        onPressed: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        title: const Text('Đổi mật khẩu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sau khi đổi, các thiết bị khác sẽ bị đăng xuất.',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _oldController,
                  obscureText: _obscureOld,
                  style: TextStyle(color: AppPalette.textPrimary),
                  decoration: _decoration(
                    'Mật khẩu hiện tại',
                    obscure: _obscureOld,
                    onToggle: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vui lòng nhập mật khẩu hiện tại'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newController,
                  obscureText: _obscureNew,
                  style: TextStyle(color: AppPalette.textPrimary),
                  decoration: _decoration(
                    'Mật khẩu mới',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  onChanged: (_) {
                    if (_confirmController.text.isNotEmpty) {
                      _confirmFieldKey.currentState?.validate();
                    }
                  },
                  validator: (v) {
                    final value = v ?? '';
                    final problem = validateNewPassword(value);
                    if (problem != null) return problem;
                    if (value == _oldController.text) {
                      return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: _confirmFieldKey,
                  controller: _confirmController,
                  obscureText: _obscureNew,
                  style: TextStyle(color: AppPalette.textPrimary),
                  decoration: _decoration(
                    'Nhập lại mật khẩu mới',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  validator: (v) =>
                      v != _newController.text ? 'Mật khẩu nhập lại không khớp' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.accent,
                      foregroundColor: AppPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppPalette.onAccent,
                            ),
                          )
                        : const Text('Đổi mật khẩu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
