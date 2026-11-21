# Netmap glossary · Glossario

One name per concept, in every page. Tone: plain words, second person, technical only one level deeper (in "Technical details" / "Dettagli tecnici" and on the Network page).

Un nome solo per ogni concetto, in ogni pagina. Tono: parole semplici, seconda persona, tecnico solo un livello più in profondità.

## How a device is connected · Come è collegato un dispositivo

Every device is a circle. Each state has a colour and a word, never colour alone; on the map each state has its own lane, and relay and no-reply devices carry a small badge.

| Italiano | English | Meaning | Look |
| :--- | :--- | :--- | :--- |
| **Diretto** | **Direct** | online with a direct path, on the hub's local network or over the internet; which of the two is a technical detail ("Passa da" / "Goes through") | green circle |
| **Online** | **Online** | online, but whether direct or relayed is unknown: the hub's local ZeroTier service can't be read. Never shown as direct | teal circle, no badge |
| **Tramite relay** | **Through a relay** | online without a direct path: it works, slower | amber circle, route badge |
| **Senza risposta** | **No reply** | the hub reaches it but gets no answer (half-open path) | red circle, arrow badge |
| **Offline** | **Offline** | not online now | grey circle, in the Offline lane |
| **Inattivo** | **Inactive** | offline for more than 7 days: always shown, dimmed | dimmed |

## People and places · Persone e luoghi

| Italiano | English | Meaning |
| :--- | :--- | :--- |
| Tu | You | the viewer's own device (from `/api/whoami`): a ring around it; on the map your own devices are labelled "Tu"/"You" |
| Hub | Hub | the member at the centre of the map (`HUB_NODE_NAME`), usually the host |
| Persona | Person | owner, read from the device name (`person-type`) |
| Dispositivo | Device | a ZeroTier member. "Nodo"/"node" appears only in "ID nodo"/"Node ID" |
| Corsia | Lane | on the map, a row of devices in one state (Diretto, Online, Tramite relay, Senza risposta, Offline, Inattivo), joined to the hub by a line in its colour; in it each person's devices sit together, two or more under their owner's name |
| Rete | Network | the ZeroTier network |
| Servizio | Service | something reachable inside the network (`services.json`), with "Apri"/"Open" |
| Richiesta di accesso | Access request | a member waiting for authorization; authorized in ZTNET, never in Netmap |

## Numbers · Numeri

| Italiano | English | Meaning |
| :--- | :--- | :--- |
| Velocità | Speed | plain level: the device's typical latency, "66 ms di solito" / "66 ms typical" |
| Latenza | Latency | technical level (details, Network page): the same measure in ms, with median, p95, the week before |
| Latenza tipica | Typical latency | median of the device medians of online, direct devices |
| Disponibilità | Availability | share of the last 24 hours online (60 slots of 24 minutes); drawn as one strip, "24 h fa" … "ora": darker = more online, full grey cell = offline, low tick = no data |
| Ultimo contatto | Last seen | when the device was last heard from |
| Pacchetti | Packets | ZeroTier counts packets per device, not bytes |
| Disconnessioni | Drops | devices going offline; several in the same poll are one incident |
| Latenza alta | High latency | a latency spike, much above the device's own median |

## Words not to use · Parole da non usare

- it: "LAN", "relè", "scollegato", "staccato", "unidirezionale", "half-open", "peer", "nodo" (except "ID nodo")
- en: "LAN", "relayed", "disconnected", "unidirectional", "half-open", "peer", "node" (except "Node ID")

`test/l10n_test.dart` checks these lists and that the two languages have the same messages.
