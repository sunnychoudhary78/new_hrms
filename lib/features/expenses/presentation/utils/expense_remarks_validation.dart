/// Word count for expense remark fields (submit / approve / reject / pay).
int expenseRemarksWordCount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
}

/// Max words allowed in any expense remarks field.
const int kExpenseRemarksMaxWords = 150;

/// Returns a user-visible error, or `null` if valid.
String? expenseRemarksValidationError(
  String text, {
  required bool required,
}) {
  final t = text.trim();
  if (required && t.isEmpty) {
    return 'Remarks are required.';
  }
  if (t.isEmpty) return null;
  final n = expenseRemarksWordCount(t);
  if (n > kExpenseRemarksMaxWords) {
    return 'Remarks must be at most $kExpenseRemarksMaxWords words (currently $n).';
  }
  return null;
}
