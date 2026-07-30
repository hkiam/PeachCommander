---
title: Fereastra principală
slug: interface-overview
section: Primii pași
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander afișează două liste de fișiere alăturate, astfel încât să puteți vedea în același timp de unde vin fișierele și încotro se îndreaptă. Cea mai mare parte a muncii se desfășoară în aceste două panouri; barele din jurul lor vă permit să comutați între discuri, să săriți la un folder și să rulați comenzile obișnuite cu fișiere fără a lăsa tastatura. Acest tur denumește fiecare parte a ferestrei, astfel încât restul ajutorului să aibă sens.

![Fereastra principală Peach Commander cu cele două panouri și barele înconjurătoare](screenshots/main-window.png)
*(Figura: Fereastra principală — două panouri cu bara de butoane, bara de discuri și barele de cale deasupra, iar bara tastelor funcționale dedesubt.)*

## Cele două panouri și panoul activ

Fereastra este împărțită într-un panou stâng și un panou drept, fiecare afișând conținutul unui folder. Doar un singur panou este activ la un moment dat: acesta afișează cursorul (un rând evidențiat), iar bara sa de cale este desenată cu un fundal colorat. Comenzi precum copierea și mutarea acționează întotdeauna asupra panoului activ și trimit fișierele către celălalt.

1. Faceți clic oriunde într-un panou pentru a-l activa sau apăsați Tab pentru a comuta între ele.
2. Folosiți tastele săgeți pentru a deplasa cursorul în sus și în jos în panoul activ.
3. Apăsați Enter pe un folder pentru a-l deschide sau pe `..` din partea de sus a listei pentru a urca un nivel.

## Barele din jurul panourilor

- **Bara de butoane** (sus): un rând de butoane plate pentru comenzi frecvente. Faceți clic pe un buton pentru a rula comanda sa; faceți clic dreapta pe un buton pentru a edita bara.
- **Bara de discuri**: câte un buton pentru fiecare disc sau volum disponibil, fiecare cu un control de ejectare și spațiul liber. Faceți clic pe un volum pentru a comuta acel panou la el.
- **Bara de cale**: afișează folderul curent ca o cale de navigare pe care se poate face clic. Faceți clic pe un segment pentru a sări direct la acel folder sau faceți clic pe cale pentru a tasta o locație.
- **Bara de stare** (sub fiecare listă): un rezumat curent al panoului — câte fișiere și foldere sunt selectate și dimensiunea lor totală.
- **Linia de comandă** (jos): un câmp de text în care puteți tasta o comandă în stil shell, care rulează în folderul curent.
- **Bara tastelor funcționale** (jos de tot): șase butoane etichetate F3 Vizualizare, F4 Editare, F5 Copiere, F6 Mutare, F7 Folder nou și F8 Ștergere. Faceți clic pe un buton sau apăsați tasta corespunzătoare.

![Prim-plan al barei de discuri cu butoanele de volum și spațiul liber](screenshots/drive-bar-crop.png)
*(Figura: Bara de discuri — câte un buton pentru fiecare volum, cu un control de ejectare și spațiul liber rămas.)*

## Scurtături

| Acțiune | Scurtătură |
|---|---|
| Comutați panoul activ | Tab |
| Deschideți folderul / elementul de sub cursor | Enter |
| Urcați un folder | Backspace |
| Vizualizați fișierul | F3 |
| Editați fișierul | F4 |
| Copiați în celălalt panou | F5 |
| Mutați / redenumiți în celălalt panou | F6 |
| Folder nou | F7 |
| Ștergeți (la Coșul de gunoi) | F8 |

## Note

- Bara tastelor funcționale se reetichetează în timp real când țineți apăsat un modificator. Ținând apăsat Shift, de exemplu, schimbă F6 într-o acțiune de redenumire pe loc, astfel încât butoanele afișează întotdeauna ce vor face tastele în acel moment.
- Aproape fiecare bară poate fi afișată sau ascunsă. Uitați-vă în meniurile Vizualizare și Configurare pentru a activa și dezactiva bara de butoane, bara de discuri, linia de comandă sau bara tastelor funcționale ori pentru a stivui cele două panouri sus și jos în loc de alăturat.
- Pe multe tastaturi Mac, tastele F acționează în mod implicit ca elemente de control media și de luminozitate. Țineți apăsată tasta Fn împreună cu F3-F8 sau activați „Folosiți tastele F1, F2 etc. ca taste funcționale standard” în Setări de sistem pentru a le folosi direct.
