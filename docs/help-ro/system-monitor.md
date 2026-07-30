---
title: System Monitor
slug: system-monitor
section: Pluginuri
order: 124
related: [plugins, settings]
---

Pluginul System Monitor afișează o citire în timp real a activității Mac-ului dvs. direct în bara de titlu a ferestrei: jetoane mici pentru procesor, memorie, disc, rețea și — acolo unde hardware-ul le expune — GPU, baterie și senzori. Fiecare jeton se actualizează o dată pe secundă; faceți clic pe unul pentru un pop-up cu un grafic de istoric și o defalcare detaliată. Fiind un plugin, îl puteți activa, configura sau elimina din **Configurare ▸ Pluginuri…**.

## Jetoanele din bara de titlu

Când pluginul este activat, un rând de jetoane compacte se află în bara de titlu. Fiecare jeton este un punct colorat, o etichetă scurtă și o valoare în timp real (unele cu o sparkline încorporată):

| Jeton | Arată |
| --- | --- |
| **CPU** | Încărcarea procesorului, cu detaliu pe nucleu |
| **RAM** | Memorie folosită / totală (plus cablată, comprimată, swap) |
| **HDD** | Spațiul volumului de pornire și debitul de citire/scriere |
| **Net** | Rate și totaluri de descărcare / încărcare |
| **GPU** · **Batt** · **Sens** | Utilizarea GPU · încărcarea și starea bateriei · vitezele ventilatoarelor și temperaturile |

Faceți clic pe un jeton pentru a deschide un pop-up cu valoarea curentă mare, o sparkline **HISTORY**, o listă cheie/valoare **DETAILS** și — pentru procesor — o listă **CORE LOAD** cu bare pe nucleu.

## Configurarea

Alegeți **Comenzi ▸ System Monitor…** (sau deschideți **Configurare ▸ Setări ▸ System Monitor**) pentru a configura citirea:

- **Arată monitorul de sistem în bara de titlu** — comutatorul principal de pornire/oprire pentru jetoane.
- **Profil** — presetările *Minimal*, *Mediu* sau *Maximal* care aleg un set rezonabil de module.
- **Tabelul de module** — activați sau dezactivați fiecare modul (CPU, GPU, RAM, HDD, Net, Batt, Sens), alegeți-i culoarea și trageți rândurile pentru a stabili ordinea în care apar în bara de titlu. Modulele pe care hardware-ul dvs. nu le poate raporta sunt afișate ca *(n/a)*.

![Setările System Monitor cu tabelul de module, profilurile și culorile pe modul](screenshots/system-monitor.png)
*(Figura: alegeți ce module apar, culorile lor și ordinea lor.)*

## Note

- Totul este măsurat, niciodată falsificat: modulele ale căror date hardware-ul nu le expune (adesea GPU sau senzorii pe unele Mac-uri) rămân indisponibile în loc să arate numere inventate. Bateria este indisponibilă pe desktopuri.
- Eșantionarea rulează pe un temporizator de fundal doar cât timp citirea este vizibilă și păstrează aproximativ 30 de minute de istoric pentru grafice.
- Alegerile dvs. de module, culorile și ordinea sunt salvate împreună cu configurația aplicației.
