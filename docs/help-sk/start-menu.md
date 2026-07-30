---
title: Ponuka Štart a vlastné príkazy
slug: start-menu
section: Prispôsobenie
order: 111
related: [toolbar, keyboard-shortcuts]
---

Ponuka **Štart** je vaša vlastná osobná ponuka, ktorá sedí v lište ponúk vedľa Súbor, Upraviť a ostatných. Obsahuje príkazy, ktoré si sami definujete, takže akcie, po ktorých siahate najčastejšie, sú vždy jedno kliknutie ďaleko. V tradícii klasických dvojpanelových správcov súborov môže každá položka spustiť vstavaný príkaz, spustiť externý program alebo aplikáciu, alebo skočiť rovno do priečinka. Peach Commander sa dodáva s prázdnou ponukou Štart pripravenou na to, aby ste ju naplnili.

## Ako pridať vlastné príkazy

1. Vyberte **Štart > Zmeniť ponuku Štart…**. Peach Commander otvorí váš súbor používateľských príkazov (prvýkrát ho vytvorí s komentovaným príkladom).
2. Pridajte jednu sekciu na príkaz. Každá sekcia začína názvom v hranatých zátvorkách, potom niekoľkými jednoduchými kľúčmi:
   - **cmd** — čo spustiť: cestu programu, aplikáciu, vstavaný príkaz `cm_`, alebo iný z vašich príkazov.
   - **param** — parametre odovzdané programu. Zástupné symboly sa vyplnia pri spustení príkazu: `%P` (zdrojový priečinok), `%N` (aktuálny súbor), `%T` (priečinok druhého panela), `%M` (súbor druhého panela), `%S` (vybrané súbory).
   - **path** — priečinok, v ktorom začať (predvolene aktuálny priečinok).
   - **menu** — názov zobrazený v ponuke Štart.
   - **key** — voliteľná skratka, napríklad `C+S+B`.
3. Uložte súbor. Ponuka Štart sa sama aktualizuje nabudúce, keď Peach Commander stane aktívnym, takže vaše nové položky sa objavia ihneď.

## Tipy

- Na otvorenie aktuálneho priečinka v Termináli nastavte **cmd** na `open`, **param** na `-a Terminal %P`, a **menu** na `Otvoriť Terminál tu`.
- Nasmerujte **cmd** na príkaz `cm_`, aby ste vstavanej akcii dali vlastnú položku ponuky Štart a skratku.
- Poradie v súbore je poradie v ponuke, takže dajte najpoužívanejšie príkazy hore.

## Poznámky

- Celú lištu ponúk môžete tiež nahradiť vlastnou. Vyberte **Konfigurácia > Upraviť súbor ponuky…** na otvorenie súboru ponuky zasiateho z aktuálnej, plne lokalizovanej vstavanej ponuky; upravte ho voľne a vaše zmeny sa použijú nabudúce, keď sa aplikácia aktivuje. Odstráňte súbor na obnovenie štandardnej lišty ponúk.
