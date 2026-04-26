import 'dart:convert';
import 'package:http/http.dart' as http;

class FedExService {
  FedExService({
    required this.clientId,
    required this.clientSecret,
    required this.baseUrl,
  });

  final String clientId;
  final String clientSecret;
  final String baseUrl;

  Future<String> _getToken() async {
    final res = await http.post(
      Uri.parse('$baseUrl/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    return jsonDecode(res.body)['access_token'];
  }

  Future<Map<String, dynamic>> trackPackage(String trackingNumber) async {
    final token = await _getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/track/v1/trackingnumbers'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'trackingInfo': [
          {
            'trackingNumberInfo': {'trackingNumber': trackingNumber}
          }
        ]
      }),
    );

    return {
      'carrier': 'FedEx',
      'trackingNumber': trackingNumber,
      'raw': jsonDecode(res.body),
    };
  }
}