---
title: Găsirea fișierelor
slug: searching
section: Găsirea fișierelor
order: 60
related: [selecting-files, quick-search-and-filter]
---

Când trebuie să depistați fișiere oriunde pe Mac-ul dvs. — după nume, după ce conțin, sau după dimensiune și dată — folosiți fereastra Găsește fișiere. Caută în unul sau mai multe foldere (și subfolderele lor), poate privi în interiorul fișierelor text și al arhivelor și vă permite să trimiteți tot ce găsește direct într-un panou, astfel încât să acționați asupra rezultatelor ca și cum ar fi un folder obișnuit.

## Găsiți fișiere după nume

1. În panoul care arată folderul pe care doriți să-l căutați, alegeți **Comenzi > Găsește fișiere…** (sau apăsați Cmd+Shift+F).
2. Pe fila **General**, tastați un tipar de nume în **Caută**. Puteți folosi caractere joker precum `*.pdf` sau `raport_*.docx`. Pentru a căuta în mai multe foldere deodată, listați-le în câmpul folderului de pornire separate cu punct și virgulă (`;`).
3. Faceți clic pe **Start**. Potrivirile apar în lista de rezultate de mai jos pe măsură ce sunt găsite.
4. Faceți dublu clic pe orice rezultat pentru a sări la acel fișier în panoul activ, sau selectați un rezultat și faceți clic pe **Vizualizează** (F3) pentru a-l deschide în vizualizatorul încorporat.

![Fereastra Găsește fișiere pe fila General, arătând tiparul de nume, folderul și lista de rezultate](screenshots/find-files-general.png)
*(Figura: fila General — căutare după tipar de nume în unul sau mai multe foldere.)*

## Căutare după conținut, dimensiune și dată

1. Pentru a căuta în interiorul fișierelor, tastați textul în **Găsește text** pe fila General — se caută ce se află în câmp, iar un câmp gol caută doar după nume. Opțiunile vă permit să-l faceți **Sensibil la majuscule**, să potrivească doar un **Cuvânt întreg**, să trateze textul ca o **Expresie regulată**, să facă o **Căutare de conținut hexazecimal** sau să găsească fișiere care **Nu conțin** textul.
2. Comutați la fila **Avansat** pentru a îngusta rezultatele după **Dimensiune** (de exemplu `10K` până la `5M`), după interval de **dată de modificare**, sau la fișiere modificate în ultimele N zile.
3. Activați **Caută în arhive** pentru a privi în arhivele găsite — aceleași formate pe care le puteți deschide cu Enter, inclusiv cele adăugate de un plugin de arhivare. Arhivele care nu au putut fi deschise sunt raportate la finalul căutării.
4. Pentru a limita căutarea la ce ați ales deja, activați **Caută doar în elementele selectate** înainte de a începe.
5. Activați **Caută și în comentariile fișierelor** și textul va fi căutat în comentariul fiecărui fișier pe lângă conținutul său. Așa regăsiți un fișier după ceea ce ați scris *despre* el — „originalul clientului”, „înlocuit de exportul din 2026” — când în fișierul însuși nu apare nimic de felul acesta. Un rezultat găsit astfel arată comentariul în loc de o linie din fișier și niciun număr de linie, fiindcă potrivirea nu se află în textul fișierului. Majusculele, cuvântul întreg și expresiile regulate se aplică unui comentariu exact ca unui conținut; o căutare hexazecimală nu, pentru că un comentariu este text scris de cineva. **Care nu conține** rămâne coerent: un fișier este listat când textul nu se află nici în conținut, nici în comentariu. Dacă modulul Note este activat, nota sa este disponibilă ca câmp de conținut, pe care puteți pune o condiție la **Plugins** — vedeți [Lucrul cu module](plugins.md).
6. Unele pluginuri pot transforma un fișier în text pe care fișierul însuși nu îl conține — pluginul de decompilare face din `.class` sursă Java. Activați **Caută în textul oferit de pluginuri** și acele fișiere sunt căutate ca acel text în loc de octeții proprii, astfel încât o formulare din sursă se găsește într-o clasă compilată. Opțiunea apare doar când un astfel de plugin este instalat și este mai lentă: producerea textului poate însemna un decompilator pe fișier.

![Fereastra Găsește fișiere pe fila Avansat, arătând filtrele de dimensiune și dată](screenshots/find-files-advanced.png)
*(Figura: fila Avansat — filtrați după dimensiune, dată și alte atribute.)*

Dacă aveți pluginuri care adaugă câmpuri de conținut (precum dimensiunile imaginilor), fila **Pluginuri** vă permite să cereți ca un câmp să corespundă unei condiții — de exemplu, doar imagini mai late de 1000 de pixeli.

![Fereastra Găsește fișiere pe fila Pluginuri, arătând o condiție pe un câmp de conținut](screenshots/find-files-plugins.png)
*(Figura: fila Pluginuri — potrivire pe câmpuri de conținut furnizate de pluginuri.)*

## Căutări rapide cu Spotlight

Pentru folderele locale pe care macOS le-a indexat deja, activați **Folosește Spotlight** pe fila General pentru rezultate aproape instantanee. Spotlight caută în index în loc să scaneze fișierele, astfel încât ignoră expresiile regulate, limitele de adâncime ale subfolderelor și domeniul doar-selectate.

## Reutilizarea și predarea rezultatelor

- **Trimite în listă** plasează fiecare rezultat în panoul activ ca o listă temporară, astfel încât să puteți copia, muta sau șterge întregul set deodată.
- Pe fila **Încarcă / Salvează**, alegeți **Salvează ca șablon…** pentru a stoca căutarea curentă (tipare și opțiuni) și a o alege din nou mai târziu din lista de șabloane.
- **Caută** și **Găsește text** rețin fiecare ultimele 20 de intrări folosite, cea mai recentă prima — faceți clic pe săgeata de la capătul câmpului pentru a alege din nou una. Un termen folosit de două ori urcă înapoi în vârf în loc să apară de două ori, iar listele supraviețuiesc închiderii ferestrei și ieșirii din aplicație. **Golește istoricul…** de pe fila **Încarcă / Salvează** le uită pe amândouă; șabloanele salvate nu sunt afectate.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Deschide Găsește fișiere | Cmd+Shift+F sau Option+F7 |
| Începe / oprește căutarea | Butonul Start din fereastră |
| Vizualizează rezultatul selectat | F3 |

## Note

- Căutarea în conținut citește fișierele întregi pentru dosarele locale și pentru arhive; în locațiile din rețea fișierele foarte mari sunt citite doar parțial (aproximativ 16 MB, sau 64 MB când se folosește o expresie regulată).
- Căutarea în interiorul arhivelor coboară până la patru niveluri de arhive imbricate.
- **Include folderele în rezultate** listează de asemenea folderele ale căror nume se potrivesc, nu doar fișierele.
- Spotlight acoperă doar folderele locale indexate; pentru locații de rețea sau potrivire bazată pe tipar, lăsați-l dezactivat și lăsați Găsește fișiere să scaneze.
