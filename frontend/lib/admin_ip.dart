import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminIp {
  const AdminIp._();

  static const String _defaultBaseUrl = 'http://60.30.59.224:5000';

  static String get baseUrl {
    const configured = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return configured;
    }

    final envUrl = (dotenv.env['BACKEND_URL'] ?? '').trim();
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    final envIp = (dotenv.env['BACKEND_IP'] ?? '').trim();
    final envPort = (dotenv.env['BACKEND_PORT'] ?? '').trim();

    if (envIp.isNotEmpty && envPort.isNotEmpty) {
      return 'http://$envIp:$envPort';
    }

    return _defaultBaseUrl;
  }
}
