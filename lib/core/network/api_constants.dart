enum Environment { uat, prod }

class ApiConstants {
  static Environment current = Environment.uat; // 👈 change only here

  static String get baseUrl {
    switch (current) {
      case Environment.uat:
        return 'https://uat-hrms.immortaltechnovation.com/api-uat-hrms/api';
      case Environment.prod:
        return 'https://hrms.immortaltechnovation.com/api-hrms/api';
    }
  }

  static String get imageBaseUrl => '${baseUrl}/uploads/';

  /// Legacy expense uploads root (some assets may still live here).
  static String get expenseReceiptBaseUrl => '${baseUrl}/uploads/expenses/';

  /// Per line item: `GET .../uploads/expenses/receipts/{filename}`.
  static String get expenseItemReceiptBaseUrl =>
      '${baseUrl}/uploads/expenses/receipts/';

  static String get selfieBaseUrl => '${baseUrl}/uploads/attendance/';

  static String get companyLogoBaseUrl => '${baseUrl}/uploads/company/';
}
