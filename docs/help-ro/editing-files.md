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
