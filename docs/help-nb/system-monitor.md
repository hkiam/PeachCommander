---
title: System Monitor
slug: system-monitor
section: Programtillegg
order: 124
related: [plugins, settings]
---

System Monitor-programtillegget plasserer en sanntidsavlesning av Mac-ens aktivitet rett i vinduets tittellinje: små brikker for CPU, minne, disk, nettverk og – der maskinvaren avslører dem – GPU, batteri og sensorer. Hver brikke oppdateres én gang i sekundet; klikk på en for et sprettoppvindu med en historikkgraf og en detaljert oversikt. Det er et programtillegg, så du kan aktivere, konfigurere eller fjerne det i **Konfigurasjon ▸ Programtillegg…**.

## Brikkene i tittellinjen

Når programtillegget er på, sitter en rad med kompakte brikker i tittellinjen. Hver brikke er en farget prikk, en kort etikett og en sanntidsverdi (noen med en innebygd minigraf):

| Brikke | Viser |
| --- | --- |
| **CPU** | Prosessorlast, med detaljer per kjerne |
| **RAM** | Brukt / totalt minne (pluss låst, komprimert, veksling) |
| **HDD** | Plass på startvolumet og les/skriv-gjennomstrømning |
| **Net** | Nedlastings- / opplastingsrater og totaler |
| **GPU** · **Batt** · **Sens** | GPU-utnyttelse · batteriladning og -tilstand · viftehastigheter og temperaturer |

Klikk på en brikke for å åpne et sprettoppvindu med den store gjeldende verdien, en **HISTORIKK**-minigraf, en **DETALJER**-liste med nøkkel/verdi og – for CPU-en – en **KJERNELAST**-liste med søyler per kjerne.

## Konfigurer det

Velg **Kommandoer ▸ System Monitor…** (eller åpne **Konfigurasjon ▸ Innstillinger ▸ System Monitor**) for å konfigurere avlesningen:

- **Vis systemovervåker i tittellinjen** – hovedbryteren av/på for brikkene.
- **Profil** – forhåndsinnstillingene *Minimal*, *Medium* eller *Maksimal* som velger et fornuftig sett med moduler.
- **Modultabellen** – slå hver modul (CPU, GPU, RAM, HDD, Net, Batt, Sens) på eller av, velg fargen dens, og dra rader for å sette rekkefølgen de vises i i tittellinjen. Moduler maskinvaren din ikke kan rapportere, vises som *(n/a)*.

![System Monitor-innstillingene med modultabellen, profilene og fargene per modul](screenshots/system-monitor.png)
*(Figur: velg hvilke moduler som vises, fargene deres og rekkefølgen deres.)*

## Merknader

- Alt måles, aldri forfalskes: moduler hvis data maskinvaren ikke avslører (ofte GPU eller sensorer på enkelte Macer), forblir utilgjengelige i stedet for å vise oppdiktede tall. Batteri er utilgjengelig på stasjonære maskiner.
- Prøvetaking kjører på en bakgrunnstimer bare mens avlesningen er synlig, og beholder omtrent 30 minutter med historikk for grafene.
- Modulvalgene, fargene og rekkefølgen din lagres med appens konfigurasjon.
