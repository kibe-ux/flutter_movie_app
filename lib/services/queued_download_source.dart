import 'wambesha_api_service.dart';

/// Queued links are checked at transfer time. An unexpired link costs no lookup.
Future<String> queuedDownloadSource({
  required WambeshaSources original,
  required String selectedUrl,
  required Future<WambeshaSources> Function() reload,
}) async {
  if (!original.isUrlExpiredOrInvalid(selectedUrl)) return selectedUrl;
  final selected =
      original.sources.where((source) => source['url'] == selectedUrl);
  if (selected.isEmpty) {
    throw const WambeshaSourceUnavailable('Choose a download source again.');
  }
  final metadata = selected.first;
  final updated = await reload();
  // Keep an explicitly selected quality/locale rather than silently switching it.
  final matches = updated.sources
      .where((source) =>
          source['kind'] == 'file_holding' &&
          source['quality'] == metadata['quality'] &&
          source['label'] == metadata['label'] &&
          source['resolution'] == metadata['resolution'] &&
          source['locale'] == metadata['locale'] &&
          source['url'] is String &&
          !updated.isUrlExpiredOrInvalid(source['url'] as String))
      .toList();
  if (matches.length == 1) return matches.single['url'] as String;
  throw const WambeshaSourceUnavailable(
      'This download source changed. Choose a source again.');
}
