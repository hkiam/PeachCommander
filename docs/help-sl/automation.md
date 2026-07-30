---
title: Avtomatizacija (AppleScript in Bližnjice)
slug: automation
section: Napredna orodja
order: 98
related: [start-menu, settings]
---

Peach Commander je mogoče skriptirati, tako da ga lahko upravljate iz AppleScript in iz aplikacije Bližnjice. Peščica osnovnih glagolov skriptu omogoča krmarjenje po podoknih, izbiranje datotek po maski, kopiranje ali premikanje trenutnega izbora ter zagon katerega koli ukaza Peach Commander po njegovem identifikatorju — s ponovno uporabo natanko istih dejanj, ki jih uporabljajo meniji, tako da se skriptiran korak obnaša kot ročni. Priročno je za ponavljajoča se opravila: razvrščanje prenosov, pripravo izhoda gradnje ali vključitev koraka z datoteko v večjo Bližnjico.

## Ogled slovarja

1. Odprite **Urejevalnik skriptov** (v `/Programi/Pripomočki`).
2. Izberite **Okno ▸ Knjižnica**, nato dvakrat kliknite **Peach Commander** (dodajte ga z **+**, če ni na seznamu).
3. Slovar se odpre in našteje ukaze in lastnosti spodaj.

Ko skript prvič upravlja Peach Commander, macOS zaprosi za dovoljenje (**Sistemske nastavitve ▸ Zasebnost in varnost ▸ Avtomatizacija**). Odobrite ga enkrat in kasnejši skripti se izvajajo brez vprašanja.

## Kaj lahko preberete

| Lastnost | Pomen |
| --- | --- |
| `active folder` | Pot POSIX mape dejavnega podokna. |
| `inactive folder` | Pot POSIX mape drugega podokna. |
| `selection paths` | Izbrani elementi v dejavnem podoknu (ali element pod kazalko). |

## Glagoli

| Ukaz | Kaj naredi |
| --- | --- |
| `go to "<pot>" [in left\|right]` | Odpri mapo v podoknu (privzeto: dejavno podokno). |
| `select "<maska>"` | Izberi elemente v dejavnem podoknu po maski z nadomestnimi znaki, npr. `*.pdf`. |
| `copy items to "<mapa>"` | Kopiraj izbor dejavnega podokna v mapo. |
| `move items to "<mapa>"` | Premakni izbor dejavnega podokna v mapo. |
| `run command "<id>"` | Zaženi kateri koli ukaz po njegovem identifikatorju, npr. `cm_PackFiles`. |

Kopiranje in premikanje uporabljata isto vrsto prenosa v ozadju kot F5/F6, tako da se napredek in morebitni pozivi za prepis prikažejo natanko tako kot pri ročnem opravilu.

## Primer

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Uporaba iz Bližnjic

V aplikaciji **Bližnjice** dodajte dejanje **Zaženi AppleScript** in prilepite skript, kot je zgornji. To vam omogoča vključitev koraka Peach Commander v večjo Bližnjico — na primer sproženo s spremembo mape ali tipko za bližnjico.

## Opombe

- Identifikator ukaza, ki ga posredujete v `run command`, je isti identifikator `cm_*`, prikazan v brskalniku ukazov (glejte [Meni Start in poljubni ukazi](start-menu.md)).
- Skriptiranje vedno deluje na **dejavnem** podoknu; najprej uporabite `go to … in left` / `in right`, če potrebujete določeno stran.
- Peach Commander je aplikacija z enim oknom, tako da skripti ciljajo na obe podokni tega okna.
