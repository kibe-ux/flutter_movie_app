import 'package:url_launcher/url_launcher.dart';

class TubiService {
  static const String tubiAppUrl = 'tubitv://';
  static const String tubiWebUrl = 'https://tubitv.com';

  // Open Tubi app or website
  static Future<void> openTubi() async {
    try {
      final appUri = Uri.parse(tubiAppUrl);
      final webUri = Uri.parse(tubiWebUrl);

      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(Uri.parse(tubiWebUrl), mode: LaunchMode.externalApplication);
    }
  }

  // Search for movie on Tubi
  static Future<void> searchMovie(Map<String, dynamic> movie) async {
    final movieTitle = movie['title'] ?? '';
    final year = _getYearFromDate(movie['release_date']);
    final query = year != null ? '$movieTitle $year' : movieTitle;
    final encodedQuery = Uri.encodeComponent(query);
    final tubiUrl = 'https://tubitv.com/search/$encodedQuery';
    final tubiUri = Uri.parse(tubiUrl);

    try {
      if (await canLaunchUrl(tubiUri)) {
        await launchUrl(tubiUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(tubiWebUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(Uri.parse(tubiWebUrl), mode: LaunchMode.externalApplication);
    }
  }

  static String? _getYearFromDate(String? releaseDate) {
    if (releaseDate == null) return null;
    try {
      return DateTime.parse(releaseDate).year.toString();
    } catch (_) {
      return null;
    }
  }
}
