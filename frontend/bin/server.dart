import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/ups_service.dart';
import '../lib/fedex_service.dart';
import '../lib/amazon_service.dart';

Future<void> main() async {
  final env = dotenv.DotEnv()..load();

  final ups = UpsService(
    clientId: env['UPS_CLIENT_ID'] ?? '',
    clientSecret: env['UPS_CLIENT_SECRET'] ?? '',
    accountNumber: env['UPS_ACCOUNT_NUMBER'] ?? '',
    baseUrl: env['UPS_BASE_URL'] ?? 'https://onlinetools.ups.com',
  );

  final fedex = FedExService(
    clientId: env['FEDEX_CLIENT_ID'] ?? '',
    clientSecret: env['FEDEX_CLIENT_SECRET'] ?? '',
    baseUrl: env['FEDEX_BASE_URL'] ?? 'https://apis.fedex.com',
  );

  final amazon = AmazonService(
    accessToken: env['AMAZON_SP_API_ACCESS_TOKEN'] ?? '',
    baseUrl: env['AMAZON_BASE_URL'] ?? 'https://sellingpartnerapi-na.amazon.com',
  );

  final router = Router();

  router.get('/health', (_) => _json({'ok': true}));

  router.post('/api/tracking', (Request req) async {
    final body = jsonDecode(await req.readAsString());

    final carrier = body['carrier'];
    final trackingNumber = body['trackingNumber'];

    try {
      switch (carrier) {
        case 'ups':
          return _json(await ups.trackPackage(trackingNumber));
        case 'fedex':
          return _json(await fedex.trackPackage(trackingNumber));
        case 'amazon':
          return _json(await amazon.trackPackage(trackingNumber));
        default:
          return _json({'error': 'Invalid carrier'}, 400);
      }
    } catch (e) {
      return _json({'error': e.toString()}, 500);
    }
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router);
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    int.parse(env['PORT'] ?? '8080'),
  );

  print('Running on ${server.port}');
}

Response _json(data, [int code = 200]) {
  return Response(
    code,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

Middleware _cors() {
  return (inner) {
    return (req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      }
      final res = await inner(req);
      return res.change(headers: {
        ...res.headers,
        'Access-Control-Allow-Origin': '*',
      });
    };
  };
}