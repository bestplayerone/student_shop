import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_shop/models/invoice_model.dart';
import 'package:student_shop/models/order_model.dart';
import 'package:student_shop/models/product_model.dart';
import 'package:student_shop/services/payment_service.dart';

const sampleProducts = <Product>[
  Product(id: 1, name: 'Mechanical Gaming Keyboard', price: 1500, imageUrl: ''),
  Product(id: 2, name: 'Wireless Ergonomic Mouse', price: 850, imageUrl: ''),
  Product(id: 3, name: 'USB-C Hub Multiport Adapter', price: 600, imageUrl: ''),
];

class FakePaymentService implements PaymentService {
  List<Product> products = sampleProducts;
  List<ShopOrder> orders = [];
  Object? productsError;
  Object? ordersError;
  Object? checkoutError;
  Object? statusError;
  Completer<List<Product>>? productsCompleter;
  Completer<Invoice>? invoiceCompleter;
  Completer<String>? statusCompleter;
  String status = 'PENDING';
  int productRequests = 0;
  int orderRequests = 0;
  int invoiceRequests = 0;
  int statusRequests = 0;
  String? checkedExternalId;

  @override
  Future<List<Product>> fetchProducts() async {
    productRequests++;
    if (productsError case final error?) throw error;
    return productsCompleter?.future ?? products;
  }

  @override
  Future<Invoice> createInvoice(Product product) async {
    invoiceRequests++;
    if (checkoutError case final error?) throw error;
    return invoiceCompleter?.future ??
        const Invoice(
          invoiceUrl: 'https://checkout.xendit.co/test-invoice',
          externalId: 'campus-order-123',
        );
  }

  @override
  Future<List<ShopOrder>> fetchOrders() async {
    orderRequests++;
    if (ordersError case final error?) throw error;
    return orders;
  }

  @override
  Future<String> checkOrderStatus(String externalId) async {
    checkedExternalId = externalId;
    if (statusError case final error?) throw error;
    return status;
  }

  @override
  Future<String> waitForOrderStatus(
    String externalId, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(seconds: 2),
  }) async {
    statusRequests++;
    checkedExternalId = externalId;
    if (statusError case final error?) throw error;
    return statusCompleter?.future ?? status;
  }
}

Widget testApp(Widget screen) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  ),
  home: screen,
);
