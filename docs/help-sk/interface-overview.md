---
title: Hlavné okno
slug: interface-overview
section: Začíname
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander zobrazuje dva zoznamy súborov vedľa seba, takže naraz vidíte, odkiaľ súbory prichádzajú a kam smerujú. Väčšina vašej práce prebieha v týchto dvoch paneloch; lišty okolo nich vám umožňujú prepínať jednotky, prejsť do priečinka a spúšťať bežné príkazy so súbormi bez toho, aby ste opustili klávesnicu. Táto prehliadka pomenúva jednotlivé časti okna, aby dával zmysel zvyšok pomocníka.

![Hlavné okno Peach Commander s dvoma panelmi a okolitými lištami](screenshots/main-window.png)
*(Obrázok: Hlavné okno — dva panely s lištou tlačidiel, lištou jednotiek a lištami cesty nad nimi a lištou funkčných klávesov pod nimi.)*

## Dva panely a aktívny panel

Okno je rozdelené na ľavý a pravý panel, každý zobrazuje obsah jedného priečinka. Aktívny je vždy len jeden panel: zobrazuje kurzor (zvýraznený riadok) a jeho lišta cesty je vykreslená s farebným pozadím. Príkazy ako kopírovanie a presun vždy pracujú s aktívnym panelom a odosielajú súbory do toho druhého.

1. Kliknutím kdekoľvek do panela ho urobíte aktívnym alebo medzi nimi prepínajte klávesom Tab.
2. Kurzor presúvajte hore a dole po aktívnom paneli pomocou klávesov so šípkami.
3. Stlačením klávesu Enter na priečinku ho otvoríte, alebo na položke `..` v hornej časti zoznamu prejdete o úroveň vyššie.

## Lišty okolo panelov

- **Lišta tlačidiel** (hore): rad plochých tlačidiel na časté príkazy. Kliknutím na tlačidlo spustíte jeho príkaz; kliknutím pravým tlačidlom lištu upravíte.
- **Lišta jednotiek**: jedno tlačidlo na každý dostupný disk alebo zväzok, pri každom voľné miesto. Kliknutím na zväzok doň prepnete tento panel; kliknutím pravým tlačidlom ho vysuniete — ponúka sa pri vymeniteľných zväzkoch a pripojených obrazoch diskov, zošedivené pri spúšťacom disku a sieťových zdieľaniach.
- **Lišta cesty**: zobrazuje aktuálny priečinok ako klikateľnú navigačnú cestu. Kliknutím na segment prejdete priamo do daného priečinka alebo kliknutím na cestu môžete umiestnenie zadať.
- **Stavová lišta** (pod každým zoznamom): priebežný súhrn panela — koľko súborov a priečinkov je vybraných a ich celková veľkosť.
- **Príkazový riadok** (dole): textové pole, do ktorého môžete napísať príkaz v štýle shellu, ktorý sa spustí v aktuálnom priečinku.
- **Lišta funkčných klávesov** (úplne dole): šesť tlačidiel s označením F3 Zobraziť, F4 Upraviť, F5 Kopírovať, F6 Presunúť, F7 Nový priečinok a F8 Odstrániť. Kliknite na tlačidlo alebo stlačte príslušný kláves.

![Detail lišty jednotiek zobrazujúci tlačidlá zväzkov a voľné miesto](screenshots/drive-bar-crop.png)
*(Obrázok: lišta jednotiek — jedno tlačidlo na zväzok, so zvyšným voľným miestom; kliknutím pravým tlačidlom na zväzok ho vysuniete.)*

## Klávesové skratky

| Akcia | Skratka |
|---|---|
| Prepnúť aktívny panel | Tab |
| Otvoriť priečinok / položku pod kurzorom | Enter |
| Prejsť o priečinok vyššie | Backspace |
| Zobraziť súbor | F3 |
| Upraviť súbor | F4 |
| Kopírovať do druhého panela | F5 |
| Presunúť / premenovať do druhého panela | F6 |
| Nový priečinok | F7 |
| Odstrániť (do Koša) | F8 |

## Poznámky

- Lišta funkčných klávesov sa počas držania modifikačného klávesu naživo premenúva. Napríklad podržanie klávesu Shift zmení F6 na akciu premenovania na mieste, takže tlačidlá vždy zobrazujú, čo klávesy práve teraz urobia.
- Takmer každú lištu možno zobraziť alebo skryť. V ponukách Zobraziť a Nastavenia nájdete možnosti na zapnutie a vypnutie lišty tlačidiel, lišty jednotiek, príkazového riadka alebo lišty funkčných klávesov, prípadne na usporiadanie oboch panelov nad seba namiesto vedľa seba.
- Na mnohých klávesniciach Macu fungujú klávesy F predvolene ako ovládanie médií a jasu. Podržte kláves Fn spolu s F3–F8 alebo v Nastaveniach systému zapnite „Používať klávesy F1, F2 atď. ako štandardné funkčné klávesy“, aby ste ich mohli používať priamo.
