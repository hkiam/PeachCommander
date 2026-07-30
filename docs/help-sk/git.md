---
title: Git
slug: git
section: Zásuvné moduly
order: 123
related: [plugins, view-modes-and-sorting]
---

Zásuvný modul Git prináša stav úložiska Git priamo do panela súborov — žiadna samostatná aplikácia, žiadny terminál. Pridáva dva stĺpce, ktoré zobrazujú stav pracovného stromu každého súboru a aktuálnu vetvu, podponuku **Git** pre každodenné príkazy (stav, pripraviť, commit, pull, push), a používa `git`, ktorý je už nainštalovaný na vašom Macu. Keďže ide o zásuvný modul, môžete ho vypnúť alebo odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Čo pridáva

- **Dva stĺpce v zozname súborov** — *Git Status* a *Branch*. V úložisku každý súbor zobrazuje krátke stavové slovo (Upravené, Pridané, Odstránené, Nesledované, Premenované, Skopírované, Konflikt, Ignorované alebo Zmenené) a panel zobrazuje aktuálnu vetvu. Stĺpce zapnite v **Konfigurácia ▸ Stĺpce…** (pozri [Režimy zobrazenia a triedenie](view-modes-and-sorting.md)).
- **Ponuka Git** — pod **Príkazy ▸ Git** a v kontextovej ponuke súboru, s: **Git Status…**, **Git Add (pripraviť)**, **Git Commit…**, **Git Pull** a **Git Push**.

![Dialóg Git Status zobrazujúci aktuálnu vetvu a zmenené súbory v úložisku](screenshots/git-status.png)
*(Obrázok: Git Status hlási vetvu a každú zmenu v pracovnom strome.)*

## Kontrola stavu

1. Umiestnite kurzor na súbor alebo priečinok vnútri úložiska Git.
2. Vyberte **Príkazy ▸ Git ▸ Git Status…** (alebo pravý klik ▸ **Git ▸ Git Status…**).
3. Objaví sa súhrn: aktuálna vetva (alebo *(odpojené)*), potom buď *Pracovný strom je čistý.*, alebo zoznam zmien, kde každý riadok zobrazuje stav a cestu súboru.

Ak kurzor nie je vnútri úložiska, zásuvný modul jednoducho oznámi *Nie je úložisko Git.*

## Pripraviť, commit, pull, push

- **Git Add (pripraviť)** pripraví súbor pod kurzorom (`git add`).
- **Git Commit…** požiada o správu commitu, potom odovzdá všetky zmeny (`git commit -a`). Zobrazí sa kombinovaný výstup, takže presne vidíte, čo sa stalo.
- **Git Pull** vykoná pull iba typu fast-forward (`git pull --ff-only`).
- **Git Push** odošle aktuálnu vetvu (`git push`).

Po príkaze, ktorý mení úložisko, sa aktívny panel obnoví, takže stavové stĺpce zostanú aktuálne.

## Poznámky

- Zásuvný modul používa systémový Git na `/usr/bin/git`. Ak Git nie je nainštalovaný, príkazy oznámia, že Git nie je k dispozícii. (Inštalácia Xcode Command Line Tools ho poskytne.)
- Stav úložiska sa načíta raz na priečinok a uloží do vyrovnávacej pamäte, takže posúvanie veľkého úložiska zostáva rýchle; vyrovnávacia pamäť sa obnoví po každom príkaze, ktorý zmení strom.
- Commit používa `git commit -a`, ktorý odovzdá sledované zmeny; úplne nové súbory stále najprv potrebujú **Git Add (pripraviť)**.
- Hlavičky stĺpcov *Git Status* a *Branch* sa momentálne zobrazujú v angličtine aj v iných jazykoch rozhrania; hodnoty a dialógy sú lokalizované.
