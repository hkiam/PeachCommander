---
title: Vizualizarea fișierelor
slug: viewing-files
section: Vizualizare și editare
order: 70
related: [editing-files, searching]
---

Peach Commander are un vizualizator integrat care vă permite să priviți în interiorul unui fișier fără a deschide altă aplicație sau a modifica fișierul. Apăsați F3 pe elementul de sub cursor, iar vizualizatorul se deschide instantaneu, chiar și pentru fișiere foarte mari. El alege automat cel mai bun mod de a afișa conținutul: text lizibil, cod colorat sintactic, un afișaj hexazecimal brut sau o imagine la dimensiune completă. Puteți de asemenea previzualiza un fișier chiar în fereastră folosind Quick View sau îl puteți preda către macOS Quick Look.

## Vizualizarea unui fișier

1. Deplasați cursorul pe un fișier din panoul activ.
2. Apăsați F3 (sau alegeți Vizualizare din meniul Fișier). Vizualizatorul se deschide în propria sa fereastră.
3. Folosiți bara de instrumente pentru a comuta modul de afișare a conținutului: Text, Cod, Hex, Imagine sau Randat. Lăsați-l pe setarea automată pentru ca Peach Commander să decidă.
4. Derulați cu tastele săgeți, Page Up/Page Down și bara de derulare. Pentru text lung, activați butonul de minihartă pentru a vedea și a naviga dintr-o privire prin întregul fișier.
5. Apăsați N pentru a sări la următorul fișier selectat sau închideți fereastra cu Esc.

![Vizualizatorul integrat afișând un fișier text cu miniharta în dreapta](screenshots/lister-text.png)
*(Figura: Vizualizarea unui fișier text, cu selectorul de reprezentare și miniharta în bara de instrumente.)*

## Găsirea textului și schimbarea codificării

- Apăsați Ctrl+F pentru a căuta în interiorul fișierului. Apăsați F3 pentru a sări la următoarea potrivire și Shift+F3 pentru cea anterioară.
- Dacă textul pare deteriorat, faceți clic pe Codificare în bara de instrumente (sau apăsați E) pentru a parcurge codificările de text până când se citește corect; setarea automată reușește de obicei.
- Apăsați W pentru a comuta încadrarea cuvintelor pentru liniile lungi.

## Quick View și Quick Look

Quick View afișează o previzualizare în timp real în panoul pe care *nu* îl folosiți, astfel încât să puteți continua să navigați pe o parte în timp ce previzualizați pe cealaltă.

1. Apăsați Ctrl+Q. Panoul inactiv se transformă într-o zonă de previzualizare.
2. Deplasați cursorul peste diferite fișiere din panoul activ pentru a previzualiza fiecare.
3. Apăsați din nou Ctrl+Q sau Esc pentru a readuce panoul la o listă normală de fișiere.

Pentru o previzualizare rapidă pe tot ecranul gestionată de macOS însuși, apăsați Cmd+Y (Quick Look). Apăsați din nou Cmd+Y sau Space pentru a o închide.

## Scurtături

| Acțiune | Scurtătură |
| --- | --- |
| Vizualizați fișierul de sub cursor | F3 |
| Vizualizați doar fișierul de sub cursor (ignorați fișierele marcate) | Shift+F3 |
| Deschideți într-un vizualizator extern | Option+F3 |
| Găsiți în vizualizator | Ctrl+F |
| Următoarea / precedenta potrivire | F3 / Shift+F3 |
| Quick View în celălalt panou | Ctrl+Q |
| Quick Look (previzualizare macOS) | Cmd+Y |
| Închideți vizualizatorul sau Quick View | Esc |

## Note

- Vizualizatorul este doar-citire. Pentru a modifica un fișier, folosiți în schimb editorul (consultați Editarea fișierelor).
- Fișierele foarte mari se deschid fără întârziere: textul deschide o vizualizare rapidă, care se poate derula, iar vizualizarea hex se transmite direct de pe disc, la orice dimensiune.
- Apăsați F3 pe un folder pentru a vedea un rezumat al conținutului său și dimensiunea totală în loc de octeții fișierului.
- Modul Randat afișează conținut formatat, cum ar fi pagini web; modul hex afișează octeții bruți alături de caracterele lor, ceea ce este util pentru inspectarea fișierelor binare.
