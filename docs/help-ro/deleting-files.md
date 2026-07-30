---
title: Ștergerea fișierelor
slug: deleting-files
section: Fișiere și foldere
order: 28
related: [copying-files]
---

Când nu mai aveți nevoie de fișiere sau foldere, Peach Commander le poate muta în Coșul de gunoi, ca să le puteți recupera mai târziu, sau le poate șterge definitiv pentru a recupera imediat spațiu. Ștergerile acționează asupra selecției curente din panoul activ; dacă nu este marcat nimic, se șterge elementul de sub cursor.

## Cum se șterg fișierele

1. În panoul activ, marcați fișierele și folderele pe care doriți să le eliminați. Dacă nu marcați nimic, se folosește elementul de sub cursor.
2. Apăsați **F8** (sau tasta **Delete**) pentru a muta selecția în Coșul de gunoi. Pentru a alege din meniu, folosiți **Fișier > Ștergere**.
3. Dacă apare o confirmare, examinați lista de elemente și faceți clic pe **Ștergere** pentru a continua sau pe **Anulare** pentru a opri.

Elementele trimise în Coșul de gunoi rămân acolo până când îl goliți, așa că le puteți restaura din Finder dacă vă răzgândiți.

## Cum se șterge definitiv

1. Marcați fișierele și folderele de eliminat.
2. Apăsați **Shift+F8** sau alegeți **Fișier > Ștergere definitivă**.
3. Confirmați ștergerea. Aceasta ocolește Coșul de gunoi, așa că elementele dispar imediat și nu pot fi recuperate.

Dacă unele elemente nu pot fi eliminate — de exemplu pentru că sunt blocate sau nu aveți permisiune — Peach Commander vă spune care dintre ele au eșuat și vă permite să reîncercați sau să le omiteți și să continuați cu restul.

## Scurtături

| Acțiune | Scurtătură |
| --- | --- |
| Ștergeți la Coșul de gunoi | F8 sau Delete |
| Ștergeți definitiv | Shift+F8 |

## Note

- **Confirmare.** În mod implicit, Peach Commander vă cere să confirmați înainte de a șterge. Puteți dezactiva aceasta în **Configurare > Confirmare** debifând **Confirmă înainte de ștergere**. Chiar și așa, tratați ștergerile definitive cu grijă, deoarece nu pot fi anulate.
- **Comportamentul implicit al lui F8.** În mod normal, F8 mută elementele în Coșul de gunoi. Dacă preferați ca F8 să șteargă definitiv în mod implicit, modificați opțiunea de ștergere din setările **Configurare > Operație**. Shift+F8 șterge întotdeauna definitiv, indiferent de această setare.
- **Ștergerea în interiorul arhivelor.** Când navigați în interiorul unei arhive acceptate, ștergerea elimină intrările selectate din arhivă. Locațiile doar-citire, cum ar fi unele foldere de rețea sau de plugin, nu pot fi modificate în acest fel.
- **Foldere.** Ștergerea unui folder elimină tot ce se află în el. Asigurați-vă că ați selectat elementele corecte înainte de a confirma, mai ales pentru o ștergere definitivă.
