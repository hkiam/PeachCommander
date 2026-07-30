---
title: Selectarea fișierelor
slug: selecting-files
section: Fișiere și foldere
order: 22
related: [copying-files, searching]
---

Înainte de a copia, muta, șterge sau împacheta ceva, îi spuneți mai întâi lui Peach Commander asupra căror elemente să acționeze. Elementul pe care se află cursorul este întotdeauna elementul curent, dar puteți și *marca* unul sau mai multe fișiere și foldere, astfel încât o comandă să ruleze asupra tuturor deodată. Elementele marcate se evidențiază printr-o culoare distinctă a numelui în panou.

## Marcarea fișierelor și folderelor

1. Faceți clic pe un rând pentru a muta cursorul pe el. Un singur clic selectează doar acel element.
2. Pentru a marca mai multe elemente deodată, țineți apăsat Cmd și faceți clic pe fiecare sau țineți apăsat Shift și faceți clic pentru a marca un interval.
3. Pentru a marca elementul de sub cursor și a coborî într-o singură mișcare, apăsați Insert. Apăsați-l în mod repetat pentru a marca rapid o serie de elemente consecutive. Bara de spațiu comută de asemenea marcajul elementului curent (și afișează dimensiunea unui folder).
4. Pentru a marca totul din panou, alegeți Marcare > Selectează tot (Ctrl+Num+) sau apăsați Cmd+A. Alegeți Marcare > Deselectează tot (Ctrl+Num-) pentru a șterge toate marcajele.

## Selectarea sau deselectarea după un tipar

1. Alegeți Marcare > Selectează grup… (Num+) pentru a adăuga elemente ale căror nume se potrivesc cu un tipar sau Marcare > Deselectează grup… (Num-) pentru a elimina elementele care se potrivesc din marcajele curente.
2. Tastați o mască cu metacaractere. Folosiți `*` pentru orice caractere și `?` pentru un singur caracter. Separați mai multe măști cu punct și virgulă și listați excepțiile după o bară verticală — de exemplu `*.jpg;*.png` marchează toate imaginile, iar `*.*|*.bak` marchează totul cu excepția fișierelor de rezervă.

![Dialogul Selectează grup cu o mască cu metacaractere tastată în câmpul de tipar](screenshots/select-by-mask.png)
*(Figura: Marcarea fișierelor după o mască cu metacaractere.)*

## Inversare, aceeași extensie și restaurare

- **Inversează selecția** (Num*, meniul Marcare) inversează fiecare marcaj: elementele marcate devin nemarcate și invers — util pentru „totul cu excepția acestora”.
- **Selectează toate cu aceeași extensie** (Alt+Num+, meniul Marcare) marchează fiecare fișier care are aceeași extensie ca elementul de sub cursor, astfel încât o singură apăsare prinde, de exemplu, toate fișierele `.pdf`.
- **Restaurează selecția** (Num/, meniul Marcare) readuce setul anterior de marcaje — util dacă o comandă le-a șters sau ați marcat grupul greșit.

## Scurtături

| Acțiune | Tastă |
|---|---|
| Comutați marcajul, coborâți | Insert |
| Comutați marcajul (elementul curent) | Space |
| Selectează tot / Deselectează tot | Ctrl+Num+ / Ctrl+Num- |
| Selectează tot (alternativă) | Cmd+A |
| Selectează grup după mască | Num+ |
| Deselectează grup după mască | Num- |
| Inversează selecția | Num* |
| Selectează toate cu aceeași extensie | Alt+Num+ |
| Restaurează selecția anterioară | Num/ |

## Note

- Marcajele și cursorul sunt independente: mutarea cursorului cu tastele săgeți nu modifică ceea ce este marcat.
- Intrarea folderului părinte (`..`) nu poate fi marcată niciodată.
- Selectează grup, Deselectează grup și Inversează selecția se potrivesc pe numele fișierului, astfel încât puteți include sau lăsa deoparte foldere în funcție de opțiunile dialogului.
- După ce o copiere, mutare sau ștergere se finalizează, elementele care au fost gestionate cu succes sunt demarcate automat, în timp ce cele care au eșuat rămân marcate ca să le puteți reîncerca.
