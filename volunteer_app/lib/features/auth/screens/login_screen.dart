import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _rememberMe = false;
  bool _isPasswordLogin = true;
  bool _obscurePassword = true;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isPasswordLogin) {
      await ref.read(authProvider.notifier).login(
            phone: _phoneController.text,
            password: _passwordController.text,
            rememberMe: _rememberMe,
          );
    } else {
      await ref.read(authProvider.notifier).loginWithCode(
            phone: _phoneController.text,
            code: _codeController.text,
          );
    }
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildLogo(),
                const SizedBox(height: 32),
                const Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '登录以管理您的志愿服务',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                _buildLoginTabs(),
                const SizedBox(height: 24),
                _buildPhoneField(),
                const SizedBox(height: 16),
                _isPasswordLogin
                    ? _buildPasswordField()
                    : _buildCodeField(),
                const SizedBox(height: 12),
                _buildRememberAndForgot(),
                const SizedBox(height: 24),
                _buildLoginButton(authState.isLoading),
                const SizedBox(height: 16),
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.volunteer_activism,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoginTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('密码登录', _isPasswordLogin, () {
              setState(() => _isPasswordLogin = true);
            }),
          ),
          Expanded(
            child: _buildTabButton('验证码登录', !_isPasswordLogin, () {
              setState(() => _isPasswordLogin = false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: AppStrings.phoneNumber,
        prefixIcon: const Icon(Icons.phone_outlined),
        hintText: '请输入手机号',
        counterText: '',
      ),
      maxLength: 11,
      validator: Validators.phone,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: AppStrings.password,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        hintText: '请输入密码',
      ),
      validator: Validators.password,
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

  Widget _buildRememberAndForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Text('记住我', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: const Text(AppStrings.forgotPassword),
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(AppStrings.login,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(AppStrings.noAccount, style: TextStyle(color: AppColors.textSecondary)),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/register');
          },
          child: const Text(AppStrings.register),
        ),
      ],
    );
  }
}
