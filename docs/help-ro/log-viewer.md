---
title: Vizualizatorul de jurnale
slug: log-viewer
section: Plugins
order: 128
related: [plugins, viewing-files, searching]
---

Puneți cursorul pe un fișier de jurnal și alegeți **Arată ca jurnal…** pentru a-l deschide într-o fereastră construită pentru jurnale, nu pentru text: un rând pe linie, nivelul fiecărei linii recunoscut și colorat, un filtru și o urmărire care ține pasul cât timp fișierul încă se scrie.

Este o extensie: o puteți dezactiva sau elimina din **Configurare ▸ Extensii…**. Fără ea, F3 arată un jurnal ca pe orice alt fișier text.

## De ce se deschide instantaneu

Fișierul este mapat în memorie și se construiește doar un index cu locul unde începe fiecare linie, în fundal. Nimic nu este încărcat ca text înainte de a fi pe ecran, iar doar liniile efectiv vizibile sunt decodate. Un jurnal de mai mulți gigaocteți se deschide la fel de repede ca unul mic, iar saltul la sfârșit nu citește mijlocul.

## Niveluri și culoare

Fiecare linie este clasificată — **Eroare**, **Avertisment**, **Info**, **Depanare**, **Urmărire** sau **Necunoscut** când formatul nu spune nimic — și colorată în consecință. Culorile implicite urmează aspectul luminos sau întunecat; stabiliți-le pe ale dumneavoastră în configurările extensiei și acelea se vor folosi.

Coloana **Nivel** arată dintr-o privire unde stau erorile, iar câmpul de filtrare restrânge lista la ce căutați. Activați **Regex** pentru a filtra cu o expresie regulată în loc de text simplu.

## Urmărirea unui fișier care încă crește

Activați **Live (derulare automată)** și fereastra urmărește sfârșitul fișierului pe măsură ce sosesc linii noi: indexul este extins peste octeții adăugați în loc să fie reconstruit, așa că rămâne ieftin oricât de lung ar deveni fișierul. Derulați în sus și citiți istoricul; urmărirea continuă dedesubt.

## Orientarea

| | |
| --- | --- |
| **Caută…** | Caută în mesaje; **Caută (marchează și sari)…** marchează fiecare potrivire ca să puteți trece de la una la alta |
| **Mergi la linia…** | Sare la un număr fizic de linie |
| **Mergi la dată/oră…** | Sare la prima linie începând cu un moment de timp, de ex. `2024-01-15 10:23:45` |

Copierea știe ce este o linie de jurnal: **Copiază linia** ia linia de sub cursor, **Copiază intrarea (toate liniile)** ia intrarea întreagă când se întinde pe mai multe linii — o urmă de stivă, de pildă — iar **Copiază liniile selectate** ia exact ce ați selectat.

## Formate

**log4j**, **log4net** și **CSV** sunt integrate, iar formatul este recunoscut automat; fereastra arată pe care s-a oprit. Dacă jurnalele dumneavoastră nu sunt niciunul dintre ele, adăugați-l pe al dumneavoastră la **Formate de jurnal** în configurări: o expresie regulată cu grupuri denumite pentru părțile care contează.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

O linie pe care expresia nu o potrivește apare oricum — este pur și simplu clasificată drept Necunoscut în loc să fie aruncată, fiindcă un jurnal pe care nu îl poți citi este mai rău decât un jurnal fără culori.

## Afișare

**Arată numerele de linie** și **Încadrează liniile lungi** se află în configurări. Zona de detalii de sub listă arată întotdeauna textul complet al intrării selectate, încadrat, orice ar face lista.
