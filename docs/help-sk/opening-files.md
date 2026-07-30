---
title: Otváranie súborov a priečinkov
slug: opening-files
section: Súbory a priečinky
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander otvára súbory a priečinky priamo z ktoréhokoľvek panela pomocou tých istých aplikácií a systémových funkcií, na ktoré sa už spoliehate vo Finderi. Stlačením klávesu otvoríte položku pod kurzorom v jej predvolenej aplikácii alebo kliknutím pravým tlačidlom zobrazíte úplnú ponuku akcií — otvoriť inou aplikáciou, zobraziť položku vo Finderi, zdieľať ju alebo otvoriť okno Terminal priamo tam, kde práve stojíte.

## Otvorenie položky

1. Kliknutím na súbor alebo priečinok v paneli naň umiestnite kurzor (zvýraznený riadok).
2. Stlačte Enter (alebo dvakrát kliknite).
   - Priečinok sa otvorí v tom istom paneli.
   - Súbor sa otvorí v jeho predvolenej aplikácii macOS — v tej istej aplikácii, ktorú by použil Finder.
   - Archív (napríklad .zip) sa otvorí ako priečinok, takže si môžete prezrieť jeho obsah.

![Hlavné okno Peach Commander s oboma panelmi zobrazujúcimi súbory a priečinky](screenshots/main-window.png)
*(Obrázok: Umiestnite kurzor na ľubovoľnú položku a stlačením klávesu Enter ju otvorte.)*

## Otvorenie inou aplikáciou, zobrazenie alebo zdieľanie

Kliknutím pravým tlačidlom na súbor (alebo stlačením Shift+F10) otvoríte ponuku položky a potom zvoľte:

- **Otvoriť** alebo **Otvoriť v predvolenej aplikácii** — otvorí súbor rovnako ako Enter.
- **Otvoriť pomocou** — vyberte ktorúkoľvek nainštalovanú aplikáciu, ktorá dokáže tento súbor otvoriť, alebo zvoľte **Iná…** a vyhľadajte inú.
- **Quick Look** — zobrazí ukážku súboru bez otvorenia aplikácie.
- **Zobraziť vo Finderi** — zobrazí súbor vybraný v okne Finderu.
- **Zdieľať…** — odošle súbor cez panel zdieľania macOS.

Ponuka tiež zlučuje štandardné macOS **Services** pre vybraný súbor a pridáva **Menovky**, takže môžete použiť bežné farebné menovky Finderu.

## Otvorenie okna Terminal v aktuálnom priečinku

Zvoľte **Otvoriť Terminal tu** z ponuky Súbor alebo Príkazy (Cmd+Option+T) a otvoríte okno Terminal už nasmerované na priečinok aktívneho panela.

## Klávesové skratky

| Akcia | Kláves |
|---|---|
| Otvoriť položku pod kurzorom | Enter |
| Zobraziť súbor (prehliadač) | F3 |
| Upraviť súbor | F4 |
| Ukážka Quick Look | Cmd+Y |
| Informácie / vlastnosti | Option+Enter |
| Otvoriť ponuku položky | Shift+F10 alebo pravé tlačidlo |
| Otvoriť Terminal tu | Cmd+Option+T |

## Poznámky

- „Predvolená aplikácia“ znamená aplikáciu, ktorú má macOS nastavenú na daný typ súboru; zmeníte ju na paneli Informácie o súbore, presne ako vo Finderi.
- **Zobraziť vo Finderi**, **Zdieľať…** a **Otvoriť pomocou ▸ Iná…** sa vzťahujú na položky na disku vášho Macu. Nie sú dostupné pre položky vnútri archívu ani na vzdialenom pripojení (FTP/SFTP).
- Kliknutie pravým tlačidlom na spustený proces (v zobrazení procesov) zobrazí kratšiu ponuku špecifickú pre proces namiesto akcií so súbormi.
