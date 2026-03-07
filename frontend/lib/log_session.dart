import 'package:flutter/foundation.dart';

class LogSession extends ChangeNotifier {
  LogSession._();

  static final LogSession instance = LogSession._();

  int? _userId;
  String? _role;
  String? _adminRole;
  String? _studentId;
  String? _fullName;
  String? _email;
  String? _phone;
  String? _profilePicture;
  bool _requiresPhoneValidation = false;
  bool _requiresPasswordSetup = false;

  int? get userId => _userId;
  String? get role => _role;
  String? get adminRole => _adminRole;
  String? get studentId => _studentId;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get phone => _phone;
  String? get profilePicture => _profilePicture;
  bool get requiresPhoneValidation => _requiresPhoneValidation;
  bool get requiresPasswordSetup => _requiresPasswordSetup;
  bool get isLoggedIn => _email != null && _email!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  bool get isUser => _role == 'user';

  void setSessionFromBackend(Map<String, dynamic> data) {
    _userId = data['id'] is int
        ? data['id'] as int
        : int.tryParse('${data['id'] ?? ''}');
    _studentId = data['student_id']?.toString();
    _fullName = data['full_name']?.toString();
    _email = data['email']?.toString();
    _phone = data['phone']?.toString();
    _profilePicture = data['picture']?.toString();

    final dynamic requiresPhone = data['requires_phone_validation'];
    final dynamic requiresPassword = data['requires_password_setup'];
    _requiresPhoneValidation = requiresPhone == true;
    _requiresPasswordSetup = requiresPassword == true;

    notifyListeners();
  }

  void setLoginSession({
    required String role,
    required Map<String, dynamic> data,
  }) {
    _role = role;
    _adminRole = data['admin_role']?.toString();
    _userId = data['id'] is int
        ? data['id'] as int
        : int.tryParse('${data['id'] ?? ''}');
    _studentId = data['student_id']?.toString();
    _fullName = data['full_name']?.toString();
    _email = data['email']?.toString();
    _phone = data['phone']?.toString();
    _profilePicture = data['picture']?.toString();
    _requiresPhoneValidation = data['requires_phone_validation'] == true;
    _requiresPasswordSetup = data['requires_password_setup'] == true;
    notifyListeners();
  }

  void markPasswordSetupCompleted() {
    _requiresPasswordSetup = false;
    notifyListeners();
  }

  void updatePhone(String phone) {
    _phone = phone;
    _requiresPhoneValidation = false;
    notifyListeners();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': _userId,
      'role': _role,
      'admin_role': _adminRole,
      'student_id': _studentId,
      'full_name': _fullName,
      'email': _email,
      'phone': _phone,
      'picture': _profilePicture,
      'requires_phone_validation': _requiresPhoneValidation,
      'requires_password_setup': _requiresPasswordSetup,
    };
  }

  void clear() {
    _userId = null;
    _role = null;
    _adminRole = null;
    _studentId = null;
    _fullName = null;
    _email = null;
    _phone = null;
    _profilePicture = null;
    _requiresPhoneValidation = false;
    _requiresPasswordSetup = false;
    notifyListeners();
  }
}
