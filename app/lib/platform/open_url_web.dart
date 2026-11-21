import 'package:web/web.dart' as web;

/// New tab, without giving the service a handle on this page.
void openUrl(String url) => web.window.open(url, '_blank', 'noopener,noreferrer');
