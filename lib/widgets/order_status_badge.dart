import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'PAID' => (Colors.green.shade700, Icons.check_circle),
      'PENDING' => (Colors.orange.shade800, Icons.schedule),
      'FAILED' => (Colors.red.shade700, Icons.cancel),
      'EXPIRED' => (Colors.grey.shade700, Icons.event_busy),
      _ => (Colors.grey.shade700, Icons.help_outline),
    };
    return Semantics(
      label: 'Order status: $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
