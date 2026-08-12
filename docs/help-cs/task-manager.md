---
title: Task Manager
slug: task-manager
section: Zásuvné moduly
order: 125
related: [plugins, viewing-files, deleting-files]
---

Zásuvný modul Task Manager promění běžící procesy vašeho Macu ve složku, kterou můžete procházet. Objeví se jako disk **TaskManager** v liště disků; otevřete jej a každý proces je řádek, který můžete řadit, zkoumat jako soubor nebo ukončit — pomocí stejných kláves, jaké již používáte pro soubory. Je to zásuvný modul, takže jej můžete vypnout nebo odebrat v nabídce **Konfigurace ▸ Zásuvné moduly…**.

## Otevření

1. Klepněte na položku **📊 TaskManager** v liště disků (sedí hned za vaším spouštěcím diskem).
2. Panel se naplní jedním řádkem na každý běžící proces. Název každého řádku tvoří název procesu následovaný jeho PID, například `Finder (462)`.
3. Tlačítko **TaskManager** zůstává vybrané, dokud jste uvnitř, a karta nese název jednotky. Přepněte na jinou kartu a zpět — nebo aplikaci ukončete a znovu otevřete — a karta se vrátí k seznamu procesů. Odejdete z ní přechodem o úroveň výš nebo klepnutím na jiný svazek v liště jednotek.

![Task Manager uvádějící běžící procesy se sloupci PID, CPU, paměť a příkaz](screenshots/task-manager.png)
*(Obrázek: běžící procesy zobrazené jako seznam souborů, který můžete řadit a nad nímž můžete provádět akce.)*

## Co znamená každý sloupec

Vedle obvyklých sloupců Velikost (paměť) a Datum (čas spuštění) přidává Task Manager sloupce procesů:

| Sloupec | Význam |
| --- | --- |
| **PID** | ID procesu |
| **CPU %** | Nedávné využití procesoru (objeví se až po druhém obnovení) |
| **Threads** | Počet vláken |
| **State** | R běžící · S spící · T zastavený · Z zombie · I nečinný |
| **User** | Vlastník |
| **PPID** | ID rodičovského procesu |
| **Command** | Úplný příkazový řádek |

Řaďte podle kteréhokoli sloupce (například CPU % nebo Velikost/paměť) stejně jako v běžné složce.

## Zkoumání nebo ukončení procesu

- **Zobrazit (F3)** zobrazí report *Process Information*: název, PID, rodiče, uživatele, stav, vlákna, paměť, CPU, čas spuštění, cestu ke spustitelnému souboru a úplný příkazový řádek.
- **Smazat (F8)** ukončí proces. První smazání pošle šetrné **ukončení** (SIGTERM); smazání procesu, který stále běží, podruhé eskaluje na **vynucené ukončení** (SIGKILL). Zásuvný modul nikdy necílí na PID 1.

## Poznámky

- Základní údaje (PID, rodič, uživatel, stav) jsou čitelné u každého procesu, jako u `ps`. Paměť, vlákna a CPU lze číst pouze u **vašich vlastních** procesů; ostatní procesy zobrazují tyto sloupce prázdné (vyžadují zvýšená oprávnění, což bude přidáno později).
- CPU % je změna mezi dvěma vzorky, takže je prázdné, dokud se panel neobnoví podruhé (panel se obnovuje zhruba každé dvě sekundy).
- Seznam je pouze pro čtení kromě ukončení procesu — nelze do něj kopírovat soubory.
