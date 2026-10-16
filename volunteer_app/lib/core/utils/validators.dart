/// 表单验证工具类
class Validators {
  /// 手机号验证
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    final phoneReg = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneReg.hasMatch(value)) {
      return '请输入正确的手机号';
    }
    return null;
  }

  /// 密码验证
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 6) {
      return '密码长度不能少于6位';
    }
    if (value.length > 20) {
      return '密码长度不能超过20位';
    }
    return null;
  }

  /// 确认密码验证
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }
    if (value != password) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  /// 验证码验证
  static String? verificationCode(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }
    if (value.length != 6) {
      return '验证码为6位数字';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return '验证码只能包含数字';
    }
    return null;
  }

  /// 用户名验证
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入姓名';
    }
    if (value.length < 2) {
      return '姓名至少2个字符';
    }
    if (value.length > 20) {
      return '姓名不能超过20个字符';
    }
    return null;
  }

  /// 邮箱验证
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return null; // 邮箱可选
    }
    final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailReg.hasMatch(value)) {
      return '请输入正确的邮箱';
    }
    return null;
  }

  /// 必填验证
  static String? required(String? value, [String fieldName = '此项']) {
    if (value == null || value.isEmpty) {
      return '请输入$fieldName';
    }
    return null;
  }
}
