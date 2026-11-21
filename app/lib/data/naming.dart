// From the device name to "whose is it" and "what is it".
// Recommended convention: person-type[-qualifier], all lowercase
// (alice-pc, bob-phone-work). The type is recognised anywhere in the name, so
// PC-Carol or LAPTOP-Dave work too; the owner is the first segment that is
// neither a type nor a qualifier. Trailing digits are ignored when grouping:
// erin2-pc ends up with erin.

enum DeviceType { pc, laptop, phone, tablet, tv, server, console, iot }

const Map<DeviceType, List<String>> _synonyms = {
  DeviceType.pc: ['pc', 'desktop', 'fisso', 'computer', 'workstation', 'imac'],
  DeviceType.laptop: ['laptop', 'notebook', 'portatile', 'macbook'],
  DeviceType.phone: ['phone', 'iphone', 'android', 'smartphone', 'tel', 'telefono', 'pixel', 'redmi', 'galaxy', 'oneplus'],
  DeviceType.tablet: ['tablet', 'ipad'],
  DeviceType.tv: ['tv', 'televisore', 'mediacenter', 'firestick', 'chromecast', 'appletv', 'shield'],
  DeviceType.server: ['server', 'nas', 'controller', 'pi', 'raspberry', 'raspberrypi', 'vm', 'proxmox', 'homelab'],
  DeviceType.console: ['console', 'playstation', 'ps3', 'ps4', 'ps5', 'xbox', 'switch', 'wii', 'steamdeck'],
  DeviceType.iot: ['iot', 'cam', 'camera', 'printer', 'stampante', 'sensor', 'esp', 'domotica'],
};

final Map<String, DeviceType> _tokenType = {
  for (final e in _synonyms.entries)
    for (final w in e.value) w: e.key,
};

const Set<String> _qualifiers = {'old', 'vecchio', 'new', 'nuovo', 'work', 'lavoro', 'gaming', 'studio', 'backup', 'main'};

List<String> _tokens(String name) => name.toLowerCase().split(RegExp('[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
String _bare(String t) => t.replaceFirst(RegExp(r'\d+$'), '');

DeviceType? typeOf(String name) {
  for (final t in _tokens(name)) {
    final ty = _tokenType[t] ?? _tokenType[_bare(t)];
    if (ty != null) return ty;
  }
  return null;
}

String? ownerOf(String name) {
  for (final t in _tokens(name)) {
    final b = _bare(t);
    if (b.isEmpty || _tokenType.containsKey(t) || _tokenType.containsKey(b) || _qualifiers.contains(b)) continue;
    return b;
  }
  return null;
}

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
