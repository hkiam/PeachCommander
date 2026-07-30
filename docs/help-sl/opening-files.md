---
title: Odpiranje datotek in map
slug: opening-files
section: Datoteke in mape
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander odpira datoteke in mape naravnost iz katerega koli podokna, pri čemer uporablja iste aplikacije in sistemske funkcije, na katere se že zanašate v Finderju. Pritisnite tipko, da element pod kazalcem odprete v njegovi privzeti aplikaciji, ali z desnim klikom odprite celoten meni dejanj — odprite z drugo aplikacijo, pokažite element v Finderju, ga delite ali odprite okno Terminala prav tam, kjer stojite.

## Odpiranje elementa

1. Kliknite datoteko ali mapo v podoknu, da nanjo postavite kazalec (označeno vrstico).
2. Pritisnite Enter (ali dvakrat kliknite).
   - Mapa se odpre v istem podoknu.
   - Datoteka se odpre v svoji privzeti aplikaciji macOS — isti aplikaciji, ki bi jo uporabil Finder.
   - Arhiv (na primer .zip) se odpre kot mapa, tako da lahko brskate po njem.

![Glavno okno Peach Commanderja z obema podoknoma, ki prikazujeta datoteke in mape](screenshots/main-window.png)
*(Slika: Postavite kazalec na kateri koli element, nato pritisnite Enter, da ga odprete.)*

## Odpiranje z drugo aplikacijo, prikaz ali deljenje

Z desnim klikom na datoteko (ali s pritiskom Shift+F10) odprite meni elementa, nato izberite:

- **Odpri** ali **Odpri v privzeti aplikaciji** — datoteko odpre, kot bi jo Enter.
- **Odpri z** — izberite katero koli nameščeno aplikacijo, ki lahko odpre to datoteko, ali izberite **Drugo …** za iskanje.
- **Quick Look** — predoglejte si datoteko brez odpiranja aplikacije.
- **Pokaži v Finderju** — pokaže datoteko izbrano v oknu Finderja.
- **Deli …** — pošljite datoteko prek lista za deljenje macOS.

Meni tudi združi standardne **Storitve** macOS za izbrano datoteko in doda **Oznake**, tako da lahko uporabite običajne barvne oznake Finderja.

## Odpiranje Terminala v trenutni mapi

Izberite **Odpri Terminal tukaj** v meniju Datoteka ali Ukazi (Cmd+Option+T), da odprete okno Terminala, ki je že usmerjeno v mapo aktivnega podokna.

## Bližnjice

| Dejanje | Tipka |
|---|---|
| Odpri element pod kazalcem | Enter |
| Ogled datoteke (pregledovalnik) | F3 |
| Urejanje datoteke | F4 |
| Predogled Quick Look | Cmd+Y |
| Prikaži informacije / lastnosti | Option+Enter |
| Odpri meni elementa | Shift+F10 ali desni klik |
| Odpri Terminal tukaj | Cmd+Option+T |

## Opombe

- »Privzeta aplikacija« pomeni aplikacijo, ki jo je macOS nastavljen uporabljati za to vrsto datotek; spremenite jo v oknu Prikaži informacije za datoteko, natanko tako kot v Finderju.
- **Pokaži v Finderju**, **Deli …** in **Odpri z ▸ Drugo …** veljajo za elemente na disku vašega Maca. Niso na voljo za elemente znotraj arhiva ali na oddaljeni povezavi (FTP/SFTP).
- Desni klik na proces v teku (v pogledu procesov) prikaže krajši meni, značilen za procese, namesto datotečnih dejanj.
