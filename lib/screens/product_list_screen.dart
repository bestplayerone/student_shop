import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/payment_service.dart';
import 'orders_screen.dart';
import 'xendit_webview_screen.dart';

typedef CheckoutBuilder = Widget Function(String invoiceUrl);

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    required this.paymentService,
    this.checkoutBuilder,
  });

  final PaymentService paymentService;
  final CheckoutBuilder? checkoutBuilder;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _products;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _products = widget.paymentService.fetchProducts();
  }

  void _refreshProducts() {
    setState(() {
      _products = widget.paymentService.fetchProducts();
    });
  }

  Future<void> _handleBuyProduct(Product product) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final invoice = await widget.paymentService.createInvoice(product);
      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              widget.checkoutBuilder?.call(invoice.invoiceUrl) ??
              XenditWebViewScreen(invoiceUrl: invoice.invoiceUrl),
        ),
      );
      if (!mounted) return;

      final status = await widget.paymentService.waitForOrderStatus(
        invoice.externalId,
        timeout: const Duration(seconds: 30),
        interval: const Duration(seconds: 2),
      );
      if (!mounted) return;

      final isPaid = status == 'PAID';
      final message = switch (status) {
        'PAID' => 'Payment Verified! ${product.name} is PAID.',
        'PENDING' => 'Payment is still pending. Check Order History shortly.',
        'EXPIRED' =>
          'This payment link expired. Start checkout again to retry.',
        'FAILED' => 'Payment was not completed. You can try again.',
        _ => 'Payment status could not be verified. Check Order History.',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isPaid
                ? Colors.green.shade700
                : Colors.orange.shade800,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Checkout could not be started or verified. Please retry.',
            ),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Campus Store'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          tooltip: 'Order History',
          icon: const Icon(Icons.receipt_long),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  OrdersScreen(paymentService: widget.paymentService),
            ),
          ),
        ),
      ],
    ),
    body: _isProcessing
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Supabase & Xendit...'),
              ],
            ),
          )
        : FutureBuilder<List<Product>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CatalogMessage(
                  title: 'The store could not connect.',
                  message: 'Check your Supabase setup and internet connection.',
                  onRetry: _refreshProducts,
                );
              }
              final products = snapshot.data ?? const <Product>[];
              if (products.isEmpty) {
                return _CatalogMessage(
                  title: 'No products found.',
                  message: 'Run the BMC-ecom1 catalog seed, then try again.',
                  onRetry: _refreshProducts,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refreshProducts(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(
                    product: products[index],
                    busy: _isProcessing,
                    onBuy: () => _handleBuyProduct(products[index]),
                  ),
                ),
              );
            },
          ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onBuy,
  });

  final Product product;
  final bool busy;
  final VoidCallback onBuy;

  Widget _image() {
    const fallback = Icon(Icons.image_outlined, size: 36);
    if (product.imageUrl.isEmpty) return fallback;
    return Image.network(
      product.imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SizedBox(
              width: 60,
              height: 60,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 60, height: 60, child: _image()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('₱${product.price.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onBuy,
            child: const Text('Buy Now'),
          ),
        ],
      ),
    ),
  );
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 54),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
