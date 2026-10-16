import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<String> _selectedSkills = [];
  int _countdown = 0;

  final List<String> _availableSkills = [
    '医疗救助',
    '应急救援',
    '心理辅导',
    '法律援助',
    '教育辅导',
    '社区服务',
    '环境保护',
    '翻译服务',
    '交通引导',
    '物资分发',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    if (Validators.phone(_phoneController.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入正确的手机号')),
      );
      return;
    }

    setState(() => _countdown = 60);
    while (_countdown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown--);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一项技能')),
      );
      return;
    }

    await ref.read(authProvider.notifier).register(
          name: _nameController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
          skills: _selectedSkills,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.register),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNameField(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 16),
              _buildCodeField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              _buildConfirmPasswordField(),
              const SizedBox(height: 24),
              _buildSkillSelector(),
              const SizedBox(height: 32),
              _buildRegisterButton(authState.isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '姓名',
        prefixIcon: Icon(Icons.person_outline),
        hintText: '请输入您的姓名',
      ),
      validator: Validators.username,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: AppStrings.phoneNumber,
        prefixIcon: Icon(Icons.phone_outlined),
        hintText: '请输入手机号',
      ),
      maxLength: 11,
      validator: Validators.phone,
    );
  }

  Widget _buildCodeField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: AppStrings.verificationCode,
              prefixIcon: Icon(Icons.sms_outlined),
              hintText: '请输入验证码',
            ),
            maxLength: 6,
            validator: Validators.verificationCode,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: ElevatedButton(
            onPressed: _countdown > 0 ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: _countdown > 0
                  ? AppColors.textHint
                  : AppColors.primary,
            ),
            child: Text(_countdown > 0 ? '${_countdown}s' : '发送'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: '设置密码',
        prefixIcon: Icon(Icons.lock_outline),
        hintText: '请输入6-20位密码',
      ),
      validator: Validators.password,
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: AppStrings.confirmPassword,
        prefixIcon: Icon(Icons.lock_outline),
        hintText: '请再次输入密码',
      ),
      validator: (value) => Validators.confirmPassword(value, _passwordController.text),
    );
  }

  Widget _buildSkillSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择您的专长 (可多选)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSkills.remove(skill);
                  } else {
                    _selectedSkills.add(skill);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleRegister,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text('注册并登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
