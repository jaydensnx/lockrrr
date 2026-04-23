import 'dart:convert';
import 'package:http/http.dart' as http;

class AmazonService {
  AmazonService({
    required this.accessToken,
    required this.baseUrl,
  });

  final String accessToken;
  final String baseUrl;

  Future<Map<String, dynamic>> trackPackage(String packageNumber) async {
    final res = await http.get(
      Uri.parse(
          '$baseUrl/fba/outbound/2020-07-01/tracking?packageNumber=$packageNumber'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return {
      'carrier': 'Amazon',
      'trackingNumber': packageNumber,
      'raw': jsonDecode(res.body),
    };
  }
}