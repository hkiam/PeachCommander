---
title: Flytte og gi nytt navn
slug: moving-and-renaming
section: Filer og mapper
order: 26
related: [copying-files, multi-rename]
---

Flytting flytter filer og mapper i stedet for å duplisere dem, og det å gi nytt navn endrer navnene deres uten å røre innholdet. Fordi Peach Commander viser to paneler side om side, er flytting bare et spørsmål om å velge det du vil ha i det ene panelet og sende det til mappen som er åpen i det andre. Du kan også gi et element nytt navn på stedet, eller gi flyttede elementer nye navn underveis ved hjelp av en jokertegnmaske.

## Flytt filer til det andre panelet

1. I kildepanelet åpner du mappen som inneholder elementene du vil flytte, og åpner målmappen i det andre panelet.
2. Merk filen eller mappen du vil flytte. For å flytte flere samtidig, merk dem alle først (se *Merke filer*).
3. Trykk F6, eller velg **Filer > Flytt**.
4. Kontroller målmappen som vises i dialogen og klikk **OK** (eller trykk Return) for å starte flyttingen.

![Flyttedialogen som viser målstifeltet, alternativer og en avmerkingsboks for kø](screenshots/copy-dialog.png)
*(Figur: Flyttedialogen bruker samme målfelt som kopiering — skriv inn en sti, eller legg til en jokertegnmaske for å gi nytt navn mens du flytter.)*

Flyttinger på samme disk skjer nesten øyeblikkelig. Når målet er på en annen disk, kopierer Peach Commander elementene og fjerner deretter originalene først etter at hver fil har kommet trygt frem.

## Gi nytt navn på stedet

1. Merk én enkelt fil eller mappe.
2. Trykk Shift+F6, eller velg **Filer > Gi nytt navn**.
3. Rediger navnet direkte i panelet, og trykk deretter Return for å bekrefte eller Esc for å avbryte.

## Gi nytt navn mens du flytter

Målfeltet i flyttedialogen godtar en jokertegnmaske, slik at du kan gi elementer nytt navn mens de flyttes:

1. Merk elementene og trykk F6.
2. I målfeltet legger du til en navnemaske etter målmappen, for eksempel `/Users/du/Archive/*_backup.*`.
3. `*` står for det opprinnelige navnet og `.*` for den opprinnelige filendelsen. Bekreft for å flytte og gi nytt navn i ett steg.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Flytt til det andre panelet | F6 |
| Gi nytt navn på stedet | Shift+F6 |

## Tips

- Flyttedialogen tilbyr den samme alternativknappen og avmerkingsboksen for bakgrunnskø som kopiering, så du kan sette store flyttinger i kø og la dem kjøre i bakgrunnen.
- Flytting innenfor samme disk er en rask operasjon på stedet, så den er trygg for svært store mapper. En flytting på tvers av disker tar lengre tid fordi dataene kopieres først, og deretter slettes kilden.
- For å gi mange filer nytt navn samtidig med nummerering, søk-og-erstatt eller mønstre, bruk Verktøy for flernavning i stedet (se *Flernavning*).
