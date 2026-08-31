import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Top-level constant for compatibility
const bool SUBSCRIPTION_TEST_MODE = true;

/// Subscription Constants & Plan Configurations
class SubscriptionConstants {
  /// IMPORTANT: Set to false before production release.
  static const bool isTestMode = true;

  /// Test Plan Codes created in Paystack Dashboard
  static String get monthlyPlanCode =>
      dotenv.env['PAYSTACK_PLUS_MONTHLY_PLAN_CODE'] ?? 'PLN_e3qyxdg3hnzm781';

  static String get annualPlanCode =>
      dotenv.env['PAYSTACK_PLUS_ANNUAL_PLAN_CODE'] ?? 'PLN_vtxmymr3dn7cdy1';

  /// Price in Kobo (₦100 = 10000 kobo for test mode)
  static const int testPriceInKobo = 10000;
  static const int monthlyPriceInKobo = 10000; // ₦100 for testing
  static const int annualPriceInKobo = 10000;  // ₦100 for testing

  /// Live prices for production
  static const int liveMonthlyPriceInKobo = 200000;  // ₦2,000
  static const int liveAnnualPriceInKobo = 2000000;  // ₦20,000
}
