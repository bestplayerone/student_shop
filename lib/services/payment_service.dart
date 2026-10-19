import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invoice_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

typedef SessionEnsurer = Future<void> Function();

abstract interface class PaymentService {
  Future<List<Product>> fetchProducts();
  Future<Invoice> createInvoice(Product product);
  Future<String> checkOrderStatus(String externalId);
  Future<List<ShopOrder>> fetchOrders();
  Future<String> waitForOrderStatus(
    String externalId, {
    Duration timeout,
    Duration interval,
  });
}

/// Calls only public catalog/order reads and the authenticated Edge Function.
/// Xendit credentials never leave the Supabase server.
class SupabasePaymentService implements PaymentService {
  SupabasePaymentService(
    SupabaseClient client, {
    SessionEnsurer? ensureSignedIn,
  }) : _client = client,
       _ensureSignedIn =
           ensureSignedIn ?? (() => _ensureAnonymousSession(client));

  final SupabaseClient _client;
  final SessionEnsurer _ensureSignedIn;

  static Future<void> _ensureAnonymousSession(SupabaseClient client) async {
    if (client.auth.currentSession != null) return;
    await client.auth.signInAnonymously();
    if (client.auth.currentSession == null) {
      throw StateError('Could not start a secure store session.');
    }
  }

  @override
  Future<List<Product>> fetchProducts() async {
    await _ensureSignedIn();
    final rows = await _client
        .from('products')
        .select('id,name,price,image_url')
        .order('id', ascending: true);
    return rows.map((row) => Product.fromMap(row)).toList(growable: false);
  }

  @override
  Future<Invoice> createInvoice(Product product) async {
    await _ensureSignedIn();
    final response = await _client.functions.invoke(
      'create-invoice',
      body: {'product_id': product.id},
    );
    if (response.status < 200 ||
        response.status >= 300 ||
        response.data is! Map<String, dynamic>) {
      throw StateError('Could not start checkout. Please try again.');
    }
    return Invoice.fromMap(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> checkOrderStatus(String externalId) async {
    await _ensureSignedIn();
    final record = await _client
        .from('orders')
        .select('status')
        .eq('external_id', externalId)
        .maybeSingle();
    return (record?['status'] as String?) ?? 'PENDING';
  }

  @override
  Future<String> waitForOrderStatus(
    String externalId, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
    final deadline = DateTime.now().add(timeout);
    var status = 'PENDING';
    do {
      status = await checkOrderStatus(externalId);
      if (status == 'PAID' || status == 'EXPIRED' || status == 'FAILED') {
        return status;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(remaining < interval ? remaining : interval);
    } while (DateTime.now().isBefore(deadline));
    return status;
  }

  @override
  Future<List<ShopOrder>> fetchOrders() async {
    await _ensureSignedIn();
    final rows = await _client
        .from('orders')
        .select('external_id,product_name,amount,status,created_at')
        .order('created_at', ascending: false);
    return rows.map((row) => ShopOrder.fromMap(row)).toList(growable: false);
  }
}
