import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../utils/download_progress.dart';
import '../utils/cinema_palette.dart';

class DownloadProgressDetails extends StatelessWidget {
  const DownloadProgressDetails({super.key, required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) => Text(downloadProgressText(item),
      style: const TextStyle(color: CinemaPalette.muted, fontSize: 12),
      maxLines: 3,
      overflow: TextOverflow.ellipsis);
}
