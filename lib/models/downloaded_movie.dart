class DownloadedMovie {
  const DownloadedMovie({
    required this.title,
    required this.path,
    required this.size,
    required this.formattedSize,
    required this.modifiedAt,
  });

  final String title;
  final String path;
  final int size;
  final String formattedSize;
  final DateTime modifiedAt;
}
