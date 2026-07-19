/// Compact elapsed-time formatting for clinician dashboard cards.
library;

/// Short magnitude only, e.g. "just now", "5 min", "2 h", "3 d".
String elapsedShort(DateTime from) {
  final d = DateTime.now().difference(from);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  return '${d.inDays} d';
}

/// Relative time with an "ago" suffix, e.g. "2 h ago" ("just now" as-is).
String timeAgo(DateTime from) {
  final s = elapsedShort(from);
  return s == 'just now' ? s : '$s ago';
}
