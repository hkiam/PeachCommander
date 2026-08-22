---
title: Probleemoplossing
slug: troubleshooting
section: Hulp en probleemoplossing
order: 140
related: [privacy-and-security, known-limitations]
---

Dit onderwerp behandelt de problemen die mensen het vaakst tegenkomen: macOS dat toegang tot bepaalde mappen blokkeert, een map die op oude inhoud lijkt vast te zitten, een beveiligde FTP-server die weigert te verbinden, en inpakken naar RAR. Elk deel vertelt wat er gebeurt en hoe je het oplost.

## macOS vraagt om toestemming, of mappen lijken leeg

Sommige locaties — zoals je map `~/Library`, mappen van andere gebruikers en systeemgebieden — worden door macOS beschermd en blijven verborgen totdat je toegang verleent. Peach Commander merkt dit op en biedt aan je naar de juiste instelling te begeleiden.

Zo'n map wordt geweigerd in plaats van leeg weergegeven, en het paneel zegt het: *macOS houdt <map> privé — zie Opdrachten ▸ Volledige schijftoegang…*. Dat is het benoemen waard, want niets eraan lijkt op een rechtenprobleem: de map is zichtbaar, hij is van jou, en zijn rechten zeggen dat je hem mag lezen. Alleen macOS zelf staat in de weg, en beheerdersrechten veranderen daar niets aan. Het paneel blijft in de map die het al toonde.

1. Kies bij de vraag om Systeeminstellingen te openen, of open het zelf.
2. Ga naar Privacy en beveiliging en vervolgens Volledige schijftoegang.
3. Zet de schakelaar naast Peach Commander aan. Staat het er niet bij, gebruik dan de knop Voeg toe.
4. Sluit Peach Commander af en open het opnieuw zodat de nieuwe toestemming van kracht wordt.

Peach Commander draait niet in een beperkte sandbox, dus zodra Volledige schijftoegang is verleend, kan het bestanden bladeren en beheren net als de Finder.

## Een map toont recente wijzigingen niet

Panelen werken zichzelf normaal bij wanneer bestanden op schijf veranderen. Als een map door een ander programma is gewijzigd, op een netwerkvolume staat of gewoon verouderd lijkt, ververs het dan handmatig.

1. Klik op het paneel dat je wilt bijwerken.
2. Druk op F2 (of Ctrl+R) om die map opnieuw in te lezen.

Netwerk- en gekoppelde volumes melden wijzigingen niet altijd aan macOS, dus daar is handmatig verversen de betrouwbare oplossing.

## Een FTPS-server maakt geen verbinding

Als een beveiligde FTP-verbinding mislukt, controleer dan deze instellingen in de verbindingsgegevens:

- Kies de beveiligingsmodus van de server: expliciet FTPS (AUTH TLS) en impliciet FTPS (poort 990) zijn niet uitwisselbaar.
- Blijft de verbinding hangen na het inloggen, wissel dan tussen passieve en actieve overdrachtsmodus — de meeste servers achter een firewall hebben passief nodig.
- Gebruikt de server een zelfondertekend certificaat, dan moet je het expliciet toestaan; anders wordt de verbinding geweigerd.
- Bevestig de host, poort, gebruikersnaam en wachtwoord, en of er op jouw netwerk een SOCKS5-proxy nodig is.

## Inpakken naar RAR doet niets

Peach Commander kan zelf ZIP-, 7z-, TAR-, TAR.GZ-, BZ2- en XZ-archieven maken. RAR is anders: omdat RAR een gesloten formaat is, vereist het maken van RAR-archieven een apart RAR-opdrachtregelprogramma dat op je Mac is geïnstalleerd. Zonder dat is RAR niet beschikbaar bij het inpakken van bestanden (Option+F5). Bestaande RAR-archieven lezen kan nog steeds door ze als een map te openen. Heb je RAR niet specifiek nodig, kies dan ZIP of 7z — beide ondersteunen sterke AES-256-versleuteling en gesplitste volumes.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| De actieve map verversen | F2 of Ctrl+R |
| Verbinden met een FTP/FTPS-server | Ctrl+F |
| Een netwerkshare koppelen | Cmd+K |
| De geselecteerde bestanden inpakken | Option+F5 |

## Opmerkingen

- Wachtwoorden en andere inloggegevens worden alleen in de macOS-sleutelhanger bewaard, nooit in platte configuratiebestanden.
- Een netwerkshare koppelen (Cmd+K, of Netwerk-menu ▸ Netwerkshare koppelen…) gebruikt dezelfde verbinding die macOS zelf gebruikt, dus hij verschijnt ook in de Finder.
- Blijft een probleem bestaan na verversen en herstarten, dan is het mogelijk een bekende beperking en geen fout — zie Bekende beperkingen.
