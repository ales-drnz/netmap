import 'package:web/web.dart' as web;

String? readPref(String key) {
  try {
    return web.window.localStorage.getItem('netmap.$key');
  } catch (_) {
    return null;
  }
}

void writePref(String key, String? value) {
  try {
    if (value == null) {
      web.window.localStorage.removeItem('netmap.$key');
    } else {
      web.window.localStorage.setItem('netmap.$key', value);
    }
  } catch (_) {}
}
