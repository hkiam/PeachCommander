---
title: Tastatur og snarveier
slug: keyboard-shortcuts
section: Tilpasning
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander er bygget for å styres fra tastaturet. Den leveres med to ferdiglagede snarveisoppsett og lar deg binde hvilken som helst kommando på nytt til tastene du foretrekker. Kommer du fra en klassisk topanels filbehandler, kan du beholde tastene du allerede kan; vil du heller bruke kjente Mac-kombinasjoner, bytt til macOS-oppsettet med ett klikk. En søkbar kommandoutforsker lar deg oppdage alt appen kan gjøre og kjøre hvilken som helst kommando etter navn.

## Bytt tastaturoppsett

1. Åpne **Konfigurasjon**-menyen.
2. Velg **Tastaturoppsett**, og velg deretter ett:
   - **TC Classic** (standard) beholder de tradisjonelle tastene, med Ctrl-baserte kombinasjoner som Ctrl+R for å oppdatere et panel.
   - **macOS Native** tilordner de samme handlingene til kjente Mac-taster der det gir mening, for eksempel Cmd+C for å kopiere filer og Cmd+F for å søke.
3. Et hakemerke viser det aktive oppsettet. Endringen trer i kraft med en gang på tvers av menyene og snarveislinjen.

## Tilpass snarveier

1. Velg **Konfigurasjon > Tastatursnarveier…**.
2. Finn en kommando med søkefeltet, og velg deretter raden dens.
3. Klikk **Ta opp…** og trykk tastkombinasjonen du vil ha. Den tilordnes med en gang.
4. Hvis den kombinasjonen allerede ble brukt av en annen kommando, forteller en melding hvilken kommando den ble tatt fra.
5. Bruk **Tøm** for å fjerne en kommandos snarvei, eller **Gjenopprett standard** for å forkaste alle endringene dine og gå tilbake til oppsettets opprinnelige taster.

![Tastatursnarveisredigereren som lister kommandoer med de tilordnede tastene](screenshots/keys-editor.png)
*(Figur: Søk etter en kommando, og bruk deretter Ta opp, Tøm eller Gjenopprett standard for å endre snarveien.)*

## Bla gjennom alle kommandoer

1. Velg **Konfigurasjon > Kommandoutforsker…**.
2. Skriv i søkefeltet for å filtrere etter navn, kategori eller beskrivelse.
3. Dobbeltklikk en kommando, eller velg den og klikk **Kjør**, for å utføre den på det aktive panelet.

![Kommandoutforskeren som viser en søkbar liste over kommandoer](screenshots/command-browser.png)
*(Figur: Hver kommando i én søkbar liste, med en kort beskrivelse av hver.)*

## Snarveier

| Handling | Menybane |
|---|---|
| Velg det klassiske oppsettet | Konfigurasjon > Tastaturoppsett > TC Classic |
| Velg Mac-oppsettet | Konfigurasjon > Tastaturoppsett > macOS Native |
| Rediger snarveier | Konfigurasjon > Tastatursnarveier… |
| Bla gjennom alle kommandoer | Konfigurasjon > Kommandoutforsker… |
| Oppdater det aktive panelet | F2 (også Ctrl+R) |

## Merknader

- De egendefinerte snarveiene dine lagres automatisk og legges oppå det aktive oppsettet. Å bytte oppsett beholder de personlige overstyringene dine.
- Kommandoer som ikke er tilgjengelige i den gjeldende sammenhengen vises dempet i både snarveisredigereren og kommandoutforskeren.
- For å bruke funksjonstastene (F1–F12) direkte, slå på **Bruk F1-, F2- osv.-tastene som standard funksjonstaster** i Systeminnstillinger > Tastatur. Ellers, hold **Fn**-tasten sammen med funksjonstasten.
