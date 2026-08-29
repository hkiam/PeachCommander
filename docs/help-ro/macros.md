---
title: Macrocomenzi
slug: macros
section: Instrumente avansate
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

O macrocomandă este o secvență cu nume de acțiuni asupra fișierelor — creează un dosar, mută selecția în el, etichetează ce rămâne — pe care o puteți rula din nou cu un clic. Nu este un limbaj de scriptare: nu are condiții și nu are bucle, iar acest lucru este intenționat. O macrocomandă este o listă pe care o puteți citi, iar a o citi este exact ce trebuie să puteți face înainte de a o aproba.

Tot ce face o macrocomandă trece prin aceeași mașinărie pe care o folosește asistentul, așa că o macrocomandă nu poate face nimic ce nu ați permis, fiecare pas al ei apare în jurnalul de acțiuni, iar un pas care poate fi anulat rămâne anulabil.

## Cea mai rapidă cale: din ce ați făcut chiar acum

Nu trebuie să scrieți o macrocomandă de la zero.

1. Faceți lucrul o dată — copiați, mutați, redenumiți sau ștergeți în panouri, sau lăsați asistentul să o facă.
2. Alegeți **Configurare ▸ Macrocomandă din acțiunile recente…**.
3. Bifați pașii pe care macrocomanda trebuie să îi repete, dați-i un nume și lăsați activat **Adaugă și un buton pentru ea**.
4. Bifați **Urmează panourile în locul acestor fișiere anume** dacă macrocomanda trebuie să lucreze data viitoare cu ce va fi selectat atunci. Rândurile se schimbă pe măsură ce bifați, deci vedeți ce salvați.

**Salvează macrocomanda**, și butonul este în bară. Acesta este tot ciclul.

![Foaia „Macrocomandă din acțiuni recente”, cu ce tocmai s-a făcut ca pași bifabili](screenshots/macro-recorder.png)
*Ce s-a întâmplat deja, oferit ca pașii unei macrocomenzi noi.*

Lista le conține pe amândouă: ce ați făcut în panouri (F5, F6, F7, F8 și o redenumire) și ce a făcut asistentul sau altă macrocomandă. Fiecare rând spune care dintre cele două — după o sesiune cu amândouă, aceleași două fișiere pot apărea în fiecare.

> **Ce nu se oferă.** Împachetarea unei arhive, și tot ce aplicația reține doar după nume, nu poate deveni un pas — nu există o formă pentru asta. Astfel de rânduri apar estompate împreună cu motivul, în loc să lipsească, pentru ca o listă de cinci care oferă trei să nu pară că a scăpat două. Iar dacă nu cereți altfel, căile sunt cele care chiar au rulat: o macrocomandă înregistrată repetă *acea* copiere, nu „o copiere de felul acela”. Deschideți-o în editor și puneți `%S` sau `%T` acolo unde vreți să urmeze panourile.

**Urmează panourile** este felul în care cereți altfel. Fișierele venite toate dintr-un singur dosar devin selecția; un dosar care este unul dintre cele două panouri devine acel panou, iar un dosar dinăuntru își păstrează coada — dintr-un „mută aceste patru facturi în Documente/2026-08” înregistrat se face „mută ce este selectat în *2026-08* de partea cealaltă”, iar mâine funcționează în alte două dosare. Ce nu se află sub niciunul dintre panouri rămâne calea care este, fiindcă nu are în ce să fie pliat. Opțiunea apare doar când ar schimba ceva.

## Exemplele livrate

Prima dată când deschideți **Configurare ▸ Editare macrocomenzi…**, fișierul este creat cu opt exemple lucrate. Sunt macrocomenzi obișnuite — modificați-le sau ștergeți-le pe cele nedorite — și fiecare poartă un comentariu care spune ce face și ce se poate schimba în ea:

| Macrocomandă | Ce face |
| --- | --- |
| **Open today's folder** | Creează în panoul activ dosarul cu data de azi și intră în el. Mâine folosește din nou. |
| **File the selection into a dated folder** | Selectează toate PDF-urile, creează în față un dosar an-lună și le mută acolo. |
| **Copy the selection to a dated backup folder** | Copiază ce ați selectat *dumneavoastră* într-un dosar datat de partea cealaltă. |
| **Move the pictures into an Images subfolder** | O mască, un subdosar, în dosarul în care oricum vă aflați. |
| **Merge the CSV files into one and open it** | Arată cum un pas folosește ceea ce a produs un pas anterior. |
| **File the selection into a folder you name** | Vă întreabă dosarul când rulează. |
| **Mark the file under the cursor as reviewed** | Îi pune etichetă și îi datează comentariul — un fișier, nu selecția. |
| **Put the temporary files in the Trash** | O macrocomandă care șterge, și cea potrivită pentru a vedea o dată întrebarea privind drepturile. |

Fiecare dintre ele devine o comandă, așa că puteți pune oricare pe un buton sau pe o tastă fără să scrieți nimic.

## Gestionarea lor

