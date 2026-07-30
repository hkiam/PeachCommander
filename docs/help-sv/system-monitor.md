---
title: System Monitor
slug: system-monitor
section: Insticksprogram
order: 124
related: [plugins, settings]
---

System Monitor-insticksprogrammet placerar en avläsning i realtid av din Macs aktivitet direkt i fönstrets namnlist: små brickor för CPU, minne, disk, nätverk och — där maskinvaran exponerar dem — GPU, batteri och sensorer. Varje bricka uppdateras en gång i sekunden; klicka på en för ett popup-fönster med en historikgraf och en detaljerad uppdelning. Det är ett insticksprogram, så du kan aktivera, konfigurera eller ta bort det i **Konfiguration ▸ Insticksprogram…**.

## Brickorna i namnlisten

När insticksprogrammet är på sitter en rad kompakta brickor i namnlisten. Varje bricka är en färgad punkt, en kort etikett och ett värde i realtid (vissa med en inbäddad sparkline):

| Bricka | Visar |
| --- | --- |
| **CPU** | Processorbelastning, med detaljer per kärna |
| **RAM** | Använt/totalt minne (plus wired, komprimerat, swap) |
| **HDD** | Utrymme på startvolymen och läs/skriv-genomströmning |
| **Net** | Ned-/uppladdningshastigheter och totaler |
| **GPU** · **Batt** · **Sens** | GPU-utnyttjande · batteriladdning och tillstånd · fläkthastigheter och temperaturer |

Klicka på en bricka för att öppna ett popup-fönster med det stora aktuella värdet, en **HISTORY**-sparkline, en **DETAILS**-lista med nyckel/värde och — för CPU:n — en **CORE LOAD**-lista med staplar per kärna.

## Konfigurera det

Välj **Kommandon ▸ System Monitor…** (eller öppna **Konfiguration ▸ Inställningar ▸ System Monitor**) för att konfigurera avläsningen:

- **Visa systemövervakaren i namnlisten** — huvudströmbrytaren av/på för brickorna.
- **Profil** — förinställningarna *Minimal*, *Medium* eller *Maximal* som väljer en rimlig uppsättning moduler.
- **Modultabellen** — slå av eller på varje modul (CPU, GPU, RAM, HDD, Net, Batt, Sens), välj dess färg och dra rader för att ställa in ordningen de visas i namnlisten. Moduler som din maskinvara inte kan rapportera visas som *(n/a)*.

![Inställningarna för System Monitor med sin modultabell, profiler och färger per modul](screenshots/system-monitor.png)
*(Figur: välj vilka moduler som visas, deras färger och deras ordning.)*

## Anmärkningar

- Allt mäts, aldrig förfalskas: moduler vars data maskinvaran inte exponerar (ofta GPU eller sensorer på vissa Mac-datorer) förblir otillgängliga i stället för att visa påhittade siffror. Batteri är otillgängligt på stationära datorer.
- Sampling körs på en bakgrundstimer endast medan avläsningen är synlig, och behåller ungefär 30 minuters historik för graferna.
- Dina modulval, färger och ordning sparas med appens konfiguration.
