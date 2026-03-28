class Quality {
  const Quality({
    required this.path,
    required this.size,
    required this.formattedSize,
  });

  final String path;
  final int size;
  final String formattedSize;

  factory Quality.fromJson(Map<String, dynamic> json) {
    final size = (json['size'] as num?)?.toInt() ?? 0;
    return Quality(
      path: (json['path'] ?? '') as String,
      size: size,
      formattedSize: (json['formattedSize'] ?? _formatBytes(size)) as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'size': size,
      'formattedSize': formattedSize,
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    final text = value < 10 && index > 0
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    return '$text ${units[index]}';
  }
}
