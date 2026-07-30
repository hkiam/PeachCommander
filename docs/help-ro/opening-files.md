---
title: Deschiderea fișierelor și folderelor
slug: opening-files
section: Fișiere și foldere
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander deschide fișiere și foldere direct din oricare panou, folosind aceleași aplicații și funcții de sistem pe care vă bazați deja în Finder. Apăsați o tastă pentru a deschide elementul de sub cursor în aplicația sa implicită sau faceți clic dreapta pentru a ajunge la un meniu complet de acțiuni — deschideți cu altă aplicație, afișați elementul în Finder, partajați-l sau deschideți o fereastră Terminal chiar acolo unde vă aflați.

## Deschiderea unui element

1. Faceți clic pe un fișier sau folder dintr-un panou pentru a poziționa cursorul pe el (rândul evidențiat).
2. Apăsați Enter (sau faceți dublu clic).
   - Un folder se deschide în același panou.
   - Un fișier se deschide în aplicația sa macOS implicită — aceeași aplicație pe care ar folosi-o Finder.
   - O arhivă (cum ar fi un .zip) se deschide ca un folder, astfel încât să puteți naviga în interiorul ei.

![Fereastra principală Peach Commander cu ambele panouri afișând fișiere și foldere](screenshots/main-window.png)
*(Figura: Poziționați cursorul pe orice element, apoi apăsați Enter pentru a-l deschide.)*

## Deschiderea cu altă aplicație, afișarea sau partajarea

Faceți clic dreapta pe un fișier (sau apăsați Shift+F10) pentru a deschide meniul elementului, apoi alegeți:

- **Deschide** sau **Deschide în aplicația implicită** — deschide fișierul așa cum ar face Enter.
- **Deschide cu** — alegeți orice aplicație instalată care poate deschide acest fișier sau alegeți **Altul…** pentru a căuta una.
- **Quick Look** — previzualizați fișierul fără a deschide o aplicație.
- **Afișează în Finder** — arată fișierul selectat într-o fereastră Finder.
- **Partajează…** — trimite fișierul prin foaia de partajare macOS.

Meniul îmbină de asemenea **Serviciile** standard macOS pentru fișierul selectat și adaugă **Etichete**, astfel încât să puteți aplica etichetele color obișnuite din Finder.

## Deschiderea unui Terminal în folderul curent

Alegeți **Deschide Terminal aici** din meniul Fișier sau Comenzi (Cmd+Option+T) pentru a deschide o fereastră Terminal deja îndreptată spre folderul panoului activ.

## Scurtături

| Acțiune | Tastă |
|---|---|
| Deschideți elementul de sub cursor | Enter |
| Vizualizați fișierul (vizualizator) | F3 |
| Editați fișierul | F4 |
| Previzualizare Quick Look | Cmd+Y |
| Obțineți informații / proprietăți | Option+Enter |
| Deschideți meniul elementului | Shift+F10 sau clic dreapta |
| Deschideți Terminal aici | Cmd+Option+T |

## Note

- „Aplicația implicită” înseamnă aplicația pe care macOS este setat să o folosească pentru acel tip de fișier; o schimbați în panoul Obține informații al fișierului, exact ca în Finder.
- **Afișează în Finder**, **Partajează…** și **Deschide cu ▸ Altul…** se aplică elementelor de pe discul Mac-ului dumneavoastră. Nu sunt disponibile pentru elemente din interiorul unei arhive sau de pe o conexiune la distanță (FTP/SFTP).
- Clicul dreapta pe un proces în execuție (într-o vizualizare de procese) afișează un meniu mai scurt, specific procesului, în locul acțiunilor pentru fișiere.
