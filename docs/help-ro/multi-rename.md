---
title: Redenumirea multor fișiere
slug: multi-rename
section: Instrumente avansate
order: 92
related: [moving-and-renaming]
---

Instrumentul de redenumire multiplă redenumește un întreg lot de fișiere într-o singură trecere. În loc să editați numele unul câte unul, descrieți modificarea o dată — un tipar de denumire, o căutare-și-înlocuire, o schemă de numerotare sau o schimbare a majusculelor — iar Peach Commander o aplică fiecărui fișier selectat. O previzualizare live arată exact cum se va numi fiecare fișier înainte să se întâmple ceva, iar un singur Anulează pune numele originale înapoi dacă rezultatul nu a fost cel dorit.

## Redenumiți un lot de fișiere

1. Selectați fișierele pe care doriți să le redenumiți (vedeți *Selectarea fișierelor*). Doar elementele selectate sunt afectate.
2. Alegeți **Comenzi > Instrument de redenumire multiplă…** sau apăsați Ctrl+M.
3. Construiți regula de redenumire folosind câmpurile descrise mai jos. Grila de previzualizare se actualizează pe măsură ce tastați, arătând fiecare **Nume vechi** lângă **Numele nou**.
4. Verificați previzualizarea. Un rând afișat într-o culoare de evidențiere semnalează un nume care nu poate fi folosit (de exemplu, un duplicat sau un nume nepermis), astfel încât să puteți ajusta regula.
5. Când previzualizarea arată corect, faceți clic pe **Start**. Dacă vă răzgândiți, faceți clic pe **Anulează** pentru a restaura numele originale.

![Fereastra de redenumire multiplă cu câmpurile de mască, opțiunile și grila de previzualizare de la vechi la nou](screenshots/multi-rename.png)
*(Figura: grila de previzualizare se actualizează live pe măsură ce editați regula de redenumire; nimic nu se schimbă pe disc până nu faceți clic pe Start.)*

## Construirea regulii de redenumire

- **Mască de redenumire** și **Extensie** — tipare care construiesc numele și extensia noi. Folosiți butoanele de inserare rapidă, sau tastați direct substituenții: `[N]` pentru numele original, `[N1-9]` pentru un interval de caractere din el, `[C]` pentru contor, `[d]` pentru părți de dată și oră și `[P]` pentru numele folderului părinte.
- **Caută / Înlocuiește cu** — înlocuiește text în interiorul numelor. Activați **Regex** pentru potrivirea tiparelor, **Sensibil la majuscule** pentru a potrivi exact majusculele și **Repetă** pentru a înlocui fiecare apariție.
- **Majuscule** — convertiți numele în minuscule, MAJUSCULE, Prima literă majusculă sau Fiecare Cuvânt Majuscul.
- **Contor** — setați numărul de **Start**, **Pasul** dintre fișiere și câte **Cifre** de completat (de exemplu, 001, 002, 003) oriunde apare `[C]`.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Deschide instrumentul de redenumire multiplă | Ctrl+M |
| Aplică redenumirea | Enter |
| Închide fereastra | Esc |

## Sfaturi

- Nimic nu se scrie pe disc până nu faceți clic pe **Start**, astfel încât puteți experimenta liber cu regula și urmări previzualizarea.
- După o rulare, **Anulează** inversează redenumirea într-un singur pas.
- Salvați o regulă pe care o folosiți des ca **Presetare**, apoi alegeți-o din meniul de presetări data viitoare pentru a completa toate câmpurile deodată.
- Pentru a redenumi un singur fișier, sau pentru a redenumi fișiere pe măsură ce le mutați, folosiți în schimb redenumirea pe loc sau dialogul de mutare (vedeți *Mutare și redenumire*).
