import 'package:flutter/material.dart';

import '../utils/movie_download_error.dart';

class MovieDownloadErrorNotice extends SnackBar {
  MovieDownloadErrorNotice(
      {super.key, required Object error, VoidCallback? onRetry})
      : super(
          content: Text(movieDownloadErrorMessage(error)),
          duration: const Duration(seconds: 6),
          persist: false,
          showCloseIcon: true,
          action: onRetry == null
              ? null
              : SnackBarAction(label: 'Retry', onPressed: onRetry),
        );
}

void showMovieDownloadError(BuildContext context, Object error,
    {VoidCallback? onRetry}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(MovieDownloadErrorNotice(error: error, onRetry: onRetry));
}
