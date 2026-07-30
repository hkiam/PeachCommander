---
title: Task Manager
slug: task-manager
section: Zásuvné moduly
order: 125
related: [plugins, viewing-files, deleting-files]
---

Zásuvný modul Task Manager premení bežiace procesy na vašom Macu na priečinok, ktorý môžete prehliadať. Objaví sa ako disk **TaskManager** v lište diskov; otvorte ho a každý proces je riadok, ktorý môžete triediť, skúmať ako súbor alebo ukončiť — pomocou tých istých klávesov, ktoré už používate pre súbory. Keďže ide o zásuvný modul, môžete ho vypnúť alebo odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Otvorenie

1. Kliknite na položku **📊 TaskManager** v lište diskov (sedí hneď za vaším spúšťacím diskom).
2. Panel sa zaplní jedným riadkom na bežiaci proces. Názov každého riadka je názov procesu nasledovaný jeho PID, napríklad `Finder (462)`.

![Task Manager uvádzajúci bežiace procesy so stĺpcami PID, CPU, pamäť a príkaz](screenshots/task-manager.png)
*(Obrázok: bežiace procesy zobrazené ako zoznam súborov, ktorý môžete triediť a nad ktorým môžete konať.)*

## Čo znamená každý stĺpec

Popri obvyklých stĺpcoch Veľkosť (pamäť) a Dátum (čas spustenia) pridáva Task Manager stĺpce procesov:

| Stĺpec | Význam |
| --- | --- |
| **PID** | ID procesu |
| **CPU %** | Nedávne využitie procesora (objaví sa až po druhom obnovení) |
| **Threads** | Počet vlákien |
| **State** | R beží · S spí · T zastavený · Z zombie · I nečinný |
| **User** | Vlastník |
| **PPID** | ID nadradeného procesu |
| **Command** | Úplný príkazový riadok |

Trieďte podľa ktoréhokoľvek stĺpca (napríklad CPU % alebo Veľkosť/pamäť) presne tak, ako by ste to robili v bežnom priečinku.

## Skúmanie alebo ukončenie procesu

- **Zobraziť (F3)** zobrazí správu *Informácie o procese*: názov, PID, nadradený proces, používateľ, stav, vlákna, pamäť, CPU, čas spustenia, cesta k spustiteľnému súboru a úplný príkazový riadok.
- **Odstrániť (F8)** ukončí proces. Prvé odstránenie odošle jemné **ukončenie** (SIGTERM); odstránenie procesu, ktorý stále beží, druhýkrát eskaluje na **vynútené ukončenie** (SIGKILL). Zásuvný modul nikdy nemieri na PID 1.

## Poznámky

- Základné údaje (PID, nadradený proces, používateľ, stav) sú čitateľné pre každý proces, ako pri `ps`. Pamäť, vlákna a CPU sa dajú načítať iba pre **vaše vlastné** procesy; ostatné procesy zobrazia tieto stĺpce prázdne (vyžadujú zvýšené oprávnenia, neskorší doplnok).
- CPU % je zmena medzi dvoma vzorkami, takže zostáva prázdne, kým sa panel neobnoví druhýkrát (panel sa obnovuje zhruba každé dve sekundy).
- Zoznam je len na čítanie okrem ukončenia procesu — nemôžete doň kopírovať súbory.
