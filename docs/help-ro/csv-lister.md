---
title: Fișiere CSV ca tabel
slug: csv-lister
section: Pluginuri
order: 129
related: [plugins, viewing-files, log-viewer]
---

Apăsați **F3** pe un fișier `.csv` sau `.tsv` și se deschide ca un tabel adevărat — coloane, antete, sortare și filtru — în loc de linii de text cu virgule în ele.

Este o extensie: o puteți dezactiva sau elimina din **Configurare ▸ Extensii…**. Fără ea, F3 arată fișierul ca text simplu, ceea ce pentru unul mic rămâne perfect lizibil.

## Delimitatorul este dedus, nu presupus

Virgula, punctul și virgula, tabulatorul, bara verticală și două puncte sunt toate candidate. Extensia le numără pe fiecare în primele douăzeci de linii și o alege pe cea care apare de același număr de ori pe cele mai multe linii — un fișier în care fiecare rând are patru puncte și virgulă este un fișier cu punct și virgulă, orice ar spune extensia numelui. Contează în practică: un `.csv` exportat de un program de calcul tabelar pe un sistem românesc este de obicei separat prin punct și virgulă, iar un `.tsv` nu este întotdeauna separat prin tabulatori.

Prima linie este tratată drept rând de antet și devine titlurile coloanelor.

## Sortare și filtrare

Faceți clic pe antetul unei coloane pentru a sorta după ea, din nou pentru a inversa. Sortarea este **numerică atunci când ambele valori sunt numere** și alfabetică altfel, astfel încât o coloană de dimensiuni pune 9 înainte de 10, nu după.

Câmpul de căutare filtrează pe măsură ce scrieți, fără a ține cont de majuscule. Implicit se uită în toate coloanele; alegeți o coloană din meniul alăturat pentru a căuta doar acolo.

## Ce nu face

Analizorul este intenționat mic, iar o limită merită cunoscută înainte să vă surprindă: **un delimitator aflat într-un câmp între ghilimele este tot tratat ca delimitator.** Un rând precum

```
"Smith, John",42
```

devine trei celule în loc de două. Ghilimelele din jur sunt eliminate când încadrează un câmp întreg, dar dincolo de asta ghilimelele nu sunt interpretate. Pentru un fișier unde asta contează, vizualizatorul integrat sau un program de calcul tabelar este unealta potrivită.

Liniile goale sunt sărite, iar un câmp care se întinde pe mai multe linii nu este acceptat.
