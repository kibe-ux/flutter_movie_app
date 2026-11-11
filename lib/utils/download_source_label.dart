/// Metadata supplied by the provider; unknown sizes and languages stay hidden.
String downloadSourceLabel(Map<String, String> source) {
  final bytes = int.tryParse(source['bytes'] ?? '');
  String? size;
  if (bytes != null && bytes >= 0) {
    if (bytes >= 1024 * 1024 * 1024) {
      size = '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      size = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      size = '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      size = '$bytes B';
    }
  }
  final locale = source['locale']?.trim();
  return [
    source['label'] ?? 'Source',
    if (locale != null && locale.isNotEmpty) locale,
    if (size != null) size
  ].join(' · ');
}
