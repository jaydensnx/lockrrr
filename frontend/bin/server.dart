import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/ups_service.dart';

void main() async {
  final env = dotenv.DotEnv()..load();

  final upsService = UpsService(
    clientId: env['UPS_CLIENT_ID'] ?? '',
    clientSecret: env['UPS_CLIENT_SECRET'] ?? '',
    accountNumber: env['UPS_ACCOUNT_NUMBER'] ?? '',
    baseUrl: env['UPS_BASE_URL'] ?? 'https://onlinetools.ups.com/',
  );

  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: {'Content-Type': 'application/json'},
    );
  });
router.get('/api/track/<trackingNumber>', (Request request, String trackingNumber) async {
    try {
      final result = await upsService.trackPackage(trackingNumber);

      return Response.ok(
        jsonEncode({
          'ok': true,
          'data': result,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({
          'ok': false,
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router);

  final port = int.tryParse(env['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('Server running on port ${server.port}');
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        });
      }

      final response = await innerHandler(request);
      return response.change(headers: {
        ...response.headers,
        'Access-Control-Allow-Origin': '',
      });
    };
  };
}