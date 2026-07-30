---
title: Atribute și permisiuni
slug: attributes-and-permissions
section: Instrumente avansate
order: 96
related: [file-utilities]
---

Peach Commander vă permite să inspectați și să modificați metadatele de nivel scăzut ale fișierelor și folderelor pe care Finder le ține în cea mai mare parte în afara accesului: permisiunile POSIX de citire/scriere/execuție, proprietarul și grupul, datele de modificare și creare, indicatoarele macOS precum ascuns și blocat, și atributele extinse. Puteți de asemenea edita lista de control al accesului (ACL) a unui fișier pentru reguli detaliate per utilizator sau per grup, crea legături și alias-uri care indică spre alte elemente și atașa propriile comentarii. Aceste instrumente sunt destinate utilizatorilor avansați care au nevoie de control precis asupra modului în care se comportă elementele și cine le poate atinge.

## Modificarea atributelor

1. Selectați unul sau mai multe elemente în panoul activ.
2. Alegeți **Fișier > Modifică atribute…**.
3. Setați ce aveți nevoie: comutați casetele de citire/scriere/execuție pentru proprietar, grup și toți (sau tastați direct o valoare octală), schimbați proprietarul sau grupul, comutați indicatoarele ascuns sau blocat și setați data de modificare sau creare. Folosiți **Folosește curentul** pentru ora curentă, sau copiați o dată dintr-un alt fișier.
4. Pentru a aplica aceeași modificare prin conținutul unui folder, activați opțiunea recursivă și alegeți dacă afectează fișierele, folderele sau ambele.
5. Faceți clic pe OK pentru a executa modificarea. Modificările recursive rulează ca o sarcină de fundal cu o bară de progres.

![Dialogul Modifică atribute care arată grila de permisiuni, indicatoarele și câmpurile de dată](screenshots/attributes-dialog.png)
*(Figura: dialogul Modifică atribute. Valorile mixte dintr-o selecție de mai multe fișiere apar ca o liniuță până le setați.)*

## Editarea unui ACL

Pentru reguli dincolo de modelul de bază proprietar/grup/toți, editați lista de control al accesului a elementului.

1. Deschideți **Fișier > Modifică atribute…** și deschideți editorul ACL de acolo.
2. Fiecare rând este o regulă: utilizatorul sau grupul căruia i se aplică, dacă permite sau refuză și ce permisiuni (citire, scriere, ștergere etc.) acordă.
3. Adăugați, eliminați sau editați rânduri, apoi salvați pentru a scrie lista înapoi în element.

## Crearea de legături, alias-uri și comentarii

- **Fișier > Creează legătură simbolică…** creează o legătură simbolică (symlink) care indică spre elementul de sub cursor prin cale.
- **Fișier > Creează legătură hard…** creează o legătură hard către aceleași date de fișier. Legăturile hard funcționează doar pentru fișiere de pe același volum.
- **Fișier > Creează alias…** creează un alias macOS pe care Finder îl poate de asemenea urma.
- **Fișier > Editează comentariul…** (Ctrl+Z) deschide un editor de text pentru un comentariu per fișier. Comentariile pot fi afișate în propria coloană și în sfaturile de stare.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Editează comentariul | Ctrl+Z |

## Note

- Schimbarea proprietarului sau a grupului necesită de obicei privilegii pe care nu le aveți ca utilizator obișnuit; când se întâmplă asta, modificarea este raportată ca eșuată în loc de aplicată, iar restul modificărilor dvs. trec în continuare.
- Comentariile sunt stocate într-un fișier `descript.ion` alături de elementele dvs. și pot fi de asemenea păstrate ca comentarii Finder, în funcție de setările dvs. Ambele sunt citite la afișarea unui comentariu.
- O legătură simbolică și un alias indică ambele spre o țintă, dar o legătură simbolică stochează o cale simplă, în timp ce un alias stochează o referință macOS care continuă să funcționeze dacă ținta este mutată sau redenumită. O legătură hard este un al doilea nume pentru aceleași date de fișier, nu un indicator.
