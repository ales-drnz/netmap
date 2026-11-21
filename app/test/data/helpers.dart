import 'dart:convert';
import 'dart:io';

import 'package:netmap/data/api.dart';

final int now = DateTime.utc(2026, 10, 19, 12).millisecondsSinceEpoch;

NetNode node({
  String? id,
  String name = 'alice-pc',
  bool online = true,
  bool relayed = false,
  bool halfOpen = false,
  Link? link = Link.wan,
  int? lastSeen,
  bool hub = false,
  List<double?> spark = const [10, 10, 10],
  double? uptime = 1,
  double? latencyMs = 10,
}) => NetNode(
  id: id ?? name,
  name: name,
  ips: const ['10.0.0.1'],
  online: online,
  relayed: relayed,
  halfOpen: halfOpen,
  link: link,
  lastSeen: lastSeen ?? now,
  hub: hub,
  spark: spark,
  uptime: uptime,
  latencyMs: latencyMs,
);

Snapshot snap({
  List<NetNode>? nodes,
  List<NetEvent> events = const [],
  Health? health,
  String? error,
  int? updatedAt,
  List<Pending> pending = const [],
  List<QuickLink> links = const [],
}) => Snapshot(
  updatedAt: updatedAt ?? now,
  networkId: 'abc',
  networkName: 'home',
  pollSeconds: 20,
  nodes: nodes ?? [node(), node(name: 'bob-pc', link: Link.lan)],
  events: events,
  health: health,
  error: error,
  pending: pending,
  links: links,
);

/// a real /api/nodes answer of the mock (test/fixtures/snapshot.json)
Snapshot fixture() => Snapshot.fromJson(jsonDecode(File('test/fixtures/snapshot.json').readAsStringSync()) as Json);
