---
title: Spații de lucru
slug: workspaces
section: Personalizare
order: 118
related: [settings, panels-and-tabs]
---

Un spațiu de lucru este un context cu nume în care lucrați: „Curățarea copiilor de siguranță”, „Sortarea dosarelor de candidatură”. Fiecare reține ambele panouri, toate filele deschise, care filă este activă pe fiecare parte, modul de vizualizare, arborele de dosare, istoricul înainte/înapoi și ce fișiere aveați marcate, filtrul rapid și aranjamentul ferestrei — panoul lateral, doc-ul, barele și poziția separatorului. Comutarea costă un clic, iar pe drum nu se pierde niciodată nimic — un spațiu de lucru nu este salvat niciodată, pentru că nu se termină niciodată.

Până când creați un al doilea, nu este nimic de văzut. Nicio bară, niciun meniu, nicio scurtătură.

## Cum se procedează

1. Pregătiți ambele panouri pentru sarcina de față: deschideți dosarele, adăugați filele, alegeți vizualizarea dorită.
2. Deschideți meniul **Mergi** și alegeți **Spații de lucru…**, apoi **Spațiu de lucru nou…**. Dați-i un nume.
3. În partea de sus a ferestrei apare o bandă de pastile colorate, iar în bara de meniu apare meniul **Spațiu de lucru**. Noul spațiu de lucru pornește ca o copie a aranjamentului în care vă aflați.
4. Pregătiți noul spațiu de lucru pentru sarcina lui. Cel din care ați venit păstrează ce avea.
5. Faceți clic pe o pastilă pentru a comuta sau apăsați **Ctrl+1** până la **Ctrl+9**. Totul comută odată cu el.

## Înapoi la un punct de pornire

Fiecare spațiu de lucru reține și aranjamentul cu care a fost configurat. **Spațiu de lucru ▸ Salvează starea curentă în spațiul de lucru** (Cmd+Ctrl+S) face din aranjamentul curent acel punct de pornire, iar **Revino la starea salvată** vă duce înapoi acolo după o după-amiază de rătăciri.

Acest lucru este separat de memorarea continuă: nu trebuie niciodată să salvați pentru a nu vă pierde locul.

## Coșul

Fiecare spațiu de lucru are un coș — pentru ceea ce se întâmplă cu adevărat în timpul curățeniei: la
trei dosare adâncime în copiile de siguranță găsiți ceva care ține de o cu totul altă treabă.
**Trageți fișiere pe pastila altui spațiu de lucru** și vor ateriza în coșul *acestuia*: nu comutați,
și nimic nu este copiat sau mutat; contorul de pe pastilă crește și continuați. Țineți **⌥** la
plasare pentru a copia în dosarul acelui spațiu, sau **⌘** pentru a muta. **Ctrl+Cmd+A** pune selecția
în coșul spațiului curent, pagina **Coș** din panoul lateral arată conținutul, iar **Spațiu de lucru ▸
Copiază coșul în celălalt panou** rezolvă tot coșul într-o singură operațiune.

Fișierele șterse între timp, sau aflate pe un volum nemontat, sunt afișate ca lipsă în loc să fie
eliminate, iar o operațiune în masă oferă să le sară sau să le scoată mai întâi. O mutare golește coșul
de ce a mutat; o copiere îl lasă cum era.

| Acțiune | Scurtătură |
| --- | --- |
| Comutare la spațiul de lucru 1 până la 9 | Ctrl+1 … Ctrl+9 |
| Transformarea aranjamentului curent în punct de pornire | Cmd+Ctrl+S |

## Sfaturi

- Faceți clic dreapta pe o pastilă pentru a o redenumi, a-i da o culoare sau a o șterge — sau faceți clic pe **✕** de la capătul ei din dreapta, care șterge spațiul de lucru după o întrebare. Culoarea este ceea ce vă permite să deosebiți spațiile de lucru dintr-o privire când fereastra este îngustă și numele nu mai încap.
- Nouă este limita, astfel încât fiecare pastilă să rămână recognoscibilă.
- **Vizualizare ▸ Afișează bara spațiilor de lucru** ascunde banda fără a dezactiva funcția, pentru cine trece de la un spațiu la altul cu tastatura.
- Spațiile de lucru pot fi dezactivate complet în **Setări ▸ File**. Spațiile dumneavoastră de lucru sunt păstrate și revin neschimbate când reactivați funcția.

## Limitarea unui spațiu de lucru la un dosar

Unui spațiu de lucru i se poate spune despre ce este vorba, iar apoi verifică înainte ca o operațiune să
ajungă în afară. Clic dreapta pe pastila lui, **Limitează la un dosar ▸ Setează la dosarul activ**, și
alegeți dacă operațiunile din afară sunt permise, întrebate sau refuzate.

