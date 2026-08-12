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
3. Tlačidlo **TaskManager** zostáva vybrané, kým ste vnútri, a karta nesie názov jednotky. Prepnite na inú kartu a späť — alebo aplikáciu ukončite a znova otvorte — a karta sa vráti k zoznamu procesov. Opustíte ju prechodom o úroveň vyššie alebo kliknutím na iný zväzok v lište jednotiek.

![Task Manager uvádzajúci bežiace procesy so stĺpcami PID, CPU, pamäť a príkaz](screenshots/task-manager.png)
*(Obrázok: bežiace procesy zobrazené ako zoznam súborov, ktorý môžete triediť a nad ktorým môžete konať.)*

## Čo znamená každý stĺpec

Vedľa stĺpca Dátum (čas spustenia) pridáva Task Manager stĺpce procesov. Veľkosť v riadku procesu zobrazuje `DIR`, pretože proces je priečinok, ktorý môžete otvoriť (pozri nižšie) — pamäť má vlastné stĺpce:

| Stĺpec | Význam |
| --- | --- |
| **PID** | ID procesu |
| **CPU %** | Nedávne využitie procesora (objaví sa až po druhom obnovení) |
| **Memory** | Pamäťová stopa — za čo je tento proces zodpovedný (číslo, ktoré ukazuje Monitor aktivity) |
| **Resident** | Rezidentná veľkosť vrátane zdieľaných stránok; vyplnená pre každý proces |
| **Threads** | Počet vlákien |
| **State** | R beží · S spí · T zastavený · Z zombie · I nečinný, plus prípony, ktoré pridáva `ps` (s = vedúci relácie, + = popredie, N = nízka priorita) |
| **User** | Vlastník |
| **PPID** | ID nadradeného procesu |
| **Read** | Bajty prečítané z disku od spustenia procesu |
| **Written** | Bajty zapísané na disk od spustenia procesu |
| **Wakeups** | Prebudenia prerušením od spustenia procesu |
| **Signed** | Kto program podpísal: Apple, tím s Developer ID, ad-hoc alebo nepodpísané |
| **Command** | Úplný príkazový riadok |

Trieďte podľa ktoréhokoľvek stĺpca (napríklad CPU % alebo Veľkosť/pamäť) presne tak, ako by ste to robili v bežnom priečinku.

## Skúmanie alebo ukončenie procesu

- **Zobraziť (F3)** zobrazí správu *Informácie o procese*: názov, PID, nadradený proces, používateľ, stav, vlákna, pamäť, CPU, čas spustenia, cesta k spustiteľnému súboru a úplný príkazový riadok.
- **Odstrániť (F8)** ukončí proces. Prvé odstránenie odošle jemné **ukončenie** (SIGTERM); odstránenie procesu, ktorý stále beží, druhýkrát eskaluje na **vynútené ukončenie** (SIGKILL). Zásuvný modul nikdy nemieri na PID 1.

## Nájsť procesy, ktoré používajú súbor

Kliknite pravým tlačidlom na ľubovoľný riadok a zvoľte **Nájsť procesy podľa súboru…**, potom zadajte cestu k súboru. Každý proces, ktorý má daný súbor práve otvorený, sa zvýrazní a kurzor skočí na prvý z tých, ktoré ho môžu zmeniť:

- **Modrá** — proces súbor iba číta.
- **Oranžová** — proces doň iba zapisuje.
- **Fialová** — proces robí oboje.

Cesta sa predvyplní z kurzora v druhom paneli, takže môžete na súbor ukázať tam a spýtať sa bez písania. **Nájsť proces podľa portu…** v tej istej ponuke odpovedá na príbuznú otázku: ktorý proces počúva na porte TCP/UDP. Voľbou **Zrušiť zvýraznenie súboru** farby odstránite; opustenie zoznamu procesov ich odstráni tiež.

## Otvorte proces a uvidíte jeho súbory

Stlačte na procese Enter — alebo naň dvakrát kliknite — a panel vypíše súbory, ktoré má tento proces práve otvorené, ako bežné riadky súborov so skutočnou veľkosťou a dátumom. Odtiaľ:

- **Zobraziť (F3)** otvorí samotný súbor.
- **Prejsť na súbor** ho ukáže v druhom paneli, kde s ním môžete pracovať.
- **Zobraziť vo Finderi** ho odovzdá Finderu.

Počítajú sa len otvorené súbory: knižnica, ktorú proces iba namapoval do pamäte, ani jeho pracovný adresár otvorenými súbormi nie sú. Proces iného používateľa zobrazí prázdny priečinok.

## Poznámky

- Základné údaje (PID, rodič, používateľ, stav, podpis) sú čitateľné pri každom procese. Pamäťová stopa, vlákna, diskové I/O a zoznam otvorených súborov sú čitateľné pri **vašich vlastných** procesoch, čo je na bežnom Macu väčšina zoznamu. Pri procesoch iných používateľov sa CPU a Resident plnia z `ps` — priemer za celý život procesu namiesto rozdielu dvoch meraní, ktorý nesú ostatné riadky — a vlákna a stopa zostávajú prázdne.
- CPU % je zmena medzi dvoma vzorkami, takže zostáva prázdne, kým sa panel neobnoví druhýkrát (panel sa obnovuje zhruba každé dve sekundy).
- Zoznam je len na čítanie okrem ukončenia procesu — nemôžete doň kopírovať súbory.
- Farby zvýraznenia sa riadia vaším farebným motívom: paleta Norton používa namiesto toho zelenú, červenú a purpurovú.
- Nájdu sa len popisovače, do ktorých smie váš účet nahliadnuť, čo v praxi znamená vaše vlastné procesy. Knižnica, ktorú proces iba namapoval do pamäte, ani jeho pracovný adresár nie sú otvorené popisovače a nehlásia sa.
- Stĺpec **Signed** sa dopĺňa počas prvých sekúnd: prečítanie podpisu trvá približne milisekundu a rôznych programov sú stovky, takže sa ich pri každom obnovení prečíta niekoľko a potom sa zapamätajú. Prázdna bunka znamená „zatiaľ neprečítané“, nie „nepodpísané“.
- **Signed** hovorí, kto program podpísal, nie či je notarizovaný: overenie notarizácie znamená vypočítať hash celého programu, čo by pri každom trvalo sekundy.
- Rýchly filter (Ctrl+S) tu zodpovedá aj stĺpcom, nielen názvu, a výraz môže pomenovať stĺpec, ktorého sa týka: `user:root state:R` sa pýta, čo práve beží pod rootom. Výrazy sa oddeľujú medzerami a musia platiť všetky; text, ktorý nepomenuje žiadny stĺpec, zostáva jedným jednoduchým podreťazcom vrátane medzier.
