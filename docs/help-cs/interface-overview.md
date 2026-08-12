---
title: Hlavní okno
slug: interface-overview
section: Začínáme
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander zobrazuje dva seznamy souborů vedle sebe, takže vidíte současně, odkud soubory přicházejí a kam míří. Většina vaší práce probíhá v těchto dvou panelech; lišty kolem nich umožňují přepínat disky, přeskočit do složky a spouštět běžné souborové příkazy bez opuštění klávesnice. Tento přehled pojmenovává každou část okna, aby zbytek nápovědy dával smysl.

![Hlavní okno Peach Commanderu s jeho dvěma panely a okolními lištami](screenshots/main-window.png)
*(Obrázek: hlavní okno — dva panely s lištou tlačítek, lištou disků a lištami cesty nahoře a lištou funkčních kláves dole.)*

## Dva panely a aktivní panel

Okno je rozděleno na levý a pravý panel, každý zobrazuje obsah jedné složky. Vždy je aktivní jen jeden panel: zobrazuje kurzor (zvýrazněný řádek) a jeho lišta cesty je vykreslena s barevným pozadím. Příkazy jako kopírovat a přesunout vždy působí na aktivní panel a odesílají soubory do druhého.

1. Klepnutím kamkoli do panelu jej učiníte aktivním, nebo přepínejte mezi nimi klávesou Tab.
2. Šipkami posouvejte kurzor nahoru a dolů v aktivním panelu.
3. Stiskem Enter na složce ji otevřete, nebo na `..` v horní části seznamu přejdete o úroveň výš.

## Lišty kolem panelů

- **Lišta tlačítek** (nahoře): řada plochých tlačítek pro časté příkazy. Klepnutím na tlačítko spustíte jeho příkaz; klepnutím pravým tlačítkem lištu upravíte.
- **Lišta jednotek**: jedno tlačítko na každý dostupný disk nebo svazek, u každého volné místo. Klepnutím na svazek do něj přepnete tento panel; klepnutím pravým tlačítkem jej vysunete — nabízí se u vyměnitelných svazků a připojených obrazů disků, zašedlé u spouštěcího disku a síťových sdílení. Zásuvné moduly mohou přidat vlastní jednotky — Task Manager je jednou z nich — a chovají se jako každý jiný svazek: panel se do ní přepne, tlačítko zůstane vybrané a karta nese název jednotky.
- **Lišta cesty**: zobrazuje aktuální složku jako klikatelnou drobečkovou navigaci. Klepnutím na segment přeskočíte přímo do té složky, nebo klepnutím na cestu zadáte umístění.
- **Stavová lišta** (pod každým seznamem): průběžný souhrn panelu — kolik souborů a složek je vybráno a jejich celková velikost.
- **Příkazový řádek** (dole): textové pole, do kterého lze zadat příkaz ve stylu shellu, jenž se spustí v aktuální složce.
- **Lišta funkčních kláves** (úplně dole): šest tlačítek označených F3 Zobrazit, F4 Upravit, F5 Kopírovat, F6 Přesunout, F7 NováSložka a F8 Smazat. Klepněte na tlačítko nebo stiskněte odpovídající klávesu.

![Detail lišty disků zobrazující tlačítka svazků a volné místo](screenshots/drive-bar-crop.png)
*(Obrázek: lišta jednotek — jedno tlačítko na svazek, se zbývajícím volným místem; klepnutím pravým tlačítkem na svazek jej vysunete.)*

## Zkratky

| Akce | Zkratka |
|---|---|
| Přepnout aktivní panel | Tab |
| Otevřít složku / položku pod kurzorem | Enter |
| Přejít o složku výš | Backspace |
| Zobrazit soubor | F3 |
| Upravit soubor | F4 |
| Kopírovat do druhého panelu | F5 |
| Přesunout / přejmenovat do druhého panelu | F6 |
| Nová složka | F7 |
| Smazat (do Koše) | F8 |

## Poznámky

- Lišta funkčních kláves se za běhu přeznačí, když podržíte modifikátor. Podržením Shift se například F6 změní na akci přejmenování na místě, takže tlačítka vždy ukazují, co klávesy právě udělají.
- Téměř každou lištu lze zobrazit nebo skrýt. V nabídkách Zobrazení a Konfigurace zapnete a vypnete lištu tlačítek, lištu disků, příkazový řádek nebo lištu funkčních kláves, případně naskládáte oba panely nad sebe místo vedle sebe.
- Na mnoha klávesnicích Mac fungují klávesy F ve výchozím nastavení jako ovládání médií a jasu. Podržte klávesu Fn spolu s F3–F8, nebo zapněte „Používat klávesy F1, F2 atd. jako standardní funkční klávesy“ v Nastavení systému, abyste je používali přímo.