**Configurare ▸ Gestionare macrocomenzi…** este lista: cum se numește fiecare macrocomandă, cum se numește comanda ei, câți pași are și ce va cere verificarea drepturilor — astfel „aceasta șterge” se vede înainte de a o pune pe o tastă. De acolo puteți redenumi, duplica, reordona și șterge. Trecând peste un rând i se văd pașii.

![Fereastra „Gestionare macrocomenzi”, cu numele comenzii, numărul de pași și permisiunea fiecăreia](screenshots/macro-manager.png)
*Cum se numește fiecare macrocomandă, ca ce rulează și pentru ce va cere permisiunea.*

Ordinea nu este decor: ordinea din fișier este aceea în care le listează Navigatorul de comenzi și selectorul barei de butoane.

**La ștergere vi se oferă să luați și butoanele**, iar asta merită știut chiar dacă nu deschideți niciodată această fereastră: o macrocomandă scoasă manual își lasă în urmă butonul și tasta, iar niciunul nu mai face nimic — aplicația spune acum că macrocomanda nu mai există, în loc să tacă, dar butonul rămâne treaba dumneavoastră. O tastă sau o intrare de meniu trebuie scoasă de acolo de unde a fost pusă.

*Pașii* nu se editează aici. **Editare fișier…** predă asta editorului, din același motiv pentru care nu există un formular: un pas este un nume de instrument cu argumentele lui, adică exact ceea ce este JSON.

## Editarea manuală a macrocomenzilor

**Configurare ▸ Editare macrocomenzi…** deschide `macros.json` din dosarul dumneavoastră de configurare, creat prima dată cu exemplele de mai sus. O macrocomandă este o listă de pași, iar fiecare pas numește un instrument și argumentele lui:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Salvarea reîncarcă imediat macrocomenzile — și spune dacă ceva nu este în regulă: un nume de instrument scris greșit, un argument obligatoriu lipsă, două macrocomenzi cu același id. O macrocomandă cu o greșeală nu este rulată și nu ajunge pe niciun buton; aflați care este și ce nu merge la ea, cât timp editorul este încă deschis.

Ce instrumente există și ce primesc vedeți în **Configurare ▸ Navigator de comenzi…**, sau cereți asistentului `list_macros`.

### Substituenți

Literele simple sunt aceleași folosite de bara de butoane și de meniul Start: cine a făcut deja un buton nu are nimic nou de învățat aici.

| Substituent | Înseamnă |
| --- | --- |
| `%P` | Dosarul panoului activ |
| `%T` | Dosarul celuilalt panou |
| `%N` | Fișierul de sub cursor |
| `%S` | Fișierele selectate — o **listă**, exact ce primesc `copy`, `move` și `move_to_trash` |
| `%{date:yyyy-MM}` | Data la care a pornit macrocomanda, în acel format |
| `%{1.destination}` | O valoare numită din rezultatul pasului 1 — aici fișierul pe care l-a scris `merge_files` |
| `%{1}` | Întregul rezultat al pasului 1, când acel pas a produs direct o cale sau o listă de căi |
| `%{ask:Folder name}` | Vă întreabă când rulează macrocomanda. `%{ask:Folder name=Archive}` pornește câmpul cu *Archive* |

Acoladele sunt pentru adaosuri, deoarece literele sunt deja ocupate: `%M` înseamnă „numele de sub cursor în celălalt panou” în tot restul programului, deci o lună nu putea fi scrisă astfel.

Pentru rezultatele pașilor folosiți forma **numită**. Majoritatea instrumentelor raportează mai multe valori în loc de una singură — `merge_files` raportează unde a scris, câte fișiere a unit și câte rânduri au ieșit —, de aceea `%{2.destination}` este scrierea obișnuită, iar un `%{2}` simplu funcționează doar pentru un instrument care întoarce o singură cale. Un nume care nu există, sau care nu este o cale, oprește macrocomanda în loc să fie ghicit.

Un `%` dintr-un nume de fișier este un `%`. Nimic din ce produce un pas și niciun nume luat dintr-un panou nu este citit la rândul lui ca substituent — un fișier numit `50%Netto.pdf` trece deci neschimbat prin macrocomenzi. Pentru un `%` literal într-un șablon scris de *dumneavoastră*, dublați-l: `%%`.

### A cere o valoare

`%{ask:…}` este felul în care o macrocomandă primește ceva ce nu poate ști dinainte — cea mai obișnuită macrocomandă dintre toate este „mută selecția într-un dosar pe care îl numesc eu”, iar fără asta dosarul ar trebui fixat în fișier.

Sunteți întrebat **înainte** ca planul să apară, iar răspunsurile sunt deja în el: rândurile spun „Mută selecția în «Facturi»”, nu „în ce urmează să scrieți”. Anularea întrebării anulează macrocomanda; nimic nu a fost propus, cu atât mai puțin rulat.

Aceeași întrebare scrisă de două ori este pusă o singură dată și folosită în ambele locuri, așa că doi pași care numesc același dosar nu pot să difere. Ce urmează după primul `=` este ceea ce conține câmpul la început. Formularea este a dumneavoastră: se arată exact cum ați scris-o, în limba în care ați scris-o.

