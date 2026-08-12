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

Vedle sloupce Datum (čas spuštění) přidává Task Manager sloupce procesů. Velikost u řádku procesu zobrazuje `DIR`, protože proces je složka, kterou lze otevřít (viz níže) — paměť má vlastní sloupce:

| Sloupec | Význam |
| --- | --- |
| **PID** | ID procesu |
| **CPU %** | Nedávné využití procesoru (objeví se až po druhém obnovení) |
| **Memory** | Stopa v paměti — za co je tento proces zodpovědný (číslo, které ukazuje Monitor aktivity) |
| **Resident** | Rezidentní velikost včetně sdílených stránek; vyplněno pro každý proces |
| **Threads** | Počet vláken |
| **State** | R běžící · S spící · T zastavený · Z zombie · I nečinný, plus přípony, které přidává `ps` (s = vedoucí relace, + = popředí, N = nízká priorita) |
| **User** | Vlastník |
| **PPID** | ID rodičovského procesu |
| **Read** | Bajty přečtené z disku od spuštění procesu |
| **Written** | Bajty zapsané na disk od spuštění procesu |
| **Wakeups** | Probuzení přerušením od spuštění procesu |
| **Signed** | Kdo program podepsal: Apple, tým s Developer ID, ad-hoc, nebo nepodepsáno |
| **Command** | Úplný příkazový řádek |

Řaďte podle kteréhokoli sloupce (například CPU % nebo Velikost/paměť) stejně jako v běžné složce.

## Zkoumání nebo ukončení procesu

- **Zobrazit (F3)** zobrazí report *Process Information*: název, PID, rodiče, uživatele, stav, vlákna, paměť, CPU, čas spuštění, cestu ke spustitelnému souboru a úplný příkazový řádek.
- **Smazat (F8)** ukončí proces. První smazání pošle šetrné **ukončení** (SIGTERM); smazání procesu, který stále běží, podruhé eskaluje na **vynucené ukončení** (SIGKILL). Zásuvný modul nikdy necílí na PID 1.

## Najít procesy, které používají soubor

Klikněte pravým tlačítkem na libovolný řádek a zvolte **Najít procesy podle souboru…**, poté zadejte cestu k souboru. Každý proces, který má daný soubor právě otevřený, se zvýrazní a kurzor skočí na první z těch, které jej mohou změnit:

- **Modrá** — proces soubor pouze čte.
- **Oranžová** — proces do něj pouze zapisuje.
- **Fialová** — proces dělá obojí.

Cesta se předvyplní z kurzoru v druhém panelu, takže můžete na soubor ukázat tam a zeptat se bez psaní. **Najít proces podle portu…** ve stejné nabídce odpovídá na příbuznou otázku: který proces naslouchá na portu TCP/UDP. Volbou **Zrušit zvýraznění souboru** barvy odstraníte; opuštění seznamu procesů je odstraní také.

## Otevřete proces a uvidíte jeho soubory

Stiskněte na procesu Enter — nebo na něj poklepejte — a panel vypíše soubory, které má tento proces právě otevřené, jako běžné řádky souborů se skutečnou velikostí a datem. Odtud:

- **Zobrazit (F3)** otevře samotný soubor.
- **Přejít na soubor** jej ukáže v druhém panelu, kde s ním můžete pracovat.
- **Zobrazit ve Finderu** jej předá Finderu.

Počítají se jen otevřené soubory: knihovna, kterou proces pouze namapoval do paměti, ani jeho pracovní adresář otevřenými soubory nejsou. Proces jiného uživatele zobrazí prázdnou složku.

## Poznámky

- Základní údaje (PID, rodič, uživatel, stav, podpis) jsou čitelné u každého procesu. Stopa v paměti, vlákna, diskové I/O a seznam otevřených souborů jsou čitelné u **vašich vlastních** procesů, což je na běžném Macu většina seznamu. U procesů jiných uživatelů se CPU a Resident plní z `ps` — celoživotní průměr namísto rozdílu dvou měření, který nesou ostatní řádky — a vlákna se stopou zůstávají prázdná.
- CPU % je změna mezi dvěma vzorky, takže je prázdné, dokud se panel neobnoví podruhé (panel se obnovuje zhruba každé dvě sekundy).
- Seznam je pouze pro čtení kromě ukončení procesu — nelze do něj kopírovat soubory.
- Barvy zvýraznění se řídí vaším barevným motivem: paleta Norton používá místo toho zelenou, červenou a purpurovou.
- Nalezeny jsou pouze popisovače, do kterých smí váš účet nahlédnout, což v praxi znamená vaše vlastní procesy. Knihovna, kterou proces pouze namapoval do paměti, ani jeho pracovní adresář nejsou otevřené popisovače a nehlásí se.
- Sloupec **Signed** se doplní během prvních sekund: přečtení podpisu trvá asi milisekundu a programů jsou stovky, takže se jich při každé aktualizaci přečte několik a pak se pamatují. Prázdná buňka znamená „zatím nepřečteno“, nikoli „nepodepsáno“.
- **Signed** říká, kdo program podepsal, ne zda je notarizovaný: ověření notarizace znamená vypočítat hash celého programu, což by u každého trvalo sekundy.
- Rychlý filtr (Ctrl+S) zde odpovídá i sloupcům, nejen názvu, a výraz může pojmenovat sloupec, na který se vztahuje: `user:root state:R` se ptá, co právě běží pod rootem. Výrazy se oddělují mezerami a musí platit všechny; text, který nepojmenuje žádný sloupec, zůstává jedním prostým podřetězcem včetně mezer.
