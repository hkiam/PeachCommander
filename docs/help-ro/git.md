---
title: Git
slug: git
section: Pluginuri
order: 123
related: [plugins, view-modes-and-sorting]
---

Pluginul Git arată starea unui depozit Git direct în panoul de fișiere — fără o aplicație separată și fără
terminal. Adaugă două coloane, un submeniu **Git**, un panou andocat pentru pregătire și comitere și ferestre
pentru istoric, blame, ramuri, conflicte și rebazare. Folosește `git`-ul deja instalat pe Mac-ul
dumneavoastră. Este un plugin, deci îl puteți dezactiva sau elimina din **Configurare ▸ Pluginuri…**.

## Ce adaugă

- **Două coloane în lista de fișiere** — *Stare Git* și *Ramură*. Fiecare fișier arată o pictogramă și un
  cuvânt scurt de stare (Modificat, Adăugat, Șters, Neurmărit, Redenumit, Copiat, Conflict, Ignorat, Tip
  schimbat), cu *(pregătit)* când modificarea este deja în index; coloana *Ramură* arată ramura pe care se
  află depozitul acelui fișier. Activați coloanele din **Configurare ▸ Coloane…** (vedeți
  [Moduri de vizualizare și sortare](view-modes-and-sorting.md)).
- **Un meniu Git** — sub **Comenzi ▸ Git** și în meniul contextual al unui fișier.

![Fereastra Stare Git cu ramura curentă și fișierele modificate din depozit](screenshots/git-status.png)
*(Figură: Starea Git indică ramura și fiecare modificare din arborele de lucru.)*

## Panoul: pregătire, comitere, sincronizare

**Comenzi ▸ Git ▸ Panou** andochează o vedere care grupează arborele de lucru în *pregătit*, *modificat* și
*neurmărit*. Selectați fișiere și folosiți **Pregătește**, **Retrage din pregătire** sau **Renunță…**,
scrieți un mesaj și apăsați **Comite** — cu **Amendează**, modificarea este pliată în comiterea precedentă.
**Trage** și **Împinge** sunt alături, acolo unde comiterea are loc oricum; ambele arată progresul și pot fi
anulate.

Se comite *indexul*, nu `git commit -a`: ce ați pregătit este ce se comite.

## Istoric, blame și web

- **Istoric…** listează comiterile cu un grafic pe benzi, referințele care indică spre fiecare (`● main`,
  `↗ origin/main`, `⚑ v1.0`) și fișierele atinse de fiecare comitere. Return sau un dublu clic deschide
  versiunea acelui fișier față de predecesoarea ei în fereastra de comparare. **Anulează comiterea** și
  **Cherry-pick** sunt acolo, și ambele refuză din start dacă arborele de lucru nu este curat.
- **Istoricul fișierului…** este aceeași fereastră pentru un singur fișier.
- **Blame (listă)…** arată fiecare linie cu comiterea, autorul și data ei. **Blame în editor** scrie aceeași
  informație pe marginea editorului, lângă numerele de linie: treceți peste o linie pentru mesajul comiterii,
  faceți clic pentru a o deschide față de predecesoarea ei.
- **Deschide pe web** deschide fișierul, comiterea sau ramura pe GitHub, GitLab, Bitbucket sau Azure DevOps,
  construit din URL-ul depozitului la distanță — fără cont, fără jeton. Pentru o gazdă a cărei formă a
  legăturilor nu o cunoaște, oferă pagina depozitului în loc să ghicească.

## Ramuri, stive și etichete

**Ramuri, stive și etichete…** le listează pe toate trei. Comutarea, crearea, îmbinarea sau ștergerea unei
ramuri; împingerea, scoaterea sau aruncarea unei stive; crearea, ștergerea sau împingerea unei etichete ori
comutarea pe ea — o etichetă nu este o ramură, așa că se spune din start că HEAD va rămâne detașat. Aducerea,
Trage și Împinge sunt în aceeași fereastră și pot fi anulate în timpul rulării.

Împingerea unei etichete este intenționat o acțiune separată: `git push` nu duce etichetele cu el.

## Conflicte

**Rezolvă conflictul…** listează regiunile în conflict ale fișierului de sub cursor și ia o decizie pentru
fiecare: *ale noastre*, *ale lor*, *ambele* — sau lasă deschis. Apoi **Scrie fișierul** sau **Scrie și
pregătește**. Refuză pregătirea cât timp o regiune rămâne deschisă — Git ar comite fără ezitare marcajele
`<<<<<<<` — și refuză să atingă un fișier ale cărui marcaje nu le poate citi, în loc să le ghicească. Pentru o
regiune care cere împletirea manuală a ambelor părți, **Deschide în editor** este la un buton distanță.

## Rebazare

**Rebazează…** listează comiterile aflate înaintea ramurii din amonte — cele pe care nimeni altcineva nu le
are încă — și vă lasă să le comprimați, să le atașați ca reparație, să le aruncați, să le reordonați sau să le
reformulați înainte ca ramura să fie rescrisă. Dacă o rebazare se oprește într-un conflict, aceeași fereastră
devine **Continuă** / **Sari peste comitere** / **Abandonează**, astfel încât o rebazare pe jumătate făcută nu
trebuie încheiată într-un terminal.

## Ignorarea fișierelor și datele de autentificare

- **Ignoră acest fișier…**, **Ignoră acest tip de fișier…** și **Ignoră acest dosar…** adaugă tiparul potrivit
  în `.gitignore` — ancorat unde trebuie, astfel încât ignorarea *acestui* dosar `build` să nu ignore orice
  dosar numit `build`.
- **Date de autentificare…** raportează cum se autentifică acest depozit: SSH sau HTTPS, dacă este configurat
  un asistent de acreditări, dacă rulează un agent SSH care ține o cheie. Unde ajută, oferă exact o acțiune —
  să lase Git să păstreze datele în brelocul macOS. Pluginul nu cere niciodată o frază de acces, nu o afișează
  și nu o păstrează.

## Observații

- Pluginul folosește Git-ul sistemului, de la `/usr/bin/git`. Dacă Git lipsește, comenzile raportează că Git
  nu este disponibil. (Xcode Command Line Tools îl aduc.)
- Starea depozitului este citită o dată per dosar și păstrată în cache, astfel încât derularea într-un depozit
  mare rămâne rapidă; cache-ul se reîmprospătează după orice comandă care schimbă arborele și urmărește și o
  comitere făcută în afara aplicației.
- Arborii de lucru legați și submodulele sunt acceptate: un fișier dintr-un submodul arată starea și ramura
  *submodulului*, nu pe cele ale depozitului părinte.
- Fiecare listă are meniu contextual, **Return** rulează acțiunea principală și **Cmd+R** reîncarcă fereastra.
