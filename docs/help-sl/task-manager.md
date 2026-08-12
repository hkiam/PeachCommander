---
title: Task Manager
slug: task-manager
section: Vtičniki
order: 125
related: [plugins, viewing-files, deleting-files]
---

Vtičnik Task Manager spremeni izvajajoče se procese na vašem Macu v mapo, po kateri lahko brskate. Pojavi se kot disk **TaskManager** v vrstici diskov; odprite ga in vsak proces je vrstica, ki jo lahko razvrstite, preučite kot datoteko ali končate — z istimi tipkami, ki jih že uporabljate za datoteke. Ker gre za vtičnik, ga lahko izklopite ali odstranite v **Konfiguracija ▸ Vtičniki…**.

## Odpiranje

1. Kliknite vnos **📊 TaskManager** v vrstici diskov (nahaja se takoj za vašim zagonskim diskom).
2. Podokno se napolni z eno vrstico na izvajajoči se proces. Ime vsake vrstice je ime procesa, ki mu sledi njegov PID, na primer `Finder (462)`.
3. Gumb **TaskManager** ostane izbran, dokler ste v njem, zavihek pa nosi ime pogona. Preklopite na drug zavihek in nazaj — ali zaprite in znova odprite program — in zavihek se vrne na seznam procesov. Zapustite ga tako, da greste raven višje ali kliknete drug nosilec v vrstici pogonov.

![Task Manager, ki našteva izvajajoče se procese s stolpci PID, CPU, pomnilnik in ukaz](screenshots/task-manager.png)
*(Slika: izvajajoči se procesi, prikazani kot seznam datotek, ki ga lahko razvrstite in nad njim izvajate dejanja.)*

## Kaj pomeni vsak stolpec

Poleg običajnih stolpcev Velikost (pomnilnik) in Datum (čas zagona) Task Manager doda procesne stolpce:

| Stolpec | Pomen |
| --- | --- |
| **PID** | ID procesa |
| **CPU %** | Nedavna uporaba procesorja (za prikaz potrebuje drugo osvežitev) |
| **Niti** | Število niti |
| **Stanje** | R teče · S spi · T ustavljen · Z zombi · I nedejaven |
| **Uporabnik** | Lastnik |
| **PPID** | ID nadrejenega procesa |
| **Ukaz** | Celotna ukazna vrstica |

Razvrstite po katerem koli stolpcu (na primer CPU % ali Velikost/pomnilnik), tako kot bi v običajni mapi.

## Preučitev ali končanje procesa

- **Poglej (F3)** prikaže poročilo *Informacije o procesu*: ime, PID, nadrejeni proces, uporabnik, stanje, niti, pomnilnik, CPU, čas zagona, pot do izvedljive datoteke in celotno ukazno vrstico.
- **Izbriši (F8)** konča proces. Prvo brisanje pošlje nežen **izhod** (SIGTERM); ponovno brisanje procesa, ki še vedno teče, stopnjuje na **prisilni izhod** (SIGKILL). Vtičnik nikoli ne cilja na PID 1.

## Opombe

- Osnovne podrobnosti (PID, nadrejeni proces, uporabnik, stanje) je mogoče prebrati za vsak proces, tako kot `ps`. Pomnilnik, niti in CPU je mogoče prebrati le za **vaše lastne** procese; drugi procesi prikazujejo te stolpce prazne (potrebujejo povišane pravice, ki bodo dodane kasneje).
- CPU % je sprememba med dvema vzorcema, zato je prazen, dokler se podokno drugič ne osveži (podokno se osveži približno vsaki dve sekundi).
- Seznam je samo za branje, razen za končanje procesa — vanj ne morete kopirati datotek.
