String? validateRequiredText(
  String? value, {
  required int maxLength,
  required String emptyMessage,
  required String lengthMessage,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return emptyMessage;
  if (text.runes.length > maxLength) return lengthMessage;
  return null;
}
