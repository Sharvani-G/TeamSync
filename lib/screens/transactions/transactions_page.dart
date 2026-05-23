import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy transaction data
    final transactions = [
      TransactionItem(
        id: 'TXN001',
        date: DateTime(2024, 5, 15),
        amount: 9.99,
        type: TransactionType.subscription,
        description: 'Annual Subscription',
        status: TransactionStatus.completed,
        paymentMethod: 'Credit Card ending in 4242',
      ),
      TransactionItem(
        id: 'TXN002',
        date: DateTime(2024, 4, 15),
        amount: 9.99,
        type: TransactionType.subscription,
        description: 'Annual Subscription',
        status: TransactionStatus.completed,
        paymentMethod: 'Credit Card ending in 4242',
      ),
      TransactionItem(
        id: 'TXN003',
        date: DateTime(2024, 3, 20),
        amount: 29.99,
        type: TransactionType.premium,
        description: 'Premium Features Upgrade',
        status: TransactionStatus.completed,
        paymentMethod: 'PayPal',
      ),
      TransactionItem(
        id: 'TXN004',
        date: DateTime(2024, 3, 15),
        amount: 9.99,
        type: TransactionType.subscription,
        description: 'Annual Subscription',
        status: TransactionStatus.completed,
        paymentMethod: 'Google Pay',
      ),
      TransactionItem(
        id: 'TXN005',
        date: DateTime(2024, 2, 10),
        amount: 49.99,
        type: TransactionType.refund,
        description: 'Refund - Premium Plan',
        status: TransactionStatus.completed,
        paymentMethod: 'Refunded to Credit Card',
      ),
    ];

    final totalSpent =
        transactions.fold<double>(0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: SimpleAppBar(title: 'Transaction History'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                        'Transactions',
                        transactions.length.toString(),
                        Colors.white,
                      ),
                      _buildSummaryItem(
                        'Last Payment',
                        _formatDate(transactions.first.date),
                        Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Transactions List
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions',
                  subtitle: 'Your transactions will appear here after your first payment.',
                ),
              )
            else
              ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _TransactionCard(transaction: transaction);
                },
              ),

            const SizedBox(height: 32),

            // Additional Info
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If you have any questions about your transactions or billing, please contact our support team.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support feature coming soon'),
                          ),
                        );
                      },
                      child: const Text('Contact Support'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class TransactionItem {
  final String id;
  final DateTime date;
  final double amount;
  final TransactionType type;
  final String description;
  final TransactionStatus status;
  final String paymentMethod;

  TransactionItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
    required this.status,
    required this.paymentMethod,
  });
}

enum TransactionType {
  subscription,
  premium,
  refund,
  other;

  IconData get icon {
    return switch (this) {
      TransactionType.subscription => Icons.card_membership_outlined,
      TransactionType.premium => Icons.star_outline,
      TransactionType.refund => Icons.money_off_outlined,
      TransactionType.other => Icons.receipt_long_outlined,
    };
  }

  Color get iconColor {
    return switch (this) {
      TransactionType.subscription => AppTheme.primary,
      TransactionType.premium => const Color(0xFFF59E0B),
      TransactionType.refund => const Color(0xFF10B981),
      TransactionType.other => AppTheme.textSecondary,
    };
  }
}

enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled;

  String get label {
    return switch (this) {
      TransactionStatus.pending => 'Pending',
      TransactionStatus.completed => 'Completed',
      TransactionStatus.failed => 'Failed',
      TransactionStatus.cancelled => 'Cancelled',
    };
  }

  Color get badgeColor {
    return switch (this) {
      TransactionStatus.pending => const Color(0xFFFCE7F3),
      TransactionStatus.completed => const Color(0xFFF0FDF4),
      TransactionStatus.failed => const Color(0xFFFEE2E2),
      TransactionStatus.cancelled => const Color(0xFFF3E8FF),
    };
  }

  Color get textColor {
    return switch (this) {
      TransactionStatus.pending => const Color(0xFFBE185D),
      TransactionStatus.completed => const Color(0xFF16A34A),
      TransactionStatus.failed => const Color(0xFFDC2626),
      TransactionStatus.cancelled => const Color(0xFF7C3AED),
    };
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionItem transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: transaction.type.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.type.icon,
                size: 20,
                color: transaction.type.iconColor,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(transaction.date)} • ${transaction.paymentMethod}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Status & Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${transaction.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: transaction.status.badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: transaction.status.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
