---
title: Markdown și HTML în vizualizator
slug: markdown-viewer
section: Pluginuri
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Apăsați F3 pe un fișier `.md` sau `.html` și el apare formatat, nu ca sursă: titluri, liste, tabele, legături, liste de sarcini și blocuri de cod colorate după limbaj. Diagramele scrise ca blocuri ` ```mermaid ` sunt desenate, iar matematica scrisă între semne de dolar este culeasă.

Acesta este un plugin. Tot ce se află pe această pagină vine de la **Markdown and HTML**, pe care îl puteți dezactiva în **Configurare ▸ Plugin-uri…** — mai jos se explică ce se schimbă atunci.

## Unde apare vizualizarea formatată

- **Vizualizatorul (F3).** Pagina formatată. Meniul **Vizualizare** oferă în continuare Text, Cod și Hex, deci sursa este la un clic, iar numele plugin-ului se află și el în acea listă.
- **Quick View (Ctrl+Q) și pagina de informații** din panoul lateral arată aceeași redare, astfel încât o previzualizare și o vizualizare completă a aceluiași fișier nu se contrazic niciodată.
- **Galeria** arată o imagine mică a începutului unui fișier Markdown în loc de o pictogramă generică de document.
- **Quick Look (Cmd+Y)** este previzualizarea proprie a macOS și *nu* este afectată — acel panou aparține sistemului și niciun plugin nu poate desena în el.

## Schema simbolurilor

Apăsați **Simboluri** în vizualizator pentru a obține titlurile documentului, imbricate așa cum sunt scrise, și faceți clic pe unul pentru a sări la el în pagină. Funcționează în vizualizarea formatată și în sursă, iar cele două sunt de acord unde se află un titlu.

## Diagrame și matematică

Un bloc de cod cu limbajul `mermaid` devine o diagramă; `$…$` și `$$…$$` devin matematică culeasă. Ambele sunt desenate **pe Mac-ul dumneavoastră**, de motoare livrate în plugin — nimic nu se descarcă și nicio parte a documentului nu este trimisă nicăieri. Un semn de dolar într-un bloc de cod sau în cod inline rămâne un semn de dolar.

Un document fără diagramă și fără formulă nu încarcă niciunul dintre motoare, deci un README obișnuit nu costă nimic în plus. O diagramă care nu poate fi citită arată eroarea acolo unde era blocul, cu textul blocului dedesubt, în loc să dispară.

Ambele pot fi dezactivate separat în **Configurare ▸ Setări ▸ Markdown**, unde se vede și ce versiune este în uz și de unde provine.

## Versiunea dumneavoastră

Dacă aveți nevoie de o versiune mai nouă sau diferită de Mermaid ori KaTeX, puneți-o în folderul deschis de butonul **Engine Folder…** și va fi folosită în locul celei livrate. Numele fișierelor sunt `mermaid.min.js`, `katex.min.js`, `katex.min.css` și `auto-render.min.js`. Nimic nu este niciodată adus din internet pentru dumneavoastră.

## Ce nu va face pagina formatată

Pagina formatată este izolată în mod deliberat, pentru că un fișier Markdown este conținut venit din altă parte:

- **Nu încarcă nimic prin rețea.** O imagine a cărei adresă începe cu `http` rămâne goală intenționat: aducerea ei ar spune acelui server când ați deschis fișierul și de la ce adresă. O imagine aflată lângă document pe disc se încarcă normal.
- **Scripturile și HTML-ul documentului nu rulează niciodată.** HTML-ul scris într-un fișier Markdown este arătat ca text, iar un fișier `.html` este afișat cu scripturile dezactivate.

## Dezactivarea

Dezactivați plugin-ul în **Configurare ▸ Plugin-uri…** și fișierele `.md` și `.html` se vor deschide ca text. Schema funcționează în continuare, colorarea sintaxei funcționează în continuare și nimic altceva nu se schimbă — vizualizarea formatată pur și simplu nu mai este oferită. Același lucru este valabil dacă dezactivați doar vizualizarea formatată în pagina de setări a plugin-ului.

## Limite

- Fișierele peste o limită de dimensiune (8 MB implicit, în pagina de setări) se deschid ca text. Transformarea unui document generat foarte mare într-o pagină formatată este lentă, iar vizualizatorul de text îl deschide imediat.
- Pagina formatată nu poate fi editată. Folosiți F4 pentru asta, sau vizualizarea Text pentru **Formatare**, **Codificare** și **Salt la**, care se aplică sursei și nu unei pagini redate.
