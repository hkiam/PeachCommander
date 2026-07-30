---
title: Bara de butoane
slug: toolbar
section: Personalizare
order: 110
related: [keyboard-shortcuts, settings]
---

Bara de butoane este banda de butoane cu pictograme de-a lungul părții de sus a ferestrei. Fiecare buton este o comandă rapidă cu un clic pe care o definiți dvs.: rulați o comandă încorporată, lansați un program sau o aplicație externă, săriți la un folder, sau deschideți o întreagă sub-bară cu mai multe butoane. Este cel mai rapid mod de a avea la îndemână acțiunile pe care le folosiți cel mai mult și o puteți adapta exact la modul în care lucrați.

## Personalizarea barei de butoane

1. Alegeți **Configurare > Personalizează bara de instrumente…**, sau faceți clic dreapta pe bară și alegeți **Editează bara de butoane…**.
2. Lista din stânga arată butoanele curente. Folosiți **+** pentru a adăuga un buton, **—** pentru a adăuga un separator, **−** pentru a elimina butonul selectat, și **↑ / ↓** pentru a reordona.
3. Selectați un buton și completați formularul din dreapta:
   - **Comandă** — tastați o comandă încorporată, sau faceți clic pe **Alege…** pentru a selecta una dintr-o listă. Puteți de asemenea introduce calea unui program sau a unei aplicații, un folder de deschis, sau o altă bară de butoane de folosit ca sub-bară.
   - **Etichetă** — eticheta și indiciul afișate pentru buton.
   - **Parametri** și **Cale de pornire** — transmise programelor externe. Substituenții precum `%P` (folderul sursă), `%N` (fișierul curent) și `%S` (fișierele selectate) se completează când butonul rulează.
   - **Pictogramă** — alegeți un SF Symbol sau folosiți pictograma proprie a unui fișier sau a unei aplicații; activați **doar pictogramă** pentru a ascunde eticheta.
4. Faceți clic pe **Salvează**. Banda se reîncarcă imediat.

![Bara de butoane de-a lungul părții de sus a ferestrei cu butoane cu pictograme](screenshots/button-bar-crop.png)
*(Figura: bara de butoane se află deasupra panourilor de fișiere; fiecare buton rulează o comandă, un program, un folder sau o sub-bară.)*

## Sub-bare și depășire

Un buton poate deschide o *sub-bară* — un al doilea set de butoane suprapus peste primul. Faceți clic pe el pentru a coborî; un buton **◀** în stânga vă readuce la bara anterioară. Când sunt mai multe butoane decât încap în lățimea ferestrei, cele în plus se pliază în spatele unui chevron **»** la capătul din dreapta; faceți clic pe el pentru a ajunge la ele.

## Aruncați fișiere pe un buton

Puteți trage fișiere sau foldere direct pe un buton:

- **Buton de folder** — elementele aruncate sunt copiate în acel folder în fundal.
- **Buton de program** — programul rulează cu elementele aruncate ca selecția sa.
- **Buton de comandă** — comanda rulează ca de obicei.

## Bară de butoane verticală

Pentru a muta banda din partea de sus a ferestrei într-o coloană de-a lungul părții stângi, alegeți **Vizualizare > Bară de butoane verticală**. Alegeți-o din nou pentru a reveni la banda orizontală.

## Note

- Bara este stocată într-un fișier standard de bară de butoane compatibil cu Total Commander, astfel încât barele pe care le aveți deja pot fi reutilizate.
- Acestor acțiuni nu le sunt asignate comenzi rapide de tastatură implicit, dar puteți adăuga propriile — vedeți [Comenzi rapide de tastatură](keyboard-shortcuts).
- Un buton fără pictogramă și fără comandă apare ca un separator simplu, util pentru gruparea butoanelor înrudite.
