---
title: System Monitor
slug: system-monitor
section: Zásuvné moduly
order: 124
related: [plugins, settings]
---

Zásuvný modul System Monitor umístí živý přehled aktivity vašeho Macu přímo do záhlaví okna: malé čipy pro procesor, paměť, disk, síť a — tam, kde to hardware zpřístupňuje — GPU, baterii a senzory. Každý čip se aktualizuje jednou za sekundu; kliknutím na některý zobrazíte vyskakovací okno s grafem historie a podrobným rozpisem. Je to zásuvný modul, takže jej můžete povolit, nakonfigurovat nebo odebrat v nabídce **Konfigurace ▸ Zásuvné moduly…**.

## Čipy v záhlaví

Když je zásuvný modul zapnutý, v záhlaví okna sedí řada kompaktních čipů. Každý čip tvoří barevná tečka, krátký popisek a živá hodnota (některé s vloženou minigrafikou sparkline):

| Čip | Ukazuje |
| --- | --- |
| **CPU** | Zatížení procesoru, s podrobností po jádrech |
| **RAM** | Použitá / celková paměť (plus wired, komprimovaná, swap) |
| **HDD** | Místo na spouštěcím svazku a propustnost čtení/zápisu |
| **Net** | Rychlosti a celkové objemy stahování / odesílání |
| **GPU** · **Batt** · **Sens** | Využití GPU · nabití a stav baterie · otáčky ventilátorů a teploty |

Kliknutím na čip otevřete vyskakovací okno s velkou aktuální hodnotou, sparkline **HISTORY**, seznamem klíč/hodnota **DETAILS** a — u procesoru — seznamem **CORE LOAD** s pruhy pro jednotlivá jádra.

## Konfigurace

Zvolte **Příkazy ▸ System Monitor…** (nebo otevřete **Konfigurace ▸ Nastavení ▸ System Monitor**) ke konfiguraci přehledu:

- **Zobrazit systémový monitor v záhlaví** — hlavní vypínač čipů.
- **Profil** — předvolby *Minimal*, *Medium* nebo *Maximal*, které vyberou rozumnou sadu modulů.
- **Tabulka modulů** — každý modul (CPU, GPU, RAM, HDD, Net, Batt, Sens) zapnete nebo vypnete, zvolíte mu barvu a přetažením řádků nastavíte pořadí, v jakém se objeví v záhlaví. Moduly, které váš hardware neumí hlásit, se zobrazují jako *(n/a)*.

![Nastavení System Monitoru s tabulkou modulů, profily a barvami jednotlivých modulů](screenshots/system-monitor.png)
*(Obrázek: zvolte, které moduly se objeví, jejich barvy a jejich pořadí.)*

## Poznámky

- Vše je měřeno, nikdy předstíráno: moduly, jejichž data hardware nezpřístupňuje (často GPU nebo senzory na některých Macích), zůstávají nedostupné, místo aby zobrazovaly vymyšlená čísla. Baterie je na stolních počítačích nedostupná.
- Vzorkování běží na časovači na pozadí jen tehdy, když je přehled viditelný, a pro grafy uchovává zhruba 30 minut historie.
- Vaše volby modulů, barvy a pořadí se ukládají s konfigurací aplikace.
