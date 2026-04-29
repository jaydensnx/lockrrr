import 'dart:convert';
import 'package:http/http.dart' as http;

class UpsService {
  UpsService({
    required this.clientId,
    required this.clientSecret,
    required this.accountNumber,
    required this.baseUrl,
  });

  final String clientId;
  final String clientSecret;
  final String accountNumber;
  final String baseUrl;

  String? _token;
  DateTime? _expiry;

  Future<String> _getToken() async {
    if (_token != null &&
        _expiry != null &&
        DateTime.now().isBefore(_expiry!)) {
      return _token!;
    }

    final auth = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final res = await http.post(
      Uri.parse('$baseUrl/security/v1/oauth/token'),
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/x-www-form-urlencoded',
        'x-merchant-id': accountNumber,
      },
      body: {'grant_type': 'client_credentials'},
    );

    final body = res.body;
    final data = jsonDecode(body);

    // 🔴 If UPS returns an error, show it clearly
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('UPS token failed: ${res.statusCode} $body');
    }

    // 🔴 Validate required fields
    if (data['access_token'] == null) {
      throw Exception('UPS token missing access_token: $body');
    }

    // 🔴 Safely parse expires_in (handles int OR string OR missing)
    int expiresIn = 3600; // default fallback

    if (data['expires_in'] != null) {
      expiresIn = int.tryParse(data['expires_in'].toString()) ?? 3600;
    }

    _token = data['access_token'];
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    return _token!;
  }

  Future<Map<String, dynamic>> trackPackage(String trackingNumber) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/track/v1/details/$trackingNumber'),
      headers: {
        'Authorization': 'Bearer $token',
        'transId': DateTime.now().millisecondsSinceEpoch.toString(),
        'transactionSrc': 'app',
      },
    );

    final body = res.body;

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('UPS tracking failed: ${res.statusCode} $body');
    }

    return {
      'carrier': 'UPS',
      'trackingNumber': trackingNumber,
      'raw': jsonDecode(body),
    };
  }
}