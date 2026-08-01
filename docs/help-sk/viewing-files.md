---
title: Zobrazenie súborov
slug: viewing-files
section: Zobrazenie a úpravy
order: 70
related: [editing-files, searching]
---

Peach Commander má vstavaný prehliadač, ktorý vám umožňuje nazrieť do súboru bez otvárania inej aplikácie alebo zmeny súboru. Stlačte F3 na položke pod kurzorom a prehliadač sa okamžite otvorí, aj pri veľmi veľkých súboroch. Automaticky vyberie najlepší spôsob zobrazenia obsahu: čitateľný text, kód s farebnou syntaxou, surový šestnástkový výpis alebo obrázok v plnej veľkosti. Náhľad súboru môžete zobraziť aj priamo v okne pomocou Rýchleho zobrazenia, alebo ho odovzdať funkcii Quick Look v macOS.

## Zobrazenie súboru

1. Presuňte kurzor na súbor v aktívnom paneli.
2. Stlačte F3 (alebo vyberte Zobraziť v ponuke Súbor). Prehliadač sa otvorí vo vlastnom okne.
3. Použite panel nástrojov na prepínanie, ako sa obsah zobrazuje: Text, Kód, Hex, Obrázok alebo Vykreslené. Nechajte automatické nastavenie, nech rozhodne Peach Commander.
4. Posúvajte šípkami, Page Up/Page Down a posuvníkom. Pri dlhom texte zapnite tlačidlo minimapy na zobrazenie celého súboru a rýchly pohyb v ňom.
5. Stlačte N na skok na ďalší vybraný súbor, alebo zatvorte okno klávesom Esc.

![Vstavaný prehliadač zobrazujúci textový súbor s minimapou vpravo](screenshots/lister-text.png)
*(Obrázok: zobrazenie textového súboru, s voličom reprezentácie a minimapou na paneli nástrojov.)*

## Hľadanie textu a zmena kódovania

- Stlačte Ctrl+F na hľadanie vnútri súboru. Stlačte F3 na skok na ďalšiu zhodu a Shift+F3 na predchádzajúcu.
- Ak text vyzerá skreslene, kliknite na Kódovanie na paneli nástrojov (alebo stlačte E) na prechádzanie kódovaní textu, kým sa nečíta správne; automatické nastavenie to zvyčajne trafí.
- Stlačte W na prepnutie zalamovania slov pri dlhých riadkoch.

## Rýchle zobrazenie a Quick Look

Rýchle zobrazenie ukazuje živý náhľad v paneli, ktorý *nepoužívate*, takže môžete pokračovať v prehliadaní na jednej strane a náhľade na druhej.

1. Stlačte Ctrl+Q. Neaktívny panel sa zmení na oblasť náhľadu.
2. Presúvajte kurzor na rôzne súbory v aktívnom paneli na náhľad každého.
3. Stlačte Ctrl+Q znova, alebo Esc, na vrátenie panela na normálny zoznam súborov.

Na rýchly celoobrazovkový náhľad spracovaný priamo macOS stlačte Cmd+Y (Quick Look). Stlačte Cmd+Y alebo medzerník znova na jeho zatvorenie.

## Stránka s informáciami v bočnom paneli

Bočný panel (**Zobraziť > Panel náhľadu** alebo Cmd+Shift+P) má stránku **Informácie**, ktorá ukazuje položku pod kurzorom tak, ako to robí informačný bočný panel Findera.

- Náhľad vyplní celú šírku panela — keď panel rozšírite, náhľad rastie s ním. Potiahnutím ľavého okraja panela ho rozšírite alebo zúžite; šírka sa pamätá.
- Ide o skutočný náhľad macOS, nie o malý náhľadový obrázok: funguje každý formát, ktorý vie zobraziť Rýchly náhľad, a viacstranovým dokumentom listujete priamo v náhľade stranu po strane.
- Pod ním je názov, druh a veľkosť, ďalej kedy bola položka vytvorená a zmenená a v ktorom priečinku leží.

Pri pohybe kurzora sa názov a údaje aktualizujú okamžite; náhľad nasleduje o okamih neskôr, aby podržaná šípka prechádzajúca dlhým priečinkom nespúšťala náhľad pre každý míňaný riadok.