Se verifică înainte ca o ștergere să ia fișiere din afară, înainte ca o copiere sau o mutare să
aterizeze în afară și înainte ca o redenumire sau un dosar nou să scrie în afară. **Navigarea nu este
niciodată restricționată** — un manager de fișiere care refuză să arate un dosar este stricat, iar toată
valoarea stă în clipa dinaintea lui F8. Nici salvările din editor nu sunt acoperite; ele se petrec în
propria fereastră.

## Jurnalul

Fiecare spațiu de lucru ține evidența a ceea ce s-a făcut în el — dosare vizitate, operațiuni
efectuate, linii de shell tastate și tot ce a refuzat o limită de dosar. **Spațiu de lucru ▸ Jurnal…**
îl afișează, cu ziua cea mai recentă prima, și un filtru **Probleme** pentru tot ce a eșuat sau a fost
oprit.

Return repetă rândul selectat, după aceeași regulă ca istoricul: doar o copiere sau o mutare se repetă
cu o apăsare, iar o linie de shell este completată în linia de comandă în loc să fie rulată. Jurnalul
este separat intenționat de istoricul global — acela răspunde la „unde merg de obicei” și ordonează după
frecvență; acesta răspunde la „ce s-a întâmplat aici” și păstrează ordinea. Se șterge odată cu spațiul
său de lucru, se păstrează altfel nelimitat și poate fi dezactivat în **Setări ▸ File**.

## Transmiterea unui spațiu de lucru

**Spațiu de lucru ▸ Exportă spațiul de lucru…** scrie spațiul de lucru curent într-un fișier
`.pcworkspace` pe care îl puteți trimite cuiva sau păstra într-un dosar de proiect. **Importă un
spațiu de lucru…** îl citește înapoi, la fel și un dublu clic în Finder.

Ce călătorește este **punctul de pornire salvat** al spațiului de lucru — apăsați întâi ⌘⌃S dacă
vreți aranjarea pe care o aveți în față — împreună cu numele, culoarea, limita de dosar și coșul.
Dosarele din dosarul dumneavoastră personal se scriu prescurtat, ca fișierul să se deschidă în
dosarul personal al *celuilalt* și nu într-un dosar numit după dumneavoastră.

Ce nu călătorește, în mod deliberat:

- **Orice ar putea fi o credențială.** Filele care indică o conexiune sau o unitate de plugin montată sunt eliminate la export, iar raportul spune câte. Nu e nimic de pierdut, fiindcă despre o conexiune nu se scrie nimic.
- **Jurnalul.** Consemnează ce ați făcut *dumneavoastră* și numește dosare de pe mașina dumneavoastră. Rămâne aici.
- Pozițiile cursorului, istoricul de anulare, dimensiunea ferestrei și ferestrele deschise de vizualizare, editare, căutare sau sincronizare.
- Filele terminalului și conversațiile cu asistentul. Acestea țin de acest Mac; un fișier de spațiu de lucru poartă *unde* se lucrează, nu ce rulează.

Un import **adaugă** întotdeauna un spațiu de lucru; nu îl înlocuiește niciodată pe cel în care vă
aflați și nu comută niciodată de la sine — un fișier trimis de cineva nu trebuie să vă mute
fereastra. Dosarele care nu există pe acest Mac se deschid la cel mai apropiat care există, elementele
din coș își păstrează căile și apar estompate, iar o limită de dosar al cărei dosar lipsește este
păstrată, dar întreabă în loc să refuze. Un raport le enumeră pe toate.

## Observații

- Comutarea nu întreabă niciodată dacă să salveze și nu închide niciodată nimic. Operațiunile cu fișiere în curs continuă, la fel și tot ce rulează într-un terminal: filele spațiului pe care îl părăsiți sunt puse deoparte cu shell-urile lor vii, nu închise. Și conversațiile asistentului urmează spațiul de lucru.
- Anularea urmează un spațiu de lucru doar cât timp aplicația rulează: un pas de anulare poartă acțiunea care îl inversează, iar aceasta nu poate fi scrisă pe disc.
- Un spațiu de lucru reține locații de dosare, nu fișierele din ele. Dacă un dosar salvat a fost mutat sau șters, fila respectivă se deschide în cel mai apropiat dosar care încă există.
- La actualizarea de la o versiune anterioară: spațiile de lucru pe care le salvaserăți devin pastile, iar sesiunea în care vă aflați devine primul. Nu se pierde nimic, iar vechiul `workspaces.ini` este păstrat ca `workspaces.ini.migrated`.
