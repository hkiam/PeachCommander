---
title: Editarea fișierelor
slug: editing-files
section: Vizualizare și editare
order: 72
related: [viewing-files]
---

Când trebuie să modificați un fișier, nu doar să-l priviți, Peach Commander îl deschide într-un editor încorporat. Fișierele text și de cod se deschid într-un editor complet cu evidențierea sintaxei, căutare și înlocuire, un contur al simbolurilor din codul dvs. și o hartă miniaturală pentru navigare rapidă. Fișierele binare pot fi deschise într-un editor hexazecimal separat, unde puteți inspecta și modifica octeți individuali. Nu trebuie niciodată să părăsiți aplicația pentru o editare rapidă.

## Editați un fișier text sau de cod

1. În oricare panou, mutați cursorul pe fișierul pe care doriți să-l modificați.
2. Apăsați F4, sau alegeți Fișier ▸ Editează. Fișierul se deschide în fereastra editorului.
3. Faceți modificările. Dacă fișierul este un format de programare sau de date recunoscut, cuvintele cheie, șirurile și comentariile sunt colorate automat.
4. Apăsați Cmd+S (sau faceți clic pe Salvează) pentru a scrie modificările. Prima salvare păstrează o copie de rezervă a originalului lângă fișier, astfel încât puteți reveni întotdeauna la ea.

Pentru a începe un fișier text nou-nouț la locația curentă, apăsați Shift+F4.

![Editorul de text încorporat care arată evidențierea sintaxei, conturul simbolurilor și harta miniaturală](screenshots/editor.png)
*(Figura: editorul cu evidențierea sintaxei, conturul simbolurilor în stânga și harta miniaturală în dreapta.)*

## Căutare, înlocuire și navigare

- Apăsați Cmd+F pentru a deschide bara de căutare. Pentru a înlocui text, deschideți bara de căutare și comutați-o la vizualizarea de înlocuire, sau faceți clic pe Găsește/Înlocuiește în bara de instrumente.
- Faceți clic pe Formatează JSON/XML pentru a re-indenta un document JSON sau XML într-o dispunere curată, lizibilă.
- Faceți clic pe Simboluri (sau apăsați Cmd+Shift+O) pentru a afișa o bară laterală care listează clasele, funcțiile și metodele din codul dvs. Faceți clic pe o intrare pentru a sări direct la ea.
- Apăsați Cmd+L pentru a sări la o linie anume.
- Apăsați Cmd+\ pentru a sări între o paranteză și perechea ei.
- Faceți clic pe butonul hartă pentru a afișa sau ascunde harta miniaturală, o prezentare generală la scară a întregului fișier pe care puteți face clic pentru a derula.
- Folosiți meniul Codificare din bara de instrumente dacă fișierul a fost salvat în altă codificare de text decât cea implicită.

## Formatarea unui fișier

Apăsați **Formatează** în editor (aceeași comandă există în vizualizator) pentru a reindenta fișierul. Peach Commander alege un formator după extensie și arată în bara de stare pe care l-a folosit, de exemplu *formatted (jq)* — așa știți mereu ce a modelat rezultatul.

**Fără să instalați nimic**: JSON, XML, SVG, pliste, HTML, configurație în stil INI și YAML. YAML este un caz aparte: este curățat, nu reindentat, fiindcă în YAML indentarea *este* structura, iar rescrierea ei fără un analizor YAML adevărat ar putea schimba sensul fișierului. Spațiile de la capăt de rând dispar, tabulatorii rătăciți din indentare devin spații, șirurile de rânduri goale se scurtează — iar tot ce se află într-un scalar de bloc (`|` sau `>`) rămâne exact așa, pentru că acolo spațiul este conținut.

**Formatoarele mai bune preiau automat.** Dacă aveți unul dintre ele instalat, Peach Commander îl folosește, pentru că o unealtă dedicată corespunde de obicei așteptărilor ecosistemului — iar la formatele de configurație vă păstrează comentariile:

| Instalați | și obțineți |
| --- | --- |
| `yq` sau `prettier` | formatare YAML completă, comentariile păstrate |
| `taplo` | TOML |
| `sqlformat` sau `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, în stilul obișnuit |
| `xmllint` | XML și SVG |

Dacă un tip de fișier nu are formator, butonul este estompat și intrarea de menu dezactivată. Dacă încercați oricum, aflați de ce — *„taplo nu este instalat”* se citește altfel decât *„JSON invalid”*.

### Folosirea propriului formator

Pentru a formata un tip pe care Peach Commander nu îl cunoaște, sau pentru a folosi altă unealtă, creați `formatters.ini` în dosarul de configurație — o secțiune pentru fiecare extensie:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` este un nume de program (căutat cum ar face shell-ul) sau o cale absolută; `args` sunt transmise ca atare. Textul fișierului intră pe intrarea standard, iar textul formatat este citit de la ieșirea standard, așa că funcționează orice formator de linie de comandă bine crescut. Intrările dumneavoastră câștigă în fața tuturor celorlalte. La prima pornire se creează un șablon comentat — deschideți fișierul și completați-l.

Și pluginurile pot contribui cu formatoare — vedeți [Plugins](plugins.md).

## Editați un fișier octet cu octet

1. Selectați fișierul într-un panou.
2. Alegeți Fișier ▸ Editează ca hexazecimal (sau faceți clic dreapta pe fișier și alegeți Editează ca hexazecimal).
3. Tastați cifre hexazecimale pentru a suprascrie octeți, sau folosiți tastele săgeți pentru a vă deplasa prin fișier. Backspace și Delete elimină octeți.
4. Apăsați Cmd+S pentru a salva. Ca la editorul de text, o copie de rezervă unică a originalului este păstrată.

## Comenzi rapide

| Acțiune | Tastă |
|---|---|
| Editează fișier | F4 |
| Creează și editează un fișier text nou | Shift+F4 |
| Salvează | Cmd+S |
| Găsește | Cmd+F |
| Afișează/ascunde conturul simbolurilor | Cmd+Shift+O |
| Salt la linie | Cmd+L |
| Salt la paranteza pereche | Cmd+\ |
| Anulează / Refă (editor hexazecimal) | Cmd+Z / Cmd+Shift+Z |

## Note

- Evidențierea sintaxei acoperă JSON, C, C#, Java, JavaScript, TypeScript, Python și Rust. Alte tipuri de fișiere se deschid și se editează în continuare normal cu colorare de bază, dar evidențierea detaliată și conturul simbolurilor sunt disponibile doar pentru limbajele acceptate.
- Conturul simbolurilor și Salt la linie se aplică editorului de text. Editorul hexazecimal este destinat inspecției binare și editărilor la nivel de octet, nu textului.
- Ambii editori păstrează o copie de rezervă a fișierului original la prima salvare, astfel încât o modificare accidentală este ușor de anulat restaurând acea copie de rezervă.
