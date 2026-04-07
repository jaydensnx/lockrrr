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

  String? _cachedToken;
  DateTime? _tokenExpiresAt;

  Future<String> getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!)) {
      return _cachedToken!;
    }

    final uri = Uri.parse('$baseUrl/security/v1/oauth/token');

    final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic $basicAuth',
        'x-merchant-id': accountNumber,
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'UPS OAuth failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final accessToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'];

    if (accessToken == null) {
      throw Exception('UPS OAuth response did not include access_token.');
    }

    _cachedToken = accessToken;

    final expirySeconds = expiresIn is int
        ? expiresIn
        : int.tryParse(expiresIn?.toString() ?? '') ?? 3000;

    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expirySeconds - 60));

    return _cachedToken!;
  }

  Future<Map<String, dynamic>> trackPackage(String trackingNumber) async {
    final token = await getAccessToken();

    final uri = Uri.parse(
      '$baseUrl/api/track/v1/details/${Uri.encodeComponent(trackingNumber)}?locale=en_US',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'transId': 'track-${DateTime.now().millisecondsSinceEpoch}',
        'transactionSrc': 'smart-box-app',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'UPS Tracking failed: ${response.statusCode} ${response.body}',
      );
    }

    final raw = jsonDecode(response.body) as Map<String, dynamic>;
    return _simplifyTrackingResponse(raw, trackingNumber);
  }

  Map<String, dynamic> _simplifyTrackingResponse(
    Map<String, dynamic> raw,
    String trackingNumber,
  ) {
    // UPS response shapes can vary a bit by shipment type,
    // so this code safely digs through common fields.

    final trackResponse = raw['trackResponse'] as Map<String, dynamic>?;
    final shipmentList = trackResponse?['shipment'] as List<dynamic>?;

    if (shipmentList == null || shipmentList.isEmpty) {
      return {
        'trackingNumber': trackingNumber,
        'status': 'Unknown',
        'latestLocation': null,
        'latestDescription': null,
        'raw': raw,
      };
    }

    final shipment = shipmentList.first as Map<String, dynamic>;
    final packageList = shipment['package'] as List<dynamic>?;
    final packageData = (packageList != null && packageList.isNotEmpty)
        ? packageList.first as Map<String, dynamic>
        : <String, dynamic>{};

    final activityList = packageData['activity'] as List<dynamic>? ?? [];
    final latestActivity = activityList.isNotEmpty
        ? activityList.first as Map<String, dynamic>
        : null;

    String? location;
    if (latestActivity != null) {
      final activityLocation =
          latestActivity['location'] as Map<String, dynamic>?;
      final address = activityLocation?['address'] as Map<String, dynamic>?;

      final city = address?['city']?.toString();
      final state = address?['stateProvince']?.toString();
      final country = address?['countryCode']?.toString();

      final parts = [city, state, country]
          .where((e) => e != null && e.trim().isNotEmpty)
          .cast<String>()
          .toList();

      if (parts.isNotEmpty) {
        location = parts.join(', ');
      }
    }

    String? status;
    if (latestActivity != null) {
      final statusObj = latestActivity['status'] as Map<String, dynamic>?;
      status = statusObj?['description']?.toString();
    }

    final deliveryDate = shipment['deliveryDate']?.toString();

    return {
      'trackingNumber': trackingNumber,
      'status': status ?? 'Unknown',
      'latestLocation': location,
      'latestDescription': latestActivity?['status']?['description']?.toString(),
      'deliveryDate': deliveryDate,
      'activityCount': activityList.length,
      'raw': raw,
    };
  }
}