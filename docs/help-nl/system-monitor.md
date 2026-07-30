---
title: System Monitor
slug: system-monitor
section: Plug-ins
order: 124
related: [plugins, settings]
---

De System Monitor-plug-in plaatst een live-uitlezing van de activiteit van je Mac direct in de titelbalk van het venster: kleine chips voor CPU, geheugen, schijf, netwerk en — waar de hardware ze biedt — GPU, batterij en sensoren. Elke chip wordt eens per seconde bijgewerkt; klik op er een voor een pop-up met een geschiedenisgrafiek en een gedetailleerd overzicht. Het is een plug-in, dus je kunt hem inschakelen, configureren of verwijderen via **Configuratie ▸ Plug-ins…**.

## De chips in de titelbalk

Als de plug-in aanstaat, staat er een rij compacte chips in de titelbalk. Elke chip bestaat uit een gekleurde stip, een kort label en een live-waarde (sommige met een ingebedde sparkline):

| Chip | Toont |
| --- | --- |
| **CPU** | Processorbelasting, met detail per core |
| **RAM** | Gebruikt / totaal geheugen (plus wired, gecomprimeerd, swap) |
| **HDD** | Ruimte op het startvolume en lees-/schrijfdoorvoer |
| **Net** | Download- / uploadsnelheden en -totalen |
| **GPU** · **Batt** · **Sens** | GPU-gebruik · batterijlading & -status · ventilatorsnelheden en temperaturen |

Klik op een chip om een pop-up te openen met de grote huidige waarde, een **HISTORY**-sparkline, een sleutel/waarde-lijst met **DETAILS** en — voor de CPU — een lijst **CORE LOAD** met balken per core.

## Configureren

Kies **Opdrachten ▸ System Monitor…** (of open **Configuratie ▸ Instellingen ▸ System Monitor**) om de uitlezing te configureren:

- **Systeemmonitor in titelbalk tonen** — de hoofdschakelaar aan/uit voor de chips.
- **Profiel** — de voorinstellingen *Minimaal*, *Gemiddeld* of *Maximaal* die een zinvolle set modules kiezen.
- **De moduletabel** — schakel elke module (CPU, GPU, RAM, HDD, Net, Batt, Sens) in of uit, kies de kleur ervan en sleep rijen om de volgorde te bepalen waarin ze in de titelbalk verschijnen. Modules die je hardware niet kan rapporteren, worden getoond als *(n/a)*.

![De instellingen van System Monitor met de moduletabel, profielen en kleuren per module](screenshots/system-monitor.png)
*(Afbeelding: kies welke modules verschijnen, hun kleuren en hun volgorde.)*

## Opmerkingen

- Alles wordt gemeten, nooit verzonnen: modules waarvan de hardware de gegevens niet biedt (vaak GPU of sensoren op sommige Macs) blijven onbeschikbaar in plaats van verzonnen getallen te tonen. Batterij is niet beschikbaar op desktops.
- Het bemonsteren draait op een achtergrondtimer, alleen zolang de uitlezing zichtbaar is, en bewaart ongeveer 30 minuten geschiedenis voor de grafieken.
- Je modulekeuzes, kleuren en volgorde worden bewaard bij de configuratie van de app.
