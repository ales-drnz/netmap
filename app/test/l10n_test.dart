// The two languages stay in step, and the glossary (lib/l10n/GLOSSARY.md) is
// respected: one word per concept, no jargon the glossary rules out.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> arb(String lang) => jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
Map<String, String> messages(String lang) => {
  for (final e in arb(lang).entries)
    if (!e.key.startsWith('@')) e.key: e.value as String,
};
Set<String> placeholders(String s) => RegExp(r'\{(\w+)[,}]').allMatches(s).map((m) => m[1]!).toSet();

void main() {
  final it = messages('it'), en = messages('en');

  test('same messages in both languages', () {
    expect(it.keys.toSet()..remove('@@locale'), en.keys.toSet()..remove('@@locale'));
  });

  test('same placeholders in both languages', () {
    for (final k in en.keys) {
      expect(placeholders(it[k]!), placeholders(en[k]!), reason: k);
    }
  });

  test('the link states have exactly the glossary words', () {
    expect(
      [it['stateDirect'], it['stateOnline'], it['stateRelay'], it['stateOneWay'], it['stateOffline'], it['stateInactive']],
      ['Diretto', 'Online', 'Tramite relay', 'Senza risposta', 'Offline', 'Inattivo'],
    );
    expect(
      [en['stateDirect'], en['stateOnline'], en['stateRelay'], en['stateOneWay'], en['stateOffline'], en['stateInactive']],
      ['Direct', 'Online', 'Through a relay', 'No reply', 'Offline', 'Inactive'],
    );
  });

  test('no word the glossary rules out', () {
    const banned = {
      'it': [r'\bLAN\b', r'\brel[eè]\b', 'scollegat', 'staccat', 'unidirezional', 'half-open', r'\bpeer\b', r'\bnod[oi]\b(?<!ID nodo)'],
      'en': [r'\bLAN\b', r'\brelayed\b', 'disconnected', 'unidirectional', 'half-open', r'\bpeers?\b', r'\bnodes?\b'],
    };
    for (final (lang, msgs) in [('it', it), ('en', en)]) {
      for (final e in msgs.entries) {
        // "ID nodo" / "Node ID" is ZeroTier's own name for the address
        final text = e.value.replaceAll('ID nodo', '').replaceAll('Node ID', '');
        for (final p in banned[lang]!) {
          expect(RegExp(p, caseSensitive: false).hasMatch(text), isFalse, reason: '$lang ${e.key}: "${e.value}" uses $p');
        }
      }
    }
  });
}
