import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('it')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Netmap'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get navNetwork;

  /// No description provided for @navMain.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get navMain;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Browser language'**
  String get languageSystem;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}'**
  String hello(String name);

  /// No description provided for @stateDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get stateDirect;

  /// No description provided for @stateRelay.
  ///
  /// In en, this message translates to:
  /// **'Through a relay'**
  String get stateRelay;

  /// No description provided for @stateOneWay.
  ///
  /// In en, this message translates to:
  /// **'No reply'**
  String get stateOneWay;

  /// No description provided for @stateOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get stateOffline;

  /// No description provided for @stateInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get stateInactive;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @hub.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get hub;

  /// No description provided for @meDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get meDirectTitle;

  /// No description provided for @meRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Through a relay'**
  String get meRelayTitle;

  /// No description provided for @meOneWayTitle.
  ///
  /// In en, this message translates to:
  /// **'No reply'**
  String get meOneWayTitle;

  /// No description provided for @meOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get meOfflineTitle;

  /// No description provided for @meUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get meUnknownTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @copyMyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy my address'**
  String get copyMyAddress;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied: {ip}'**
  String addressCopied(String ip);

  /// No description provided for @agoNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoNow;

  /// No description provided for @agoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s ago'**
  String agoSeconds(int n);

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String agoHours(int n);

  /// No description provided for @agoYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get agoYesterday;

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String agoDays(int n);

  /// No description provided for @verdictLoading.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get verdictLoading;

  /// No description provided for @verdictOk.
  ///
  /// In en, this message translates to:
  /// **'Everything works'**
  String get verdictOk;

  /// No description provided for @verdictRelay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Works · 1 device through a relay} other{Works · {count} devices through a relay}}'**
  String verdictRelay(int count);

  /// No description provided for @verdictTcpFallback.
  ///
  /// In en, this message translates to:
  /// **'UDP is blocked: the network falls back to TCP'**
  String get verdictTcpFallback;

  /// No description provided for @verdictForceTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP relay is forced'**
  String get verdictForceTcp;

  /// No description provided for @verdictNetDrop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device dropped} other{{count} devices dropped together}}'**
  String verdictNetDrop(int count);

  /// No description provided for @verdictNetDropMany.
  ///
  /// In en, this message translates to:
  /// **'Several devices dropped together'**
  String get verdictNetDropMany;

  /// No description provided for @verdictServerDown.
  ///
  /// In en, this message translates to:
  /// **'Netmap isn\'t answering'**
  String get verdictServerDown;

  /// No description provided for @verdictZtnetDown.
  ///
  /// In en, this message translates to:
  /// **'ZTNET isn\'t answering: data from {ago}'**
  String verdictZtnetDown(String ago);

  /// No description provided for @mapLabel.
  ///
  /// In en, this message translates to:
  /// **'Map of the network'**
  String get mapLabel;

  /// No description provided for @mapHint.
  ///
  /// In en, this message translates to:
  /// **'Arrows move between devices, Enter opens one, plus and minus zoom, 0 shows everything.'**
  String get mapHint;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomFit.
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get zoomFit;

  /// No description provided for @legend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get legend;

  /// No description provided for @closeDetails.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeDetails;

  /// No description provided for @latencyMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String latencyMs(int ms);

  /// No description provided for @ownerOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s'**
  String ownerOf(String name);

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'seen {ago}'**
  String lastSeen(String ago);

  /// No description provided for @neverSeen.
  ///
  /// In en, this message translates to:
  /// **'never seen'**
  String get neverSeen;

  /// No description provided for @typePc.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get typePc;

  /// No description provided for @typeLaptop.
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get typeLaptop;

  /// No description provided for @typePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get typePhone;

  /// No description provided for @typeTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get typeTablet;

  /// No description provided for @typeTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get typeTv;

  /// No description provided for @typeServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get typeServer;

  /// No description provided for @typeConsole.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get typeConsole;

  /// No description provided for @typeIot.
  ///
  /// In en, this message translates to:
  /// **'Other device'**
  String get typeIot;

  /// No description provided for @durMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String durMinutes(int count);

  /// No description provided for @durHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String durHours(int count);

  /// No description provided for @durDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durDays(int count);

  /// No description provided for @durMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String durMonths(int count);

  /// No description provided for @durYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String durYears(int count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @svcDown.
  ///
  /// In en, this message translates to:
  /// **'Not answering'**
  String get svcDown;

  /// No description provided for @svcDownFor.
  ///
  /// In en, this message translates to:
  /// **'Not answering for {d}'**
  String svcDownFor(String d);

  /// No description provided for @svcApp.
  ///
  /// In en, this message translates to:
  /// **'App: {app}'**
  String svcApp(String app);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @someDevice.
  ///
  /// In en, this message translates to:
  /// **'a device'**
  String get someDevice;

  /// No description provided for @evOffline.
  ///
  /// In en, this message translates to:
  /// **'{name} went offline'**
  String evOffline(String name);

  /// No description provided for @evOnline.
  ///
  /// In en, this message translates to:
  /// **'{name} is back online'**
  String evOnline(String name);

  /// No description provided for @evRelay.
  ///
  /// In en, this message translates to:
  /// **'{name} now goes through a relay'**
  String evRelay(String name);

  /// No description provided for @evDirect.
  ///
  /// In en, this message translates to:
  /// **'{name} is direct again'**
  String evDirect(String name);

  /// No description provided for @evSpike.
  ///
  /// In en, this message translates to:
  /// **'High latency on {name}'**
  String evSpike(String name);

  /// No description provided for @evPending.
  ///
  /// In en, this message translates to:
  /// **'{name} is asking to join'**
  String evPending(String name);

  /// No description provided for @evNetdrop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device dropped} other{{count} devices dropped together}}'**
  String evNetdrop(int count);

  /// No description provided for @evNetdropMany.
  ///
  /// In en, this message translates to:
  /// **'Several devices dropped together'**
  String get evNetdropMany;

  /// No description provided for @actAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get actAll;

  /// No description provided for @actOff.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get actOff;

  /// No description provided for @actOn.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get actOn;

  /// No description provided for @actPath.
  ///
  /// In en, this message translates to:
  /// **'Link changes'**
  String get actPath;

  /// No description provided for @actSpike.
  ///
  /// In en, this message translates to:
  /// **'High latency'**
  String get actSpike;

  /// No description provided for @actJoin.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get actJoin;

  /// No description provided for @actFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter the activity'**
  String get actFilter;

  /// No description provided for @actWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get actWaiting;

  /// No description provided for @actWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'for {d}'**
  String actWaitingFor(String d);

  /// No description provided for @actEmptyFilter.
  ///
  /// In en, this message translates to:
  /// **'Nothing of this kind'**
  String get actEmptyFilter;

  /// No description provided for @devNone.
  ///
  /// In en, this message translates to:
  /// **'No device matches'**
  String get devNone;

  /// No description provided for @devSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name, person or address'**
  String get devSearch;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @dtOwner.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s {type}'**
  String dtOwner(String name, String type);

  /// No description provided for @dtSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get dtSpeed;

  /// No description provided for @dtLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get dtLastSeen;

  /// No description provided for @dtAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability, 24 hours'**
  String get dtAvailability;

  /// No description provided for @dtNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get dtNow;

  /// No description provided for @dtSpeedMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms typical'**
  String dtSpeedMs(int ms);

  /// No description provided for @dtAvailPct.
  ///
  /// In en, this message translates to:
  /// **'online {pct} of the last 24 hours'**
  String dtAvailPct(String pct);

  /// No description provided for @dtTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get dtTechnical;

  /// No description provided for @dtAddress.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier address'**
  String get dtAddress;

  /// No description provided for @dtNodeId.
  ///
  /// In en, this message translates to:
  /// **'Node ID'**
  String get dtNodeId;

  /// No description provided for @dtVersion.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier version'**
  String get dtVersion;

  /// No description provided for @dtNewest.
  ///
  /// In en, this message translates to:
  /// **'newest on the network: {v}'**
  String dtNewest(String v);

  /// No description provided for @dtPaths.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get dtPaths;

  /// No description provided for @dtPathsValue.
  ///
  /// In en, this message translates to:
  /// **'{active} active · {dead} broken · IPv{family}'**
  String dtPathsValue(int active, int dead, int family);

  /// No description provided for @dtLastPacket.
  ///
  /// In en, this message translates to:
  /// **'Last packet'**
  String get dtLastPacket;

  /// No description provided for @dtSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} s ago'**
  String dtSecondsAgo(int n);

  /// No description provided for @dtMemberFor.
  ///
  /// In en, this message translates to:
  /// **'In the network for'**
  String get dtMemberFor;

  /// No description provided for @dtNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get dtNote;

  /// No description provided for @dtLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency over time'**
  String get dtLatency;

  /// No description provided for @dtWeekPrev.
  ///
  /// In en, this message translates to:
  /// **'week before {ms} ms'**
  String dtWeekPrev(int ms);

  /// No description provided for @dtPackets.
  ///
  /// In en, this message translates to:
  /// **'Packets, 30 days'**
  String get dtPackets;

  /// No description provided for @dtPacketsTotal.
  ///
  /// In en, this message translates to:
  /// **'{n} packets'**
  String dtPacketsTotal(String n);

  /// No description provided for @dtErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no packet errors in 24 hours} =1{1 packet error in 24 hours} other{{count} packet errors in 24 hours}}'**
  String dtErrors(int count);

  /// No description provided for @dtRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get dtRecent;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @netPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get netPrivate;

  /// No description provided for @netPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get netPublic;

  /// No description provided for @netCreated.
  ///
  /// In en, this message translates to:
  /// **'created {date}'**
  String netCreated(String date);

  /// No description provided for @netHubTitle.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier on {hub}'**
  String netHubTitle(String hub);

  /// No description provided for @netService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get netService;

  /// No description provided for @netOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get netOnline;

  /// No description provided for @netNotOnline.
  ///
  /// In en, this message translates to:
  /// **'Not answering'**
  String get netNotOnline;

  /// No description provided for @netVersionPort.
  ///
  /// In en, this message translates to:
  /// **'{v} · port {port}'**
  String netVersionPort(String v, String port);

  /// No description provided for @netTcpFallback.
  ///
  /// In en, this message translates to:
  /// **'TCP fallback'**
  String get netTcpFallback;

  /// No description provided for @netForced.
  ///
  /// In en, this message translates to:
  /// **'Forced TCP relay'**
  String get netForced;

  /// No description provided for @netPortMapping.
  ///
  /// In en, this message translates to:
  /// **'Port mapping'**
  String get netPortMapping;

  /// No description provided for @netMetrics.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get netMetrics;

  /// No description provided for @netActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get netActive;

  /// No description provided for @netInactive.
  ///
  /// In en, this message translates to:
  /// **'not active'**
  String get netInactive;

  /// No description provided for @netOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get netOn;

  /// No description provided for @netOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get netOff;

  /// No description provided for @netUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get netUnknown;

  /// No description provided for @netNoLocal.
  ///
  /// In en, this message translates to:
  /// **'The local ZeroTier service can\'t be queried'**
  String get netNoLocal;

  /// No description provided for @netChain.
  ///
  /// In en, this message translates to:
  /// **'Configured, received, applied'**
  String get netChain;

  /// No description provided for @netConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get netConfigured;

  /// No description provided for @netApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied on {hub}'**
  String netApplied(String hub);

  /// No description provided for @netDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get netDns;

  /// No description provided for @netRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get netRoutes;

  /// No description provided for @netAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get netAddresses;

  /// No description provided for @netNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get netNone;

  /// No description provided for @netNotReceived.
  ///
  /// In en, this message translates to:
  /// **'not received'**
  String get netNotReceived;

  /// No description provided for @netNotApplied.
  ///
  /// In en, this message translates to:
  /// **'not applied'**
  String get netNotApplied;

  /// No description provided for @netConsentOff.
  ///
  /// In en, this message translates to:
  /// **'not allowed on the hub'**
  String get netConsentOff;

  /// No description provided for @netYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get netYes;

  /// No description provided for @netPerf.
  ///
  /// In en, this message translates to:
  /// **'Performance over time'**
  String get netPerf;

  /// No description provided for @netOnlineNow.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get netOnlineNow;

  /// No description provided for @netTypical.
  ///
  /// In en, this message translates to:
  /// **'Typical latency'**
  String get netTypical;

  /// No description provided for @netAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability, 24 h'**
  String get netAvailability;

  /// No description provided for @netOutages.
  ///
  /// In en, this message translates to:
  /// **'Drops, 24 h'**
  String get netOutages;

  /// No description provided for @netVsWeek.
  ///
  /// In en, this message translates to:
  /// **'{pct} vs last week'**
  String netVsWeek(String pct);

  /// No description provided for @netLatencyBy.
  ///
  /// In en, this message translates to:
  /// **'Latency by device'**
  String get netLatencyBy;

  /// No description provided for @netAvailGrid.
  ///
  /// In en, this message translates to:
  /// **'Availability, 24 hours'**
  String get netAvailGrid;

  /// No description provided for @netRelays.
  ///
  /// In en, this message translates to:
  /// **'Through a relay'**
  String get netRelays;

  /// No description provided for @netTraffic.
  ///
  /// In en, this message translates to:
  /// **'Network traffic, 30 days'**
  String get netTraffic;

  /// No description provided for @netTcpShare.
  ///
  /// In en, this message translates to:
  /// **'TCP share {pct}'**
  String netTcpShare(String pct);

  /// No description provided for @netMetricsOff.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier metrics are off'**
  String get netMetricsOff;

  /// No description provided for @netTop.
  ///
  /// In en, this message translates to:
  /// **'Traffic by person'**
  String get netTop;

  /// No description provided for @netVersions.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier versions'**
  String get netVersions;

  /// No description provided for @netComposition.
  ///
  /// In en, this message translates to:
  /// **'Devices by type'**
  String get netComposition;

  /// No description provided for @netDevicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device} other{{count} devices}}'**
  String netDevicesCount(int count);

  /// No description provided for @stateOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get stateOnline;

  /// No description provided for @meOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get meOnlineTitle;

  /// No description provided for @netLocalTokenUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Netmap can\'t read ZeroTier\'s token: the file is readable only by root. Use the current image (it reads the token as root, then drops privileges) or set ZT_AUTHTOKEN.'**
  String get netLocalTokenUnreadable;

  /// No description provided for @netLocalTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier\'s token isn\'t there: mount the zerotier volume or set ZT_AUTHTOKEN.'**
  String get netLocalTokenMissing;

  /// No description provided for @netLocalRefused.
  ///
  /// In en, this message translates to:
  /// **'The local ZeroTier service doesn\'t answer: Netmap must share the ZeroTier container\'s network (network_mode: service:zerotier).'**
  String get netLocalRefused;

  /// No description provided for @netLocalTimeout.
  ///
  /// In en, this message translates to:
  /// **'The local ZeroTier service is too slow to answer.'**
  String get netLocalTimeout;

  /// No description provided for @netLocalUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The local ZeroTier service refuses the token: check ZT_AUTHTOKEN.'**
  String get netLocalUnauthorized;

  /// No description provided for @inactiveShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{+{count} inactive}}'**
  String inactiveShort(int count);

  /// No description provided for @revoked.
  ///
  /// In en, this message translates to:
  /// **'revoked'**
  String get revoked;

  /// No description provided for @availAgo24.
  ///
  /// In en, this message translates to:
  /// **'24 h ago'**
  String get availAgo24;

  /// No description provided for @availNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get availNow;

  /// No description provided for @chartMedian.
  ///
  /// In en, this message translates to:
  /// **'{v} median'**
  String chartMedian(int v);

  /// No description provided for @chartPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'{v} week before'**
  String chartPrevWeek(int v);

  /// No description provided for @dtMedianP95.
  ///
  /// In en, this message translates to:
  /// **'median {median} ms · p95 {p95} ms'**
  String dtMedianP95(int median, int p95);

  /// No description provided for @netReceivedValue.
  ///
  /// In en, this message translates to:
  /// **'received: {value}'**
  String netReceivedValue(String value);

  /// No description provided for @netId.
  ///
  /// In en, this message translates to:
  /// **'Network ID'**
  String get netId;

  /// No description provided for @devicesOfType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, pc{{count, plural, =1{1 computer} other{{count} computers}}} laptop{{count, plural, =1{1 laptop} other{{count} laptops}}} phone{{count, plural, =1{1 phone} other{{count} phones}}} tablet{{count, plural, =1{1 tablet} other{{count} tablets}}} tv{{count, plural, =1{1 TV} other{{count} TVs}}} server{{count, plural, =1{1 server} other{{count} servers}}} console{{count, plural, =1{1 console} other{{count} consoles}}} other{{count, plural, =1{1 other device} other{{count} other devices}}}}'**
  String devicesOfType(String type, int count);

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'Nothing has changed yet.'**
  String get noEvents;

  /// No description provided for @dtVia.
  ///
  /// In en, this message translates to:
  /// **'Goes through'**
  String get dtVia;

  /// No description provided for @dtViaLocal.
  ///
  /// In en, this message translates to:
  /// **'the hub\'s local network'**
  String get dtViaLocal;

  /// No description provided for @dtViaInternet.
  ///
  /// In en, this message translates to:
  /// **'the internet'**
  String get dtViaInternet;

  /// No description provided for @dtViaRelay.
  ///
  /// In en, this message translates to:
  /// **'a relay'**
  String get dtViaRelay;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'it':
      return LIt();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
