---
title: Căutare rapidă și filtru
slug: quick-search-and-filter
section: Organizarea vizualizării
order: 44
related: [searching, view-modes-and-sorting]
---

Când un folder conține sute de elemente, rareori trebuie să derulați. Peach Commander vă permite să săriți direct la un fișier tastându-i numele (căutare rapidă), să reduceți lista doar la elementele care vă interesează (filtru rapid) și să afișați sau ascundeți fișierele cu punct pe care macOS le ține de obicei în afara vederii. Toate trei funcționează în interiorul panoului activ fără a deschide un dialog.

## Salt la un fișier prin tastare (căutare rapidă)

1. Faceți clic pe un panou de fișiere astfel încât să fie activ.
2. Începeți să tastați începutul unui nume. Cursorul sare la primul element care se potrivește.
3. Continuați să tastați pentru a rafina potrivirea, sau apăsați din nou aceeași literă pentru a parcurge elementele care încep cu acea literă.
4. Textul tastat se șterge după o scurtă pauză, astfel încât puteți începe o căutare nouă oricând.

Implicit, literele simple merg la linia de comandă, iar căutarea rapidă este declanșată cu Ctrl+Option+literă (comportamentul clasic). Puteți comuta căutarea rapidă să răspundă la tastarea simplă în schimb, sau să o dezactivați, în setările de configurare.

## Filtrarea listei (filtru rapid)

1. În panoul activ, apăsați Ctrl+S pentru a activa filtrul rapid.
2. Tastați o mască de filtru. Panoul se îngustează live la elementele care se potrivesc pe măsură ce tastați.
3. Apăsați Esc pentru a șterge filtrul și a afișa din nou totul.

Filtrul acceptă mai multe tipuri de măști:

- **Text simplu** se potrivește cu orice nume care conține ce ați tastat (de exemplu, `raport` arată fiecare element cu „raport" oriunde în numele său).
- **Caractere joker** folosesc `*` (orice caractere) și `?` (un caracter). Separați mai multe măști cu punct și virgulă și adăugați excluderi după o bară verticală, de exemplu `*.jpg;*.png|*thumb*` pentru a afișa imagini, dar a ascunde miniaturile.
- **Etichete Finder** filtrează după culoarea etichetei: tastați `tag:red` (sau `#red`) pentru a afișa doar elementele cu etichetă roșie, sau un simplu `tag:` pentru a afișa tot ce poartă orice etichetă.

## Afișarea fișierelor ascunse

Apăsați Ctrl+H, sau alegeți comanda din meniul Vizualizare, pentru a comuta elementele ascunse (nume care încep cu un punct și fișiere ascunse de sistem). Setarea se aplică panoului activ și este reținută între sesiuni.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Căutare rapidă (mod clasic) | Ctrl+Option+literă |
| Filtru rapid pornit/oprit | Ctrl+S |
| Șterge filtrul / anulează | Esc |
| Afișează/ascunde fișierele ascunse | Ctrl+H |

## Note

- Căutarea rapidă doar mută cursorul; filtrul rapid schimbă efectiv care elemente sunt listate. Folosiți filtrul când doriți să lucrați pe un subset (de exemplu, să selectați sau copiați doar potrivirile).
- Setările de filtru și fișiere ascunse sunt per panou, astfel încât cele două părți pot afișa lucruri diferite deodată.
- Căutarea rapidă potrivește numele de la început; modul text simplu al filtrului rapid potrivește oriunde în nume. Folosiți un caracter joker precum `*text*` dacă doriți ca filtrul să se comporte la fel.
