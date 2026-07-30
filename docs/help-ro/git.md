---
title: Git
slug: git
section: Pluginuri
order: 123
related: [plugins, view-modes-and-sorting]
---

Pluginul Git aduce starea unui depozit Git direct în panoul de fișiere — fără o aplicație separată, fără terminal. Adaugă două coloane care arată starea din arborele de lucru a fiecărui fișier și ramura curentă, un submeniu **Git** pentru comenzile de zi cu zi (status, pregătire, commit, pull, push), și folosește `git`-ul deja instalat pe Mac-ul dvs. Fiind un plugin, îl puteți dezactiva sau elimina din **Configurare ▸ Pluginuri…**.

## Ce adaugă

- **Două coloane în lista de fișiere** — *Git Status* și *Branch*. Într-un depozit, fiecare fișier arată un cuvânt de stare scurt (Modificat, Adăugat, Șters, Neurmărit, Redenumit, Copiat, Conflict, Ignorat sau Schimbat), iar panoul arată ramura curentă. Activați coloanele în **Configurare ▸ Coloane…** (vedeți [Moduri de vizualizare și sortare](view-modes-and-sorting.md)).
- **Un meniu Git** — în **Comenzi ▸ Git**, și în meniul cu clic dreapta al unui fișier, cu: **Git Status…**, **Git Add (pregătire)**, **Git Commit…**, **Git Pull** și **Git Push**.

![Dialogul Git Status care arată ramura curentă și fișierele modificate din depozit](screenshots/git-status.png)
*(Figura: Git Status raportează ramura și fiecare modificare din arborele de lucru.)*

## Verificarea stării

1. Puneți cursorul pe un fișier sau folder din interiorul unui depozit Git.
2. Alegeți **Comenzi ▸ Git ▸ Git Status…** (sau clic dreapta ▸ **Git ▸ Git Status…**).
3. Apare un rezumat: ramura curentă (sau *(detașat)*), apoi fie *Arbore de lucru curat.*, fie o listă de modificări, fiecare linie arătând starea și calea fișierului.

Dacă cursorul nu este în interiorul unui depozit, pluginul spune pur și simplu *Nu este un depozit Git.*

## Pregătire, commit, pull, push

- **Git Add (pregătire)** pregătește fișierul de sub cursor (`git add`).
- **Git Commit…** cere un mesaj de commit, apoi înregistrează toate modificările (`git commit -a`). Ieșirea combinată este afișată, astfel încât să vedeți exact ce s-a întâmplat.
- **Git Pull** face un pull doar de tip fast-forward (`git pull --ff-only`).
- **Git Push** trimite ramura curentă (`git push`).

După o comandă care modifică depozitul, panoul activ se reîmprospătează, astfel încât coloanele de stare rămân actuale.

## Note

- Pluginul folosește Git-ul de sistem de la `/usr/bin/git`. Dacă Git nu este instalat, comenzile raportează că Git nu este disponibil. (Instalarea Xcode Command Line Tools îl furnizează.)
- Starea depozitului este citită o singură dată pentru fiecare folder și memorată în cache, astfel încât parcurgerea unui depozit mare rămâne rapidă; cache-ul se reîmprospătează după orice comandă care modifică arborele.
- Commit folosește `git commit -a`, care înregistrează modificările urmărite; fișierele complet noi tot au nevoie mai întâi de **Git Add (pregătire)**.
- Antetele coloanelor *Git Status* și *Branch* apar deocamdată în engleză chiar și în alte limbi ale interfeței; valorile și dialogurile sunt localizate.
