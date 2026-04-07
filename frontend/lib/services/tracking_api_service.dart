import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/package_tracking.dart';

class TrackingApiService {
  TrackingApiService({required this.baseUrl});

  final String baseUrl;

  Future<PackageTracking> fetchTracking(String trackingNumber) async {
    final uri = Uri.parse('$baseUrl/api/track/$trackingNumber');

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch tracking info.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['ok'] != true) {
      throw Exception(body['error']?.toString() ?? 'Unknown backend error.');
    }

    return PackageTracking.fromJson(body['data'] as Map<String, dynamic>);
  }
}