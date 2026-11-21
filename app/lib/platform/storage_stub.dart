final Map<String, String> _memory = {};

String? readPref(String key) => _memory[key];

void writePref(String key, String? value) {
  if (value == null) {
    _memory.remove(key);
  } else {
    _memory[key] = value;
  }
}
