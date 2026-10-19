import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/payment_service.dart';
import '../widgets/order_status_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.paymentService});

  final PaymentService paymentService;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<ShopOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.paymentService.fetchOrders();
  }

  void _refresh() {
    setState(() {
      _orders = widget.paymentService.fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Order History'),
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<ShopOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading order history…'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.receipt_long_outlined,
            message: 'Order history could not be loaded.',
            detail: 'Check your connection and try again.',
            onRetry: _refresh,
          );
        }
        final orders = snapshot.data ?? const <ShopOrder>[];
        if (orders.isEmpty) {
          return _MessageState(
            icon: Icons.receipt_long_outlined,
            message: 'No orders yet.',
            detail: 'Your checkout orders will appear here.',
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isPaid = order.isPaid;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    isPaid ? Icons.check_circle : Icons.schedule,
                    color: isPaid
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    size: 32,
                    semanticLabel: isPaid ? 'Paid' : 'Payment not verified',
                  ),
                  title: Text(
                    order.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ref: ${order.externalId}\n${_formatDate(order.createdAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${order.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      OrderStatusBadge(status: order.status),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = (local.hour % 12 == 0 ? 12 : local.hour % 12)
        .toString()
        .padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'AM' : 'PM';
    return '$month/$day/${local.year} $hour:$minute $suffix';
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
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