Un răspuns este o valoare, niciodată un șablon: dacă tastați `50%Netto`, obțineți un dosar numit `50%Netto`.

O macrocomandă care întreabă nu poate fi rulată de un agent extern prin MCP — acolo nu e nimeni de întrebat, iar a lua în tăcere valorile implicite ar însemna să răspundem în locul dumneavoastră. Este refuzată și o spune.


`%S` este singurul loc în care o macrocomandă diferă de un buton: pe un buton selecția devine o listă de cuvinte pentru o linie de comandă, aici devine lista de căi complete pe care le primesc instrumentele de fișiere.

Un pas al cărui `%S` sau `%{1}` iese **gol oprește macrocomanda**, în loc să ruleze fără nimic. Un `move` fără fișiere nu este un `move` mai mic — este o cerere care nu mai spune nimic, iar a raporta succes ar fi o minciună.

## Rularea unei macrocomenzi

Fiecare macrocomandă devine o comandă numită `mc_<id>` și apare astfel de la sine în:

- **Configurare ▸ Explorator de comenzi…**
- **Configurare ▸ Editează scurtăturile… — puneți-o pe o tastă**
- Selectorul de comenzi din editorul barei de butoane
- Fișierul dumneavoastră de meniu `.mnu` și `usercmd.ini`, dacă le folosiți
- Asistentul, care o poate rula după nume

Înainte ca o macrocomandă care schimbă ceva să ruleze, vă arată pașii ca listă și așteaptă. Puteți tăia un pas pe care nu îl doriți; ce rămâne este ce rulează. O macrocomandă care doar citește rulează fără să întrebe. **Tăierea unui pas îi ia cu el pe cei care depind de el** — o macrocomandă este o secvență, iar pasul care umple dosarul nu poate rula fără pasul care îl creează: acele rânduri se dezactivează singure și devin gri. Puneți pasul la loc și revin — în afară de cele pe care le-ați tăiat dumneavoastră; acelea rămân tăiate.

![Dialogul de confirmare al macrocomenzii, fiecare pas o casetă care numește fișierele](screenshots/macro-confirm.png)
*Pașii, rezolvați pe panourile dumneavoastră — fiecare poate fi tăiat.*

Tot ce se poate vedea că este greșit înainte de pornire — un instrument care nu există, un argument lipsă, un pas care ar rula altă macrocomandă — o oprește înainte de primul pas, nu după al treilea. Dacă un pas eșuează în timpul rulării, macrocomanda **se oprește acolo** în loc să continue: pasul doi presupune de regulă că pasul unu a avut loc, iar mutarea fișierelor într-un dosar care nu a fost creat nu este un succes parțial. Raportul numește pasul, spune ce a mers prost și câți pași fuseseră deja executați; fiecare dintre ei se află în jurnalul de acțiuni, cu drumul său înapoi acolo unde există unul.
## Ce îi este permis unei macrocomenzi

O macrocomandă este judecată după cel mai pretențios lucru din ea. O macrocomandă ai cărei pași doar citesc este tratată ca o citire; una care se termină cu o ștergere definitivă este controlată ca o ștergere definitivă — înainte să ruleze orice, nu patru pași mai târziu.

Un pas care rulează o *comandă* este judecat după ce face acea comandă, nu după faptul că este o comandă — o macrocomandă care rulează `cm_DeleteReal` este deci o macrocomandă care șterge și vă este arătată ca atare. O macrocomandă nu poate rula altă macrocomandă, în niciuna dintre cele două scrieri.

A nu acorda nimic în plus este comportamentul implicit. Dacă o macrocomandă conține un pas pe care permisiunile dumneavoastră nu îl admit — o comandă shell, un script — întreaga macrocomandă este refuzată cu motivul, și nu se întâmplă nimic.

## Anulare

Fiecare pas este jurnalizat separat, deci **anulează** după o macrocomandă recuperează *ultimul* ei pas, nu întreaga macrocomandă. Nu există o anulare a întregii macrocomenzi, deoarece mai multe instrumente nu au niciun invers, iar un buton care ar oferi-o ar minți despre acelea.

## Unde se salvează totul

- Macrocomenzile dumneavoastră sunt în `macros.json` din dosarul de configurare — un fișier simplu, pe care îl puteți compara și păstra cu dotfiles.
- Butoanele adăugate de o macrocomandă sunt intrări obișnuite ale barei de butoane din `default.bar`, deci a elimina unul este la fel ca la orice alt buton.

## Pașii următori

- [Automatizare (AppleScript și Scurtături)](automation.md) — Controlul Peach Commander dintr-un script și rularea propriilor scripturi ca pas de macrocomandă.
- [Bara de butoane](toolbar.md) — Unde ajunge butonul adăugat de o macrocomandă.
- [Tastatură și scurtături](keyboard-shortcuts.md) — Punerea unei macrocomenzi pe o tastă.
