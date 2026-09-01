---
title: Previzualizarea fișierelor care nu se află pe acest Mac
slug: remote-previews
section: Vizualizare și editare
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander afișează o previzualizare a fișierului de sub cursor în bara laterală de informații, în Quick View și ca miniaturi în vizualizarea galerie. Când acel fișier nu se află pe un disc atașat acestui Mac, afișarea lui costă ceva real — o descărcare, o dezarhivare sau ambele — și nimeni nu a cerut-o: cursorul doar s-a mutat pe fișier. De aceea Peach Commander decide dinainte cât poate costa o previzualizare; această pagină explică ce decide și cum puteți schimba.

## Fișiere din interiorul unei arhive

Un fișier dintr-o arhivă poate fi previzualizat exact ca unul din afara ei. Peach Commander îl dezarhivează în fundal într-o copie temporară și o afișează pe aceasta. Același lucru este valabil pentru Quick Look, pentru deschiderea într-o altă aplicație cu Enter sau dublu clic și pentru submeniul Deschide cu.

Ce primește cealaltă aplicație este o copie, iar aceasta este doar pentru citire: ce modificați acolo nu se scrie înapoi în arhivă. Peach Commander o spune prima dată, cu o casetă pentru a nu mai spune. Pentru a edita un fișier care se află într-o arhivă, dezarhivați-l mai întâi cu F5 și lucrați cu fișierul dezarhivat.

## Cât poate costa o previzualizare

O previzualizare urmărește cursorul, deci se întâmplă fără să fie cerută. De aceea i se aplică un buget care depinde de unde se află de fapt conținutul fișierului:

- Pe un disc atașat acestui Mac nu există nicio limită, iar previzualizările se comportă exact ca până acum.
- Într-o locație de rețea — o partajare montată, FTP, SFTP, Amazon S3 sau un volum de plugin — fișierele sunt previzualizate până la 4 MB, cât timp Peach Commander nu a măsurat cât de rapidă este de fapt acea conexiune. După aceea permite tot ce poate citi în aproximativ o secundă și jumătate, astfel încât o partajare rapidă afișează fișiere mari, iar una lentă refuză fișiere mici.
- Într-o arhivă, un fișier este dezarhivat pentru previzualizare până la 32 MB.
- Un fișier pe care un serviciu cloud nu l-a descărcat încă pe acest Mac nu este adus niciodată doar pentru că a ajuns cursorul pe el.
- În formatele de arhivă care trebuie dezarhivate fișier cu fișier — CPIO, ISO, CAB, LZH și altele asemenea — nu se previzualizează nimic automat, pentru că fiecare fișier în parte costă o parcurgere completă a arhivei.

O previzualizare refuzată nu este un panou gol: bara laterală arată pictograma fișierului, numele, dimensiunea și data, plus un rând cu motivul. Quick Look îl afișează oricum și nu este supus niciuneia dintre aceste limite.

## Modificarea limitelor

1. Deschideți Setări ▸ Editare/Vizualizare.
2. Dezactivați „Previzualizează automat fișierele din locațiile de rețea” pentru a opri complet previzualizările în rețea sau setați „Fișiere din rețea până la (MB)” la dimensiunea dorită.
3. Activați „Descarcă fișierele din cloud pentru previzualizare” dacă preferați previzualizarea în locul traficului economisit.
4. Setați „Dezarhivează din arhive până la (MB)” pentru cât de mare poate fi un fișier dintr-o arhivă.

Alte două setări nu au un control propriu și se află în `peachcmd.ini`, la `[Preview]`: `AutoPreviewSeconds` este bugetul de timp care se aplică după ce o conexiune a fost măsurată (1,5 implicit; 0 îl dezactivează), iar `AutoPreviewLocalMB` este un plafon pentru discurile locale (0 înseamnă fără limită).

## Unde ajung copiile dezarhivate

Copiile sunt scrise în dosarul temporar al sistemului, iar previzualizările le împart în loc ca fiecare să și-o facă pe a sa. O copie făcută pentru o previzualizare este ștearsă când părăsiți arhiva; o copie predată altei aplicații rămâne până când închideți Peach Commander, pentru că acea aplicație o mai are deschisă. Ce lasă în urmă o închidere neașteptată este recunoscut la următoarea pornire și curățat atunci.

Miniaturile din vizualizarea galerie respectă același buget, iar fișierele dintr-o arhivă își păstrează acolo pictograma generică în loc de o miniatură.
