---
title: System Monitor
slug: system-monitor
section: Bővítmények
order: 124
related: [plugins, settings]
---

A System Monitor bővítmény a Mac tevékenységének valós idejű kijelzését helyezi közvetlenül az ablak címsorába: kis chipek a processzorhoz, memóriához, lemezhez, hálózathoz, és — ahol a hardver közzéteszi őket — GPU-hoz, akkumulátorhoz és érzékelőkhöz. Minden chip másodpercenként egyszer frissül; kattintson egyre egy előugró ablakért, amely egy előzménygrafikont és részletes bontást mutat. Mivel bővítményről van szó, a **Konfiguráció ▸ Bővítmények…** menüpontból engedélyezheti, konfigurálhatja vagy eltávolíthatja.

## A címsor chipjei

Amikor a bővítmény be van kapcsolva, kompakt chipek sora ül a címsorban. Minden chip egy színes pontból, egy rövid feliratból és egy élő értékből áll (némelyik beágyazott sparkline-nal):

| Chip | Mit mutat |
| --- | --- |
| **CPU** | Processzorterhelés, magonkénti részletezéssel |
| **RAM** | Használt / teljes memória (plusz drótozott, tömörített, swap) |
| **HDD** | Az indítókötet helye és olvasási/írási átvitele |
| **Net** | Letöltési / feltöltési sebesség és összegek |
| **GPU** · **Batt** · **Sens** | GPU-kihasználtság · akkumulátortöltés és -állapot · ventilátorfordulatszámok és hőmérsékletek |

Kattintson egy chipre egy előugró ablak megnyitásához, amelyben a nagy aktuális érték, egy **HISTORY** sparkline, egy **DETAILS** kulcs/érték lista, és — a CPU esetében — egy **CORE LOAD** lista magonkénti sávokkal található.

## Konfigurálás

Válassza a **Parancsok ▸ System Monitor…** lehetőséget (vagy nyissa meg a **Konfiguráció ▸ Beállítások ▸ System Monitor** oldalt) a kijelzés konfigurálásához:

- **Rendszermonitor megjelenítése a címsorban** — a chipek fő be/ki kapcsolója.
- **Profil** — *Minimális*, *Közepes* vagy *Maximális* előbeállítások, amelyek a modulok ésszerű készletét választják ki.
- **A modultábla** — kapcsolja be vagy ki az egyes modulokat (CPU, GPU, RAM, HDD, Net, Batt, Sens), válassza ki a színüket, és húzza a sorokat, hogy beállítsa a címsorban való megjelenésük sorrendjét. Azok a modulok, amelyeket a hardver nem tud jelenteni, *(n/a)* jelöléssel jelennek meg.

![A System Monitor beállításai a modultáblával, a profilokkal és a modulonkénti színekkel](screenshots/system-monitor.png)
*(Ábra: válassza ki, mely modulok jelenjenek meg, a színeiket és a sorrendjüket.)*

## Megjegyzések

- Minden mért, sosem koholt: azok a modulok, amelyek adatait a hardver nem teszi közzé (gyakran a GPU vagy az érzékelők egyes Maceken), inkább elérhetetlenek maradnak, mintsem kitalált számokat mutassanak. Asztali gépeken az akkumulátor nem érhető el.
- A mintavétel csak egy háttéridőzítőn fut, amíg a kijelzés látható, és körülbelül 30 percnyi előzményt tart meg a grafikonokhoz.
- A modulválasztásai, színei és sorrendje az app konfigurációjával együtt mentődnek.
