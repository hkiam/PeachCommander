---
title: Istoric global
slug: history
section: Organizarea vizualizării
order: 47
related: [favorites, navigating]
---

Istoricul global este o fereastră care își amintește propria ta muncă: dosare vizitate, fișiere deschise, operațiuni efectuate și comenzi rulate. Apasă Ctrl+Cmd+H de oriunde, începe să scrii și te întorci la dosarul de ieri într-o secundă — fără mouse.

## Deschiderea istoricului

1. Apasă Ctrl+Cmd+H sau alege **Mergi > Istoric…**. Nu contează care panou este activ.
2. Scrie câteva litere. Potrivirea nu trebuie să fie exactă sau continuă: `proj rep` găsește `~/Projects/annual-report.txt`.
3. Parcurge rezultatele cu tastele sus și jos în timp ce continui să scrii.
4. Enter acționează asupra intrării evidențiate, Esc închide fereastra.

Intrările sunt ordonate după cât de recent *și* cât de des le-ai folosit, așa că locurile în care lucrezi cel mai mult sunt deja sus. Intrările fixate conduc mereu lista.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Figură: Istoricul global — câmpul de căutare are focusul, iar lista este ordonată după cât de recent și cât de des ai folosit fiecare intrare.)*

## Filtrarea după tip

Butoanele de sub câmpul de căutare limitează lista la toate intrările, la dosare, la fișiere, la operațiuni sau la favorite. Option+1 până la Option+5 comută între ele de la tastatură.

## Acțiuni pe o intrare

| Acțiune | Scurtătură |
| --- | --- |
| Deschide intrarea evidențiată | Return |
| Arată-o în panou, cu cursorul pe ea | Option+Return |
| Deschide una dintre cele nouă intrări cele mai relevante | Cmd+1 … Cmd+9 |
| Schimbă panoul în care se deschid | Tab |
| Fixează sau eliberează intrarea | Cmd+P |
| Elimină intrarea din istoric | Cmd+Delete |
| Copiază calea intrării | Option+Cmd+C |
| Arată intrarea în Finder | Cmd+Shift+R |
| Închide istoricul | Esc |

Enter face ceea ce se cuvine intrării: un dosar se deschide în panoul țintă, un fișier se deschide așa cum s-ar deschide din panou, iar o linie de comandă este pusă în linia de comandă ca să o verifici și să o rulezi. Panoul țintă este numit în josul ferestrei, iar Tab îl schimbă.

## Repetarea unei operațiuni

O copiere sau o mutare apare la **Operațiuni**, iar Enter o rulează din nou — aceleași elemente în același dosar, prin coada de transfer obișnuită și întrebările ei despre suprascriere. Elementele care nu mai există sunt sărite, iar dacă nu mai rămâne niciunul ți se spune.

Ștergerile și redenumirile sunt listate, dar nu se repetă niciodată: Enter arată în schimb unde s-au petrecut. Repetarea unei ștergeri nu ar trebui să fie la o tastă distanță într-o listă pe care doar o parcurgi.

## Ținerea sub control

Setări ▸ Diverse decide dacă se ține un istoric, câte intrări păstrează și după câte zile le uită. Intrările fixate sunt scutite, iar 0 zile păstrează totul; lista se află în `history.ini` din dosarul tău de configurare și supraviețuiește repornirilor.

## Note

- Deschiderea a ceva din istoric contează ca utilizare — de aceea ceea ce reiei urcă tot mai sus.
- Dosarele din interiorul unei arhive, de pe un server sau dintr-o unitate de modul nu sunt ținute minte: o astfel de cale nu înseamnă nimic fără montarea care a produs-o, iar istoricul propriu al panoului le păstrează cât timp este deschisă.
- Acesta nu este istoricul de dosare al panoului de pe Alt+jos, care enumeră doar unde a fost acel panou, în ordine.
