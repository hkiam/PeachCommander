---
title: Moduri de vizualizare și sortare
slug: view-modes-and-sorting
section: Organizarea vizualizării
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Fiecare panou își poate afișa folderul în dispunerea potrivită sarcinii: o listă detaliată cu coloane, o listă compactă cu mai multe coloane de nume, o grilă de pictograme, o galerie cu miniaturi mari, sau un arbore de foldere. Puteți de asemenea sorta lista după nume, tip de fișier, dimensiune sau dată, alege exact ce coloane se afișează și activa sortarea naturală (numerică), astfel încât numele cu numere să se alinieze cum vă așteptați. Modul de vizualizare, ordinea de sortare și coloanele se setează per panou, astfel încât cele două părți pot arăta complet diferit.

## Schimbarea modului de vizualizare

1. Faceți clic pe panoul pe care doriți să-l modificați astfel încât să devină activ.
2. Deschideți meniul Vizualizare și alegeți un mod: **Complet (Detalii)** pentru lista cu coloane, **Scurt (Coloane)** pentru o listă densă cu mai multe coloane de nume, **Pictograme** pentru o grilă de pictograme, **Miniaturi (Galerie)** pentru previzualizări mari, sau **Arbore** pentru un arbore de foldere.
3. Pentru a parcurge rapid modurile fără a deschide meniul, apăsați Cmd+Shift+M. Fiecare apăsare trece la modul următor.

![Un panou care arată diferitele moduri de vizualizare: detalii, scurt, pictograme și galerie](screenshots/view-modes.png)
*(Figura: același folder afișat ca o listă detaliată, o listă scurtă de coloane, o grilă de pictograme și o galerie de miniaturi.)*

## Sortarea listei de fișiere

1. În vizualizarea Detalii, faceți clic pe un antet de coloană (Nume, Tip, Dimensiune sau Dată) pentru a sorta după el. O mică săgeată în antet arată coloana și direcția de sortare curente.
2. Faceți clic din nou pe același antet pentru a inversa ordinea.
3. Puteți de asemenea alege Vizualizare > Sortează după și alege Nume, Tip de fișier, Dimensiune, Dată sau Nesortat.

Folderele se sortează întotdeauna împreună în partea de sus, înaintea fișierelor, iar intrarea `..` care vă duce cu un nivel mai sus se fixează prima. Sortarea după nume sau tip de fișier este ascendentă (de la A la Z) implicit; sortarea după dimensiune sau dată este cele mai noi sau mai mari primele implicit.

## Alegerea coloanelor afișate

1. Alegeți Configurare > Coloane….
2. Activați sau dezactivați coloanele și setați ordinea lor. Coloanele disponibile includ Nume, Tip, Dimensiune, Dată, Atr (atribute), Etichete și Comentariu.
3. Aplicați modificările. Coloanele afectează vizualizarea Detalii a panoului activ.

![Fereastra de configurare a coloanelor cu lista de coloane disponibile](screenshots/columns-config.png)
*(Figura: alegeți ce coloane se afișează în vizualizarea Detalii și setați ordinea lor.)*

## Comenzi rapide

| Acțiune | Comandă rapidă |
|---|---|
| Parcurge modurile de vizualizare | Cmd+Shift+M |
| Vizualizare scurtă (coloane) | Ctrl+F1 |
| Vizualizare completă (detalii) | Ctrl+F2 |
| Vizualizare miniaturi (galerie) | Ctrl+Shift+F1 |
| Vizualizare arbore | Ctrl+F8 |
| Sortează după nume | Ctrl+F3 |
| Sortează după tip de fișier | Ctrl+F4 |
| Sortează după dimensiune | Ctrl+F5 |
| Sortează după dată | Ctrl+F6 |

## Sfaturi

- Sortarea naturală (numerică) este activată implicit, astfel încât `file2` vine înaintea lui `file10` în loc de după. O puteți dezactiva în Configurare > Opțiuni în setările de vizualizare.
- Puteți face o coloană mai lată sau mai îngustă în vizualizarea Detalii trăgând linia de separare dintre anteturile de coloană.
- Dacă folosiți navigarea cu tastatura din macOS (Configurări sistem ▸ Tastatură), rândul Ctrl+F1 – Ctrl+F8 aparține sistemului — bara de meniu, Dock, bara de instrumente — și nu ajunge niciodată la Peach Commander. Comutați schema de taste pe **macOS** în configurări: modurile de afișare sunt atunci pe Cmd+1, Cmd+2 și Cmd+3, iar sortarea pe Alt+Cmd+1 – Alt+Cmd+4.
- Modul de vizualizare, ordinea de sortare și alegerea coloanelor sunt reținute per panou, astfel încât puteți avea o parte ca o listă detaliată și cealaltă ca o galerie foto.