## Dekompilácia súborov .class jazyka Java

So zapnutým zásuvným modulom **Java Decompiler** ukáže F3 na súbore `.class` čitateľný kód namiesto binárnych údajov — aj pri triedach vnútri archívu JAR alebo ZIP, do ktorého možno vstúpiť a čítať ho bez rozbaľovania.

Modul sám žiadny dekompilátor neobsahuje. Riadi engine, ktorý si nainštalujete, a engine možno kedykoľvek vymeniť:

- **CFR** (licencia MIT) a **Vineflower** (Apache 2.0) vytvárajú zdrojový kód Javy. Vložte `cfr.jar` alebo `vineflower.jar` do priečinka enginov.
- **Procyon** (Apache 2.0) je tretí dekompilátor do zdrojového kódu.
- **javap** nevyžaduje žiadne sťahovanie — patrí ku každému JDK a ukazuje bajtkód namiesto zdrojového kódu Javy.

Nič sa za vás nesťahuje: ide o programy tretích strán s vlastnými licenciami a Peach Commander ich nesťahuje ani neaktualizuje. Tlačidlo **Priečinok enginov…** v prehliadači otvorí priečinok, kam patria, a zanechá v ňom poznámku s názvom každého enginu a odkiaľ ho získať. Všetky okrem javap vyžadujú nainštalovanú Javu.

Engine prepnete ponukou v hornej časti prehliadača; zvolený sa použije ihneď a výsledok sa uchová, takže porovnanie dvoch enginov nad tým istým súborom je okamžité.

Modul je **vypnutý, kým ho nezapnete**, v Nastavenia ▸ Zásuvné moduly — väčšina ľudí súbor .class nikdy neotvorí a bez enginu aj tak nič nezmôže.

Vlastný engine pridáte vytvorením `decompilers.ini` v priečinku enginov:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args   = -jar {engine} {input}
engine = ~/tools/my-decompiler.jar
output = stdout
```

`{input}`, `{engine}` a `{outdir}` sa dosadia pri spustení. Vaše záznamy majú prednosť pred vstavanými a použitie vstavaného názvu (`cfr`, `vineflower`, `procyon`, `javap`) ho nahradí namiesto pridania druhého záznamu.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Zobraziť súbor pod kurzorom | F3 |
| Zobraziť len súbor pod kurzorom (ignorovať označené súbory) | Shift+F3 |
| Otvoriť v externom prehliadači | Option+F3 |
| Hľadať v prehliadači | Ctrl+F |
| Ďalšia / predchádzajúca zhoda | F3 / Shift+F3 |
| Rýchle zobrazenie v druhom paneli | Ctrl+Q |
| Quick Look (náhľad macOS) | Cmd+Y |
| Zatvoriť prehliadač alebo Rýchle zobrazenie | Esc |

## Poznámky

- Prehliadač je len na čítanie. Na zmenu súboru použite namiesto toho editor (pozri Úprava súborov).
- Veľmi veľké súbory sa otvárajú bez oneskorenia: text otvorí rýchle posúvateľné zobrazenie a šestnástkové zobrazenie sa číta priamo z disku pri akejkoľvek veľkosti.
- Stlačte F3 na priečinku na zobrazenie súhrnu jeho obsahu a celkovej veľkosti namiesto bajtov súboru.
- Režim Vykreslené zobrazuje formátovaný obsah ako webové stránky; šestnástkový režim ukazuje surové bajty vedľa ich znakov, čo je praktické na skúmanie binárnych súborov.
- V režime Vykreslené možno označovať a kopírovať text a Nájsť prehľadáva vykreslenú stránku. Tlačidlá, ktoré na vykreslenú stránku nemožno použiť — Formátovať, Kódovanie, Vybrať všetko, Výbery a Prejsť na — sú zosivené, namiesto aby zostali bez účinku.
- Tlačidlo Formátovať nanovo odsadí štruktúrované súbory (JSON, XML, HTML, INI, YAML a ďalšie, ak máte príslušný nástroj príkazového riadka). Je celé opísané v [Úpravy súborov](editing-files.md#formatting-a-file) a funguje tu rovnako.
