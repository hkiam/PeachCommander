---
title: MI-asszisztens
slug: ai-assistant
section: Bővítmények
order: 122
related: [plugins, settings, privacy-and-security]
---

Az MI-asszisztens egy opcionális, eltávolítható bővítmény, amely segít abban, hogy hétköznapi nyelven dolgozhasson a fájljaival. Össze tud foglalni vagy elmagyarázni egy dokumentumot, jobb fájlnevet javasolhat, szöveget fordíthat vagy korrektúrázhat, adatokat táblázattá alakíthat, sőt egy mappát is rendszerezhet – és fájlműveleteket is végrehajthat Ön helyett, miután először bemutatott egy tervet. Két bővítményből áll: az **AI On-Device** az Apple Intelligence-t használja, és azokat a műveleteket adja, amelyek javaslatot mutatnak és alkalmazzák, míg az **AI Assistant** a csevegés, amelyhez felhőmodell kell. Kapcsolja be bármelyiket, vagy mindkettőt. Mivel bővítményről van szó, teljesen letilthatja vagy eltávolíthatja a **Beállítások ▸ Bővítmények…** menüpontból.

## Az asszisztens megnyitása

Válassza a **Parancsok ▸ MI-asszisztens** menüpontot, hogy az asszisztens megjelenjen egy dokkolt panelen az ablak jobb oldalán. Írjon be egy kérést, és nyomja meg a Return billentyűt; az asszisztens fájlokat olvashat, információkat kereshet ki, és – az Ön megerősítésével – módosításokat is végezhet.

![Az MI-asszisztens csevegőablaka a fájlpanelek mellé dokkolva](screenshots/ai-chat.png)
*(Ábra: Az MI-asszisztens a jobb oldalra dokkolva, egy kérésen dolgozik.)*

## Jobb gombos műveletek (MI ▸)

Az asszisztens leggyorsabb használati módja a jobb gombos menü **MI ▸** almenüje:

- **Egy fájlon** – Összefoglalás, Magyarázat, Névjavaslat, Megjegyzésjavaslat, Fordítás angolra, Korrektúra, Feladatok felismerése és Táblázat készítése.
- **A panel hátterén** – Keresés jelentés szerint, Mappa rendszerezése és Valószínű duplikátumok keresése.

A(z) **Összefoglalás**, **Magyarázat**, **Névjavaslat**, **Megjegyzésjavaslat** és **Mappa rendezése** az **AI On-Device** bővítményből származik, és csevegés nélkül végzi a dolgát: egy lapon megmutatja a javaslatát, Ön kiveszi a pipát onnan, amit változatlanul hagyna, és a lemezen semmi sem változik, amíg jóvá nem hagyja. A többi művelet az **AI Assistant** bővítményhez tartozik, és saját nevesített csevegést nyit, így a különböző feladatok elkülönülnek. Ha Ön ír a beviteli mezőbe, az a kérés a jelenlegi csevegést folytatja.

## A csevegések kezelése

- A panel tetején lévő csevegésváltóval mozoghat a beszélgetések között.
- A **Törlés ▾** menü **Ezt a csevegést törlöm** és **Az összes csevegést törlöm** lehetőségeket kínál, így egyszerre kitakaríthat mindent, ha a lista túl hosszú lesz. Az üres csevegések automatikusan törlődnek, amikor bezárja a panelt.

## A módosításokat először megerősíti

Bármi olyan előtt, ami fájlokat módosít – áthelyezés, átnevezés, írás, törlés –, az asszisztens **megmutat egy tervet, és megvárja az Ön megerősítését**, mielőtt cselekedne. Ezt a Beállításokban módosíthatja az asszisztens önállóságának növelésével, vagy csak olvasható szintre csökkentheti, hogy soha semmit ne módosítson.

## Beállítások

Nyissa meg a **Beállítások ▸ Beállítások ▸ MI** oldalt, hogy egyetlen lapon konfigurálja az asszisztenst:

- **Előnyben részesített modell** – milyen modellt használ az **AI Assistant** csevegés. Amióta az eszközön futó műveletek külön bővítmény lettek, ez csak a csevegésre vonatkozik: a *Felhő* és az *Automatikus* egyaránt az alábbi végpontot használja, az *Eszközön* pedig azt jelzi a csevegésnek, hogy nincs rá szükség.
- **Felhővégpont, modell és API-kulcs** – a készüléken futó helyett egy OpenAI-kompatibilis modell használatához. A kulcs a macOS Kulcskarikán tárolódik, soha nem a konfigurációs fájlokban.
- **Az asszisztens önállósága** – csak olvasható, módosítások megerősítése (az alapértelmezett) vagy önálló.
- **Egyéni rendszerprompt** – opcionális utasítások, amelyek befolyásolják, ahogy az asszisztens válaszol.
- **MCP-kiszolgáló** – egy opcionális, csak helyben elérhető kiszolgáló, amely lehetővé teszi, hogy egy külső ügynök vezérelje az alkalmazást; alapértelmezés szerint ki van kapcsolva, és tokennel védhető.

![Az MI oldal a Beállításokban az önállóság és az MCP-kiszolgáló beállításaival](screenshots/settings-ai.png)
*(Ábra: Az asszisztens minden beállítása egyetlen MI oldalon található a Beállításokban.)*

## Adatvédelem

- Az Apple Intelligence használatakor az asszisztens **az Ön Mac gépén** fut; semmi sem hagyja el a készüléket.
- Felhőalapú modellt **csak akkor** használ a program, **ha Ön beállít egyet**, és annak API-kulcsa a Kulcskarikán marad.
- A fájlokat módosító műveleteket a program megerősítteti, mielőtt lefutnának, hacsak Ön szándékosan nem emeli meg az önállóság szintjét.
