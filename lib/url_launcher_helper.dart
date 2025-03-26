import 'package:url_launcher/url_launcher.dart';

class URLLauncherHelper {
  static Future<void> launchURL(String url) async {
    launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }
}
