// Words for model values, in one place so every page uses the same name for
// the same concept (see the glossary in data/model.dart).
import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../data/api.dart';
import '../data/model.dart';
import '../data/naming.dart';
import '../data/status.dart';
import 'app_localizations.dart';

extension Words on L {
  String state(LinkState s) => switch (s) {
    // at home or over the internet: both simply direct (where it goes
    // through is a technical detail of the device)
    LinkState.atHome || LinkState.internet => stateDirect,
    LinkState.online => stateOnline,
    LinkState.relay => stateRelay,
    LinkState.oneWay => stateOneWay,
    LinkState.offline => stateOffline,
  };

  /// "5 min ago" for an epoch-ms time, relative to [now]
  String ago(int t, int now) {
    final s = ((now - t) / 1000).clamp(0, double.infinity);
    if (s < 10) return agoNow;
    if (s < 90) return agoSeconds(s.round());
    if (s < 3600) return agoMinutes((s / 60).round());
    if (s < 86400) return agoHours((s / 3600).round());
    final d = (s / 86400).round();
    return d == 1 ? agoYesterday : agoDays(d);
  }

  String verdictText(Verdict v, int now) => switch (v.reason) {
    Loading() => verdictLoading,
    AllGood() => verdictOk,
    Relayed(:final count) => verdictRelay(count),
    TcpFallback() => verdictTcpFallback,
    ForceTcp() => verdictForceTcp,
    NetDrop(:final count) => count == null ? verdictNetDropMany : verdictNetDrop(count),
    Stale(:final ztnet, :final ageSec) =>
      ztnet ? verdictZtnetDown(ageSec == null ? '—' : ago(now - ageSec * 1000, now)) : verdictServerDown,
  };
}

extension MoreWords on L {
  String type(DeviceType t) => switch (t) {
    DeviceType.pc => typePc,
    DeviceType.laptop => typeLaptop,
    DeviceType.phone => typePhone,
    DeviceType.tablet => typeTablet,
    DeviceType.tv => typeTv,
    DeviceType.server => typeServer,
    DeviceType.console => typeConsole,
    DeviceType.iot => typeIot,
  };

  /// a length of time: "5 minutes", "3 hours", "2 days", "4 months"
  String duration(double seconds) {
    final s = seconds.clamp(0, double.infinity);
    if (s < 3600) return durMinutes(math.max(1, (s / 60).round()));
    if (s < 86400) return durHours((s / 3600).round());
    final d = s / 86400;
    if (d < 31) return durDays(d.round());
    if (d < 365) return durMonths((d / 30.4).round());
    return durYears((d / 365).round());
  }

  /// "98,7 %" / "98.7%"
  String pct(double v, {int digits = 1}) =>
      NumberFormat.decimalPercentPattern(locale: localeName, decimalDigits: v >= .999 || v == 0 ? 0 : digits).format(v);

  String number(num v) => NumberFormat.decimalPattern(localeName).format(v);

  String compact(num v) => NumberFormat.compact(locale: localeName).format(v);

  String bytes(num v) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var x = v.toDouble();
    var i = 0;
    while (x >= 1000 && i < units.length - 1) {
      x /= 1000;
      i++;
    }
    return '${NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: x < 10 && i > 0 ? 1 : 0).format(x)} ${units[i]}';
  }

  String day(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return this.today;
    if (dd == today.subtract(const Duration(days: 1))) return yesterday;
    return DateFormat.MMMMEEEEd(localeName).format(d);
  }

  String time(int t) => DateFormat.Hm(localeName).format(DateTime.fromMillisecondsSinceEpoch(t));

  String date(int t) => DateFormat.yMMMd(localeName).format(DateTime.fromMillisecondsSinceEpoch(t));

  /// an event's sentence and, when there is one, its data (never advice)
  (String title, String? sub) event(NetEvent e) {
    final name = e.name ?? someDevice;
    return switch (e.kind) {
      EventKind.offline => (evOffline(name), null),
      EventKind.online => (evOnline(name), null),
      EventKind.relay => (evRelay(name), null),
      EventKind.direct => (evDirect(name), null),
      EventKind.spike => (evSpike(name), e.detail),
      EventKind.pending => (evPending(name), e.detail != null ? revoked : null),
      // who dropped, by name
      EventKind.netdrop => (e.count == null ? evNetdropMany : evNetdrop(e.count!), e.detail),
    };
  }

  /// why the hub's local ZeroTier service can't be read, in plain words
  String localReason(String? reason) => switch (reason) {
    'token-unreadable' => netLocalTokenUnreadable,
    'token-missing' => netLocalTokenMissing,
    'refused' => netLocalRefused,
    'timeout' => netLocalTimeout,
    'unauthorized' => netLocalUnauthorized,
    _ => netNoLocal,
  };
}
