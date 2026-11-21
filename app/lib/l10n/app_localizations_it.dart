// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class LIt extends L {
  LIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Netmap';

  @override
  String get navMap => 'Mappa';

  @override
  String get navDevices => 'Dispositivi';

  @override
  String get navActivity => 'Attività';

  @override
  String get navNetwork => 'Rete';

  @override
  String get navMain => 'Navigazione principale';

  @override
  String get more => 'Altro';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Lingua del browser';

  @override
  String version(String version) {
    return 'Versione $version';
  }

  @override
  String get close => 'Chiudi';

  @override
  String hello(String name) {
    return 'Ciao $name';
  }

  @override
  String get stateDirect => 'Diretto';

  @override
  String get stateRelay => 'Tramite relay';

  @override
  String get stateOneWay => 'Senza risposta';

  @override
  String get stateOffline => 'Offline';

  @override
  String get stateInactive => 'Inattivo';

  @override
  String get you => 'Tu';

  @override
  String get hub => 'Hub';

  @override
  String get meDirectTitle => 'Diretto';

  @override
  String get meRelayTitle => 'Tramite relay';

  @override
  String get meOneWayTitle => 'Senza risposta';

  @override
  String get meOfflineTitle => 'Offline';

  @override
  String get meUnknownTitle => 'Dispositivo sconosciuto';

  @override
  String get loading => 'Caricamento…';

  @override
  String get copyMyAddress => 'Copia il mio indirizzo';

  @override
  String addressCopied(String ip) {
    return 'Indirizzo copiato: $ip';
  }

  @override
  String get agoNow => 'adesso';

  @override
  String agoSeconds(int n) {
    return '$n s fa';
  }

  @override
  String agoMinutes(int n) {
    return '$n min fa';
  }

  @override
  String agoHours(int n) {
    return '$n h fa';
  }

  @override
  String get agoYesterday => 'ieri';

  @override
  String agoDays(int n) {
    return '$n giorni fa';
  }

  @override
  String get verdictLoading => 'Collegamento…';

  @override
  String get verdictOk => 'Funziona tutto';

  @override
  String verdictRelay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Funziona · $count dispositivi tramite relay',
      one: 'Funziona · 1 dispositivo tramite relay',
    );
    return '$_temp0';
  }

  @override
  String get verdictTcpFallback => 'UDP è bloccato: la rete passa da TCP';

  @override
  String get verdictForceTcp => 'Il relay TCP è forzato';

  @override
  String verdictNetDrop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivi si sono disconnessi insieme',
      one: '1 dispositivo si è disconnesso',
    );
    return '$_temp0';
  }

  @override
  String get verdictNetDropMany => 'Più dispositivi si sono disconnessi insieme';

  @override
  String get verdictServerDown => 'Netmap non risponde';

  @override
  String verdictZtnetDown(String ago) {
    return 'ZTNET non risponde: dati di $ago';
  }

  @override
  String get mapLabel => 'Mappa della rete';

  @override
  String get mapHint => 'Le frecce passano da un dispositivo all\'altro, Invio lo apre, più e meno cambiano lo zoom, 0 mostra tutto.';

  @override
  String get zoomIn => 'Ingrandisci';

  @override
  String get zoomOut => 'Riduci';

  @override
  String get zoomFit => 'Mostra tutto';

  @override
  String get legend => 'Legenda';

  @override
  String get closeDetails => 'Chiudi';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String ownerOf(String name) {
    return 'di $name';
  }

  @override
  String lastSeen(String ago) {
    return 'visto $ago';
  }

  @override
  String get neverSeen => 'mai visto';

  @override
  String get typePc => 'Computer';

  @override
  String get typeLaptop => 'Portatile';

  @override
  String get typePhone => 'Telefono';

  @override
  String get typeTablet => 'Tablet';

  @override
  String get typeTv => 'TV';

  @override
  String get typeServer => 'Server';

  @override
  String get typeConsole => 'Console';

  @override
  String get typeIot => 'Altro dispositivo';

  @override
  String durMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minuti', one: '1 minuto');
    return '$_temp0';
  }

  @override
  String durHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count ore', one: '1 ora');
    return '$_temp0';
  }

  @override
  String durDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count giorni', one: '1 giorno');
    return '$_temp0';
  }

  @override
  String durMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count mesi', one: '1 mese');
    return '$_temp0';
  }

  @override
  String durYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count anni', one: '1 anno');
    return '$_temp0';
  }

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get services => 'Servizi';

  @override
  String get svcDown => 'Non risponde';

  @override
  String svcDownFor(String d) {
    return 'Non risponde da $d';
  }

  @override
  String svcApp(String app) {
    return 'App: $app';
  }

  @override
  String get open => 'Apri';

  @override
  String get details => 'Dettagli';

  @override
  String get someDevice => 'un dispositivo';

  @override
  String evOffline(String name) {
    return '$name è andato offline';
  }

  @override
  String evOnline(String name) {
    return '$name è tornato online';
  }

  @override
  String evRelay(String name) {
    return '$name ora passa da un relay';
  }

  @override
  String evDirect(String name) {
    return '$name è di nuovo diretto';
  }

  @override
  String evSpike(String name) {
    return 'Latenza alta su $name';
  }

  @override
  String evPending(String name) {
    return '$name chiede di entrare nella rete';
  }

  @override
  String evNetdrop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivi si sono disconnessi insieme',
      one: '1 dispositivo si è disconnesso',
    );
    return '$_temp0';
  }

  @override
  String get evNetdropMany => 'Più dispositivi si sono disconnessi insieme';

  @override
  String get actAll => 'Tutti';

  @override
  String get actOff => 'Offline';

  @override
  String get actOn => 'Tornati online';

  @override
  String get actPath => 'Cambi di collegamento';

  @override
  String get actSpike => 'Latenza alta';

  @override
  String get actJoin => 'Richieste';

  @override
  String get actFilter => 'Filtra le attività';

  @override
  String get actWaiting => 'In attesa';

  @override
  String actWaitingFor(String d) {
    return 'da $d';
  }

  @override
  String get actEmptyFilter => 'Niente di questo tipo';

  @override
  String get devNone => 'Nessun dispositivo corrisponde';

  @override
  String get devSearch => 'Cerca per nome, persona o indirizzo';

  @override
  String get back => 'Indietro';

  @override
  String dtOwner(String name, String type) {
    return '$type di $name';
  }

  @override
  String get dtSpeed => 'Velocità';

  @override
  String get dtLastSeen => 'Ultimo contatto';

  @override
  String get dtAvailability => 'Disponibilità, 24 ore';

  @override
  String get dtNow => 'adesso';

  @override
  String dtSpeedMs(int ms) {
    return '$ms ms di solito';
  }

  @override
  String dtAvailPct(String pct) {
    return 'online il $pct delle ultime 24 ore';
  }

  @override
  String get dtTechnical => 'Dettagli tecnici';

  @override
  String get dtAddress => 'Indirizzo ZeroTier';

  @override
  String get dtNodeId => 'ID nodo';

  @override
  String get dtVersion => 'Versione di ZeroTier';

  @override
  String dtNewest(String v) {
    return 'la più recente in rete: $v';
  }

  @override
  String get dtPaths => 'Percorsi';

  @override
  String dtPathsValue(int active, int dead, int family) {
    return '$active attivi · $dead interrotti · IPv$family';
  }

  @override
  String get dtLastPacket => 'Ultimo pacchetto';

  @override
  String dtSecondsAgo(int n) {
    return '$n s fa';
  }

  @override
  String get dtMemberFor => 'Nella rete da';

  @override
  String get dtNote => 'Nota';

  @override
  String get dtLatency => 'Latenza nel tempo';

  @override
  String dtWeekPrev(int ms) {
    return 'settimana prima $ms ms';
  }

  @override
  String get dtPackets => 'Pacchetti, 30 giorni';

  @override
  String dtPacketsTotal(String n) {
    return '$n pacchetti';
  }

  @override
  String dtErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errori di pacchetto in 24 ore',
      one: '1 errore di pacchetto in 24 ore',
      zero: 'nessun errore di pacchetto in 24 ore',
    );
    return '$_temp0';
  }

  @override
  String get dtRecent => 'Eventi recenti';

  @override
  String get copy => 'Copia';

  @override
  String get copied => 'Copiato';

  @override
  String get netPrivate => 'Privata';

  @override
  String get netPublic => 'Pubblica';

  @override
  String netCreated(String date) {
    return 'creata il $date';
  }

  @override
  String netHubTitle(String hub) {
    return 'ZeroTier su $hub';
  }

  @override
  String get netService => 'Servizio';

  @override
  String get netOnline => 'Online';

  @override
  String get netNotOnline => 'Non risponde';

  @override
  String netVersionPort(String v, String port) {
    return '$v · porta $port';
  }

  @override
  String get netTcpFallback => 'Ripiego TCP';

  @override
  String get netForced => 'Relay TCP forzato';

  @override
  String get netPortMapping => 'Mappatura porte';

  @override
  String get netMetrics => 'Metriche';

  @override
  String get netActive => 'attivo';

  @override
  String get netInactive => 'non attivo';

  @override
  String get netOn => 'attiva';

  @override
  String get netOff => 'spenta';

  @override
  String get netUnknown => 'sconosciuto';

  @override
  String get netNoLocal => 'Il servizio ZeroTier locale non si può interrogare';

  @override
  String get netChain => 'Configurato, ricevuto, applicato';

  @override
  String get netConfigured => 'Configurato';

  @override
  String netApplied(String hub) {
    return 'Applicato su $hub';
  }

  @override
  String get netDns => 'DNS';

  @override
  String get netRoutes => 'Rotte';

  @override
  String get netAddresses => 'Indirizzi';

  @override
  String get netNone => 'nessuno';

  @override
  String get netNotReceived => 'non ricevuto';

  @override
  String get netNotApplied => 'non applicato';

  @override
  String get netConsentOff => 'non consentito sull\'hub';

  @override
  String get netYes => 'sì';

  @override
  String get netPerf => 'Prestazioni nel tempo';

  @override
  String get netOnlineNow => 'Online adesso';

  @override
  String get netTypical => 'Latenza tipica';

  @override
  String get netAvailability => 'Disponibilità, 24 h';

  @override
  String get netOutages => 'Disconnessioni, 24 h';

  @override
  String netVsWeek(String pct) {
    return '$pct vs sett. prima';
  }

  @override
  String get netLatencyBy => 'Latenza per dispositivo';

  @override
  String get netAvailGrid => 'Disponibilità, 24 ore';

  @override
  String get netRelays => 'Tramite relay';

  @override
  String get netTraffic => 'Traffico di rete, 30 giorni';

  @override
  String netTcpShare(String pct) {
    return 'quota TCP $pct';
  }

  @override
  String get netMetricsOff => 'Le metriche di ZeroTier sono spente';

  @override
  String get netTop => 'Traffico per persona';

  @override
  String get netVersions => 'Versioni di ZeroTier';

  @override
  String get netComposition => 'Dispositivi per tipo';

  @override
  String netDevicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count dispositivi', one: '1 dispositivo');
    return '$_temp0';
  }

  @override
  String get stateOnline => 'Online';

  @override
  String get meOnlineTitle => 'Online';

  @override
  String get netLocalTokenUnreadable =>
      'Netmap non riesce a leggere il token di ZeroTier: il file è leggibile solo da root. Usa l\'immagine aggiornata (legge il token come root e poi rinuncia ai privilegi) o imposta ZT_AUTHTOKEN.';

  @override
  String get netLocalTokenMissing => 'Il token di ZeroTier non c\'è: monta il volume zerotier o imposta ZT_AUTHTOKEN.';

  @override
  String get netLocalRefused =>
      'Il servizio ZeroTier locale non risponde: Netmap deve condividere la rete del container ZeroTier (network_mode: service:zerotier).';

  @override
  String get netLocalTimeout => 'Il servizio ZeroTier locale è troppo lento a rispondere.';

  @override
  String get netLocalUnauthorized => 'Il servizio ZeroTier locale rifiuta il token: controlla ZT_AUTHTOKEN.';

  @override
  String inactiveShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '+$count inattivi', one: '+1 inattivo');
    return '$_temp0';
  }

  @override
  String get revoked => 'revocato';

  @override
  String get availAgo24 => '24 h fa';

  @override
  String get availNow => 'ora';

  @override
  String chartMedian(int v) {
    return '$v mediana';
  }

  @override
  String chartPrevWeek(int v) {
    return '$v sett. prima';
  }

  @override
  String dtMedianP95(int median, int p95) {
    return 'mediana $median ms · p95 $p95 ms';
  }

  @override
  String netReceivedValue(String value) {
    return 'ricevuto: $value';
  }

  @override
  String get netId => 'ID rete';

  @override
  String devicesOfType(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count computer', one: '1 computer');
    String _temp1 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count portatili', one: '1 portatile');
    String _temp2 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count telefoni', one: '1 telefono');
    String _temp3 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tablet', one: '1 tablet');
    String _temp4 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count TV', one: '1 TV');
    String _temp5 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count server', one: '1 server');
    String _temp6 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count console', one: '1 console');
    String _temp7 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count altri dispositivi', one: '1 altro dispositivo');
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
  String get noEvents => 'Non è ancora cambiato niente.';

  @override
  String get dtVia => 'Passa da';

  @override
  String get dtViaLocal => 'la rete locale dell\'hub';

  @override
  String get dtViaInternet => 'internet';

  @override
  String get dtViaRelay => 'un relay';
}
