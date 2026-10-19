import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_shop/services/payment_service.dart';

void main() {
  test(
    'catalog checkout sends product ID only to server-priced invoice function',
    () async {
      var authCalls = 0;
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://project.supabase.co',
        'public-test-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          if (req.url.path == '/rest/v1/products') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'name': 'Mechanical Gaming Keyboard',
                  'price': 1500,
                  'image_url': '',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            );
          }
          if (req.url.path == '/functions/v1/create-invoice') {
            expect(req.method, 'POST');
            expect(jsonDecode(req.body), {'product_id': 1});
            return http.Response(
              jsonEncode({
                'invoice_url': 'https://checkout.xendit.co/web/test',
                'external_id': 'order_test',
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            );
          }
          return http.Response('{}', 404, request: req);
        }),
      );
      addTearDown(client.dispose);
      final service = SupabasePaymentService(
        client,
        ensureSignedIn: () async {
          authCalls++;
        },
      );
      final products = await service.fetchProducts();
      expect(products.single.price, 1500);
      final invoice = await service.createInvoice(products.single);
      expect(invoice.externalId, 'order_test');
      expect(authCalls, 2);
      expect(requests.first.url.queryParameters['order'], 'id.asc.nullslast');
    },
  );
}
