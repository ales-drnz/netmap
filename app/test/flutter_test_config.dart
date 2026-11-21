// Runs before every test file: loads the real fonts, so golden images show
// real text and icons instead of the test font's boxes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden images compared with a small tolerance: another Linux machine (CI)
/// may anti-alias a handful of pixels differently. Real changes move far more.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile);

  /// share of pixels allowed to differ
  static const tolerance = .002;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = TolerantComparator((goldenFileComparator as LocalFileComparator).basedir.resolve('x_test.dart'));
  }
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // where pub put the icon font: read it from the package config
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final pkg = (config['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'material_symbols_icons');
  final root = Uri.parse('${pkg['rootUri']}/');
  final symbols = (root.isAbsolute ? root : Uri.file('${Directory.current.path}/.dart_tool/').resolveUri(root))
      .resolve('lib/fonts/MaterialSymbolsRounded.ttf')
      .toFilePath();
  await load('RobotoFlex', ['assets/fonts/RobotoFlex.ttf']);
  await load('RobotoMono', ['assets/fonts/RobotoMono.ttf']);
  await load('packages/material_symbols_icons/MaterialSymbolsRounded', [symbols]);
  // Material's own icons (expand arrows, checkmarks) come with the SDK
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) await load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  await testMain();
}
