// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Netmap';

  @override
  String get navMap => 'Map';

  @override
  String get navDevices => 'Devices';

  @override
  String get navActivity => 'Activity';

  @override
  String get navNetwork => 'Network';

  @override
  String get navMain => 'Main navigation';

  @override
  String get more => 'More';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Browser language';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get close => 'Close';

  @override
  String hello(String name) {
    return 'Hi $name';
  }

  @override
  String get stateDirect => 'Direct';

  @override
  String get stateRelay => 'Through a relay';

  @override
  String get stateOneWay => 'No reply';

  @override
  String get stateOffline => 'Offline';

  @override
  String get stateInactive => 'Inactive';

  @override
  String get you => 'You';

  @override
  String get hub => 'Hub';

  @override
  String get meDirectTitle => 'Direct';

  @override
  String get meRelayTitle => 'Through a relay';

  @override
  String get meOneWayTitle => 'No reply';

  @override
  String get meOfflineTitle => 'Offline';

  @override
  String get meUnknownTitle => 'Unknown device';

  @override
  String get loading => 'Loading…';

  @override
  String get copyMyAddress => 'Copy my address';

  @override
  String addressCopied(String ip) {
    return 'Address copied: $ip';
  }

  @override
  String get agoNow => 'just now';

  @override
  String agoSeconds(int n) {
    return '$n s ago';
  }

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String get agoYesterday => 'yesterday';

  @override
  String agoDays(int n) {
    return '$n days ago';
  }

  @override
  String get verdictLoading => 'Connecting…';

  @override
  String get verdictOk => 'Everything works';

  @override
  String verdictRelay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Works · $count devices through a relay',
      one: 'Works · 1 device through a relay',
    );
    return '$_temp0';
  }

  @override
  String get verdictTcpFallback => 'UDP is blocked: the network falls back to TCP';

  @override
  String get verdictForceTcp => 'TCP relay is forced';

  @override
  String verdictNetDrop(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count devices dropped together', one: '1 device dropped');
    return '$_temp0';
  }

  @override
  String get verdictNetDropMany => 'Several devices dropped together';

  @override
  String get verdictServerDown => 'Netmap isn\'t answering';

  @override
  String verdictZtnetDown(String ago) {
    return 'ZTNET isn\'t answering: data from $ago';
  }

  @override
  String get mapLabel => 'Map of the network';

  @override
  String get mapHint => 'Arrows move between devices, Enter opens one, plus and minus zoom, 0 shows everything.';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomFit => 'Show everything';

  @override
  String get legend => 'Legend';

  @override
  String get closeDetails => 'Close';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String ownerOf(String name) {
    return '$name\'s';
  }

  @override
  String lastSeen(String ago) {
    return 'seen $ago';
  }

  @override
  String get neverSeen => 'never seen';

  @override
  String get typePc => 'Computer';

  @override
  String get typeLaptop => 'Laptop';

  @override
  String get typePhone => 'Phone';

  @override
  String get typeTablet => 'Tablet';

  @override
  String get typeTv => 'TV';

  @override
  String get typeServer => 'Server';

  @override
  String get typeConsole => 'Console';

  @override
  String get typeIot => 'Other device';

  @override
  String durMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes', one: '1 minute');
    return '$_temp0';
  }

  @override
  String durHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count hours', one: '1 hour');
    return '$_temp0';
  }

  @override
  String durDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String durMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count months', one: '1 month');
    return '$_temp0';
  }

  @override
  String durYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count years', one: '1 year');
    return '$_temp0';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get services => 'Services';

  @override
  String get svcDown => 'Not answering';

  @override
  String svcDownFor(String d) {
    return 'Not answering for $d';
  }

  @override
  String svcApp(String app) {
    return 'App: $app';
  }

  @override
  String get open => 'Open';

  @override
  String get details => 'Details';

  @override
  String get someDevice => 'a device';

  @override
  String evOffline(String name) {
    return '$name went offline';
  }

  @override
  String evOnline(String name) {
    return '$name is back online';
  }

  @override
  String evRelay(String name) {
    return '$name now goes through a relay';
  }

  @override
  String evDirect(String name) {
    return '$name is direct again';
  }

  @override
  String evSpike(String name) {
    return 'High latency on $name';
  }

  @override
  String evPending(String name) {
    return '$name is asking to join';
  }

  @override
  String evNetdrop(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count devices dropped together', one: '1 device dropped');
    return '$_temp0';
  }

  @override
  String get evNetdropMany => 'Several devices dropped together';

  @override
  String get actAll => 'All';

  @override
  String get actOff => 'Offline';

  @override
  String get actOn => 'Back online';

  @override
  String get actPath => 'Link changes';

  @override
  String get actSpike => 'High latency';

  @override
  String get actJoin => 'Requests';

  @override
  String get actFilter => 'Filter the activity';

  @override
  String get actWaiting => 'Waiting';

  @override
  String actWaitingFor(String d) {
    return 'for $d';
  }

  @override
  String get actEmptyFilter => 'Nothing of this kind';

  @override
  String get devNone => 'No device matches';

  @override
  String get devSearch => 'Search by name, person or address';

  @override
  String get back => 'Back';

  @override
  String dtOwner(String name, String type) {
    return '$name\'s $type';
  }

  @override
  String get dtSpeed => 'Speed';

  @override
  String get dtLastSeen => 'Last seen';

  @override
  String get dtAvailability => 'Availability, 24 hours';

  @override
  String get dtNow => 'now';

  @override
  String dtSpeedMs(int ms) {
    return '$ms ms typical';
  }

  @override
  String dtAvailPct(String pct) {
    return 'online $pct of the last 24 hours';
  }

  @override
  String get dtTechnical => 'Technical details';

  @override
  String get dtAddress => 'ZeroTier address';

  @override
  String get dtNodeId => 'Node ID';

  @override
  String get dtVersion => 'ZeroTier version';

  @override
  String dtNewest(String v) {
    return 'newest on the network: $v';
  }

  @override
  String get dtPaths => 'Paths';

  @override
  String dtPathsValue(int active, int dead, int family) {
    return '$active active · $dead broken · IPv$family';
  }

  @override
  String get dtLastPacket => 'Last packet';

  @override
  String dtSecondsAgo(int n) {
    return '$n s ago';
  }

  @override
  String get dtMemberFor => 'In the network for';

  @override
  String get dtNote => 'Note';

  @override
  String get dtLatency => 'Latency over time';

  @override
  String dtWeekPrev(int ms) {
    return 'week before $ms ms';
  }

  @override
  String get dtPackets => 'Packets, 30 days';

  @override
  String dtPacketsTotal(String n) {
    return '$n packets';
  }

  @override
  String dtErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packet errors in 24 hours',
      one: '1 packet error in 24 hours',
      zero: 'no packet errors in 24 hours',
    );
    return '$_temp0';
  }

  @override
  String get dtRecent => 'Recent events';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get netPrivate => 'Private';

  @override
  String get netPublic => 'Public';

  @override
  String netCreated(String date) {
    return 'created $date';
  }

  @override
  String netHubTitle(String hub) {
    return 'ZeroTier on $hub';
  }

  @override
  String get netService => 'Service';

  @override
  String get netOnline => 'Online';

  @override
  String get netNotOnline => 'Not answering';

  @override
  String netVersionPort(String v, String port) {
    return '$v · port $port';
  }

  @override
  String get netTcpFallback => 'TCP fallback';

  @override
  String get netForced => 'Forced TCP relay';

  @override
  String get netPortMapping => 'Port mapping';

  @override
  String get netMetrics => 'Metrics';

  @override
  String get netActive => 'active';

  @override
  String get netInactive => 'not active';

  @override
  String get netOn => 'on';

  @override
  String get netOff => 'off';

  @override
  String get netUnknown => 'unknown';

  @override
  String get netNoLocal => 'The local ZeroTier service can\'t be queried';

  @override
  String get netChain => 'Configured, received, applied';

  @override
  String get netConfigured => 'Configured';

  @override
  String netApplied(String hub) {
    return 'Applied on $hub';
  }

  @override
  String get netDns => 'DNS';

  @override
  String get netRoutes => 'Routes';

  @override
  String get netAddresses => 'Addresses';

  @override
  String get netNone => 'none';

  @override
  String get netNotReceived => 'not received';

  @override
  String get netNotApplied => 'not applied';

  @override
  String get netConsentOff => 'not allowed on the hub';

  @override
  String get netYes => 'yes';

  @override
  String get netPerf => 'Performance over time';

  @override
  String get netOnlineNow => 'Online now';

  @override
  String get netTypical => 'Typical latency';

  @override
  String get netAvailability => 'Availability, 24 h';

  @override
  String get netOutages => 'Drops, 24 h';

  @override
  String netVsWeek(String pct) {
    return '$pct vs last week';
  }

  @override
  String get netLatencyBy => 'Latency by device';

  @override
  String get netAvailGrid => 'Availability, 24 hours';

  @override
  String get netRelays => 'Through a relay';

  @override
  String get netTraffic => 'Network traffic, 30 days';

  @override
  String netTcpShare(String pct) {
    return 'TCP share $pct';
  }

  @override
  String get netMetricsOff => 'ZeroTier metrics are off';

  @override
  String get netTop => 'Traffic by person';

  @override
  String get netVersions => 'ZeroTier versions';

  @override
  String get netComposition => 'Devices by type';

  @override
  String netDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count devices', one: '1 device');
    return '$_temp0';
  }

  @override
  String get stateOnline => 'Online';

  @override
  String get meOnlineTitle => 'Online';

  @override
  String get netLocalTokenUnreadable =>
      'Netmap can\'t read ZeroTier\'s token: the file is readable only by root. Use the current image (it reads the token as root, then drops privileges) or set ZT_AUTHTOKEN.';

  @override
  String get netLocalTokenMissing => 'ZeroTier\'s token isn\'t there: mount the zerotier volume or set ZT_AUTHTOKEN.';

  @override
  String get netLocalRefused =>
      'The local ZeroTier service doesn\'t answer: Netmap must share the ZeroTier container\'s network (network_mode: service:zerotier).';

  @override
  String get netLocalTimeout => 'The local ZeroTier service is too slow to answer.';

  @override
  String get netLocalUnauthorized => 'The local ZeroTier service refuses the token: check ZT_AUTHTOKEN.';

  @override
  String inactiveShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '+$count inactive');
    return '$_temp0';
  }

  @override
  String get revoked => 'revoked';

  @override
  String get availAgo24 => '24 h ago';

  @override
  String get availNow => 'now';

  @override
  String chartMedian(int v) {
    return '$v median';
  }

  @override
  String chartPrevWeek(int v) {
    return '$v week before';
  }

  @override
  String dtMedianP95(int median, int p95) {
    return 'median $median ms · p95 $p95 ms';
  }

  @override
  String netReceivedValue(String value) {
    return 'received: $value';
  }

  @override
  String get netId => 'Network ID';

  @override
  String devicesOfType(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count computers', one: '1 computer');
    String _temp1 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count laptops', one: '1 laptop');
    String _temp2 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count phones', one: '1 phone');
    String _temp3 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tablets', one: '1 tablet');
    String _temp4 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count TVs', one: '1 TV');
    String _temp5 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count servers', one: '1 server');
    String _temp6 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count consoles', one: '1 console');
    String _temp7 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count other devices', one: '1 other device');
    String _temp8 = intl.Intl.selectLogic(type, {
      'pc': '$_temp0',
      'laptop': '$_temp1',
      'phone': '$_temp2',
      'tablet': '$_temp3',
      'tv': '$_temp4',
      'server': '$_temp5',
      'console': '$_temp6',
      'other': '$_temp7',
    });
    return '$_temp8';
  }

  @override
  String get noEvents => 'Nothing has changed yet.';

  @override
  String get dtVia => 'Goes through';

  @override
  String get dtViaLocal => 'the hub\'s local network';

  @override
  String get dtViaInternet => 'the internet';

  @override
  String get dtViaRelay => 'a relay';
}
