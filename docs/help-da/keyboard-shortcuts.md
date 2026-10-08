---
title: Tastatur og genveje
slug: keyboard-shortcuts
section: Tilpasning
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander er bygget til at blive styret fra tastaturet. Den leveres med to færdiglavede genvejsskemaer og lader dig ombinde enhver kommando til de taster, du foretrækker. Hvis du kommer fra en klassisk topanels filhåndtering, kan du beholde de taster, du allerede kender; hvis du hellere vil bruge velkendte Mac-kombinationer, skift til macOS-skemaet med ét klik. En søgbar kommandobrowser lader dig opdage alt, hvad appen kan, og køre enhver kommando efter navn.

## Skift tastaturskema

1. Åbn **Indstillinger** (Cmd+, eller **Konfiguration > Indstillinger…**), og vælg siden **Tastatur**.
2. Vælg et skema i menuen **Skema**:
   - **Total Commander (klassisk)** (standard) beholder de traditionelle taster, med Ctrl-baserede kombinationer såsom Ctrl+R for at opdatere et panel.
   - **macOS** knytter de samme handlinger til velkendte Mac-taster, hvor det giver mening, for eksempel Cmd+C for at kopiere filer og Cmd+F for at søge.
3. Ændringen træder i kraft med det samme på tværs af menuerne og genvejslinjen. **Rediger genveje…** sidder lige nedenunder, fordi individuelle ombindinger lægges oven på det skema, du har valgt.

## Tilpas genveje

1. Vælg **Konfiguration > Rediger genveje…**, eller klik på **Rediger genveje…** på siden Tastatur i Indstillinger.
2. Find en kommando ved hjælp af søgefeltet, og vælg derefter dens række.
3. Klik på **Optag…** og tryk på den tastekombination, du vil have. Den tildeles med det samme.
4. Hvis den kombination allerede blev brugt af en anden kommando, fortæller en meddelelse, hvilken kommando den blev taget fra.
5. Brug **Ryd** for at fjerne en kommandos genvej, eller **Gendan standarder** for at kassere alle dine ændringer og vende tilbage til skemaets oprindelige taster.

![Tastaturgenveje-editoren der viser kommandoer med deres tildelte taster](screenshots/keys-editor.png)
*(Figur: søg efter en kommando, og brug derefter Optag, Ryd eller Gendan standarder for at ændre dens genvej.)*

## Gennemse alle kommandoer

1. Vælg **Konfiguration > Kommandobrowser…**.
2. Skriv i søgefeltet for at filtrere efter navn, kategori eller beskrivelse.
3. Dobbeltklik på en kommando, eller vælg den og klik på **Kør**, for at udføre den på det aktive panel.

![Kommandobrowseren der viser en søgbar liste over kommandoer](screenshots/command-browser.png)
*(Figur: hver kommando i én søgbar liste, med en kort beskrivelse af hver.)*

## Genveje

| Handling | Menusti |
|---|---|
| Vælg et skema | Indstillinger > Tastatur > Skema |
| Rediger genveje | Konfiguration > Rediger genveje… |
| Gennemse alle kommandoer | Konfiguration > Kommandobrowser… |
| Opdater det aktive panel | F2 (også Ctrl+R) |

## Bemærkninger

- Dine tilpassede genveje gemmes automatisk og lægges oven på det aktive skema. At skifte skema beholder dine personlige tilsidesættelser.
- Kommandoer, der ikke er tilgængelige i den aktuelle kontekst, vises nedtonet i både genvejseditoren og kommandobrowseren.
- For at bruge funktionstasterne (F1–F12) direkte, slå **Brug F1-, F2- osv.-tasterne som standardfunktionstaster** til i Systemindstillinger > Tastatur. Ellers hold **Fn**-tasten sammen med funktionstasten.
