import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final notifier = ref.read(walletProvider.notifier);
    const bool isDark = false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: const SafeTraceAppBar(
        title: "SafeTrace Wallet",
        showBackButton: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Balance Card
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2648), Color(0xFF131522)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppBorderRadius.lgBorder,
                  border: Border.all(
                    color: const Color(0xFF2E3B68),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "WALLET BALANCE",
                          style: TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                          decoration: BoxDecoration(
                            color: walletState.isSubscriptionActive
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: walletState.isSubscriptionActive ? AppColors.success : AppColors.error,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            walletState.isSubscriptionActive ? "PREMIUM ACTIVE" : "FREE TIER GATED",
                            style: TextStyle(
                              color: walletState.isSubscriptionActive ? AppColors.success : AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "₦${walletState.balance.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SafeTraceButton(
                            text: "Deposit Funds",
                            type: ButtonType.primary,
                            onPressed: () => _showTopUpSheet(context, notifier, isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Main display switching based on subscription active
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !walletState.isSubscriptionActive
                    ? _buildLockedOverlay(context, notifier, isDark)
                    : _buildTransactionsView(walletState, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gated Subscription paywall view
  Widget _buildLockedOverlay(BuildContext context, WalletNotifier notifier, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            "Access Gated: Subscription Expired",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "A minimum wallet balance of ₦1,000 is required to activate your 365-day safety subscription.\nIncludes unlimited AI notes, route intelligence summaries, and on-device Audio Sentinel monitoring.",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SafeTraceButton(
            text: "Top Up ₦1,000 Now",
            onPressed: () => _showTopUpSheet(context, notifier, isDark),
          ),
        ],
      ),
    );
  }

  // Transactions listing view
  Widget _buildTransactionsView(WalletState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(
            "TRANSACTION HISTORY",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: state.transactions.isEmpty
              ? Center(
                  child: Text(
                    "No transactions yet.",
                    style: TextStyle(
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: state.transactions.length,
                  itemBuilder: (context, index) {
                    final tx = state.transactions[index];
                    final isCredit = tx.type == 'credit';

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: AppBorderRadius.mdBorder,
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isCredit ? AppColors.success : AppColors.primary).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            color: isCredit ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textLightPrimary,
                          ),
                        ),
                        subtitle: Text(
                          tx.date,
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        trailing: Text(
                          "${isCredit ? '+' : '-'}₦${tx.amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCredit ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Paystack topup modal
  void _showTopUpSheet(BuildContext context, WalletNotifier notifier, bool isDark) {
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setAmount(double amt) {
              setSheetState(() {
                amountController.text = amt.toStringAsFixed(0);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Paystack Wallet Deposit",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text("DEPOSIT AMOUNT (NGN)"),
                  const SizedBox(height: 8),
                  SafeTraceTextField(
                    hintText: "Enter amount (min ₦1,000)",
                    controller: amountController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Preset options
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setAmount(1000),
                          child: const Text("₦1,000"),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setAmount(2000),
                          child: const Text("₦2,000"),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setAmount(5000),
                          child: const Text("₦5,000"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Simulated Paystack payment
                  SafeTraceButton(
                    text: "Authorize Payment (Web Simulation)",
                    onPressed: () {
                      final val = double.tryParse(amountController.text) ?? 0.0;
                      if (val < 1000.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Minimum deposit is ₦1,000")),
                        );
                        return;
                      }

                      notifier.depositFunds(val);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Payment successful. Wallet updated.")),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
