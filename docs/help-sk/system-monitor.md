---
title: System Monitor
slug: system-monitor
section: Zásuvné moduly
order: 124
related: [plugins, settings]
---

Zásuvný modul System Monitor vkladá živý odpočet aktivity vášho Macu priamo do titulnej lišty okna: malé čipy pre procesor, pamäť, disk, sieť a — kde to hardvér poskytuje — GPU, batériu a senzory. Každý čip sa aktualizuje raz za sekundu; kliknite na niektorý pre vyskakovacie okno s grafom histórie a podrobným rozpisom. Keďže ide o zásuvný modul, môžete ho povoliť, konfigurovať alebo odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Čipy v titulnej lište

Keď je zásuvný modul zapnutý, v titulnej lište sedí rad kompaktných čipov. Každý čip je farebná bodka, krátky štítok a živá hodnota (niektoré s vloženou sparkline):

| Čip | Zobrazuje |
| --- | --- |
| **CPU** | Zaťaženie procesora, s detailom na jadro |
| **RAM** | Použitá / celková pamäť (plus rezervovaná, komprimovaná, swap) |
| **HDD** | Miesto na spúšťacom zväzku a priepustnosť čítania/zápisu |
| **Net** | Rýchlosti a súčty sťahovania / odosielania |
| **GPU** · **Batt** · **Sens** | Využitie GPU · nabitie a stav batérie · otáčky ventilátorov a teploty |

Kliknite na čip pre otvorenie vyskakovacieho okna s veľkou aktuálnou hodnotou, sparkline **HISTORY**, zoznamom kľúč/hodnota **DETAILS** a — pri procesore — zoznamom **CORE LOAD** s pruhmi na jadro.

## Konfigurácia

Vyberte **Príkazy ▸ System Monitor…** (alebo otvorte **Konfigurácia ▸ Nastavenia ▸ System Monitor**) na konfiguráciu odpočtu:

- **Zobraziť monitor systému v titulnej lište** — hlavný vypínač pre čipy.
- **Profil** — predvoľby *Minimálny*, *Stredný* alebo *Maximálny*, ktoré vyberú zmysluplnú sadu modulov.
- **Tabuľka modulov** — zapnite alebo vypnite každý modul (CPU, GPU, RAM, HDD, Net, Batt, Sens), vyberte jeho farbu a ťahaním riadkov nastavte poradie, v akom sa objavia v titulnej lište. Moduly, ktoré váš hardvér nedokáže hlásiť, sa zobrazia ako *(n/a)*.

![Nastavenia System Monitor s tabuľkou modulov, profilmi a farbami na modul](screenshots/system-monitor.png)
*(Obrázok: vyberte, ktoré moduly sa objavia, ich farby a ich poradie.)*

## Poznámky

- Všetko je merané, nikdy predstierané: moduly, ktorých údaje hardvér neposkytuje (často GPU alebo senzory na niektorých Macoch), zostávajú nedostupné namiesto zobrazovania vymyslených čísel. Na stolových počítačoch je batéria nedostupná.
- Vzorkovanie beží na časovači na pozadí iba počas toho, čo je odpočet viditeľný, a uchováva približne 30 minút histórie pre grafy.
- Vaša voľba modulov, farby a poradie sa uložia s konfiguráciou aplikácie.
