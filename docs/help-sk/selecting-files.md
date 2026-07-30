---
title: Výber súborov
slug: selecting-files
section: Súbory a priečinky
order: 22
related: [copying-files, searching]
---

Skôr než čokoľvek skopírujete, presuniete, odstránite alebo zabalíte, najprv Peach Commanderu poviete, s ktorými položkami má pracovať. Položka, na ktorej sedí kurzor, je vždy aktuálnou položkou, ale môžete tiež *označiť* jeden alebo viacero súborov a priečinkov, aby sa príkaz vykonal na všetkých naraz. Označené položky vynikajú odlišnou farbou názvu v paneli.

## Označenie súborov a priečinkov

1. Kliknutím na riadok naň presuniete kurzor. Jedno kliknutie vyberie iba danú položku.
2. Ak chcete označiť viacero položiek naraz, podržte Cmd a kliknite na každú z nich, alebo podržte Shift a kliknutím označte rozsah.
3. Ak chcete jedným pohybom označiť položku pod kurzorom a posunúť sa nadol, stlačte Insert. Opakovaným stláčaním rýchlo označíte sériu po sebe idúcich položiek. Medzerník tiež prepína označenie aktuálnej položky (a zobrazí veľkosť priečinka).
4. Ak chcete označiť všetko v paneli, zvoľte Označiť ▸ Vybrať všetko (Ctrl+Num+) alebo stlačte Cmd+A. Voľbou Označiť ▸ Zrušiť výber všetkého (Ctrl+Num-) vymažete všetky označenia.

## Výber alebo zrušenie výberu podľa vzoru

1. Zvoľte Označiť ▸ Vybrať skupinu… (Num+), aby ste pridali položky, ktorých názvy zodpovedajú vzoru, alebo Označiť ▸ Zrušiť výber skupiny… (Num-), aby ste zodpovedajúce položky z aktuálnych označení odstránili.
2. Napíšte masku so zástupnými znakmi. Použite `*` pre ľubovoľné znaky a `?` pre jeden znak. Viacero masiek oddeľte bodkočiarkou a výnimky uveďte za zvislou čiarou — napríklad `*.jpg;*.png` označí všetky obrázky a `*.*|*.bak` označí všetko okrem záložných súborov.

![Dialóg Vybrať skupinu s maskou so zástupnými znakmi napísanou v poli vzoru](screenshots/select-by-mask.png)
*(Obrázok: Označovanie súborov maskou so zástupnými znakmi.)*

## Invertovanie, rovnaká prípona a obnovenie

- **Invertovať výber** (Num*, ponuka Označiť) prehodí každé označenie: označené položky sa stanú neoznačenými a naopak — praktické pre „všetko okrem týchto“.
- **Vybrať všetko s rovnakou príponou** (Alt+Num+, ponuka Označiť) označí každý súbor, ktorý zdieľa príponu položky pod kurzorom, takže jedným stlačením klávesu získate napríklad všetky súbory `.pdf`.
- **Obnoviť výber** (Num/, ponuka Označiť) vráti vašu predchádzajúcu množinu označení — užitočné, ak ju príkaz vymazal alebo ste označili nesprávnu skupinu.

## Klávesové skratky

| Akcia | Kláves |
|---|---|
| Prepnúť označenie, posunúť nadol | Insert |
| Prepnúť označenie (aktuálna položka) | Space |
| Vybrať všetko / Zrušiť výber všetkého | Ctrl+Num+ / Ctrl+Num- |
| Vybrať všetko (alternatíva) | Cmd+A |
| Vybrať skupinu podľa masky | Num+ |
| Zrušiť výber skupiny podľa masky | Num- |
| Invertovať výber | Num* |
| Vybrať všetko s rovnakou príponou | Alt+Num+ |
| Obnoviť predchádzajúci výber | Num/ |

## Poznámky

- Označenia a kurzor sú nezávislé: presúvanie kurzora klávesmi so šípkami nemení, čo je označené.
- Položku nadradeného priečinka (`..`) nie je možné nikdy označiť.
- Vybrať skupinu, Zrušiť výber skupiny a Invertovať výber sa zhodujú podľa názvu súboru, takže priečinky môžete zahrnúť alebo vynechať v závislosti od možností dialógu.
- Po dokončení kopírovania, presunu alebo odstránenia sa položky, ktoré boli úspešne spracované, automaticky odznačia, zatiaľ čo tie, ktoré zlyhali, zostanú označené, aby ste ich mohli zopakovať.
