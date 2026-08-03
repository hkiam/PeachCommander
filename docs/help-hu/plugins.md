---
title: Bővítmények
slug: plugins
section: Bővítmények
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, archives, ftp-and-sftp]
---

A bővítmények kiegészítik a Peach Commandert extra eszközökkel, fájlformátumokkal és böngészhető helyekkel. Egy tucat bővítmény beépített, így azonnal elkezdheti használni őket, és egyes bővítményeket be- vagy kikapcsolhat — vagy újakat telepíthet — egyetlen ablakból. Használjon bővítményeket, ha a mindennapi másoláson és böngészésen túli képességeket szeretne: megjeleníteni, mi tölti meg a lemezt, csatlakozni egy WebDAV-kiszolgálóhoz, ellenőrizni egy Git-tároló állapotát, figyelni a rendszertevékenységet, és többet.

A bővítmények többféle formában érkeznek: egyesek egy **panelt vagy oldalsávot** adnak (egy nézetet), egyesek **oszlopokat** adnak a fájllistához, egyesek egy **helyet, ahová benavigálhat**, mint egy meghajtó, és egyesek egy új **archívumformátumot** tanítanak meg az appnak. Mindegyik egymástól függetlenül engedélyezhető.

## Mit adnak hozzá a beépített bővítmények

Több bővítménynek saját, részletes súgótémája van — kövesse a hivatkozást a teljes történetért:

- **[Lemeztérkép](disk-map.md)** — megjeleníti, mi tölti meg a mappát vagy kötetet fatérképként vagy napkitörésként, a szabad, kiüríthető és rejtett hellyel egyeztetve, egy takarító gyűjtővel.
- **[Asszisztens MI](ai-assistant.md)** — egy opcionális, eltávolítható asszisztens, amely természetes nyelven összefoglal, átnevez, fordít, táblázatba rendez és rendszerez fájlokat, az eszközön vagy egy felhőmodellen keresztül.
- **[Git](git.md)** — megmutatja minden fájl munkafa-állapotát és az aktuális branchet paneloszlopokként, és hozzáad egy **Git** menüt a státuszhoz, előkészítéshez, committoláshoz, pullhoz és pushhoz.
- **[System Monitor](system-monitor.md)** — valós idejű kijelzés a processzorról, memóriáról, lemezről, hálózatról (és ahol elérhető, GPU-ról, akkumulátorról, érzékelőkről) az ablak címsorában, átkattintható részletdiagramokkal.
- **[Task Manager](task-manager.md)** — a futó folyamatait böngészhető **TaskManager** meghajtóként csatolja; rendezze, vizsgálja őket fájlokként, vagy zárja be őket a Törlés billentyűvel.
- **[Uninstaller](uninstaller.md)** — eltávolít egy alkalmazást **és** a hátrahagyott támogatófájlokat, gyorsítótárakat és beállításokat, miután pontosan megmutatta, mi tűnik el.

A többi beépített bővítmény kisebb, és nincs szüksége saját oldalra:

- **WebDAV** — csatlakozzon egy WebDAV-kiszolgálóhoz (**Hálózat ▸ WebDAV-kapcsolat…**), és böngésszen, töltsön fel, töltsön le, nevezzen át és töröljön rajta, mintha egy mappa lenne. A jelszavak a macOS Kulcskarikán maradnak.
- **iCloud Drive** — hozzáad egy *iCloud Drive* bejegyzést a meghajtósávhoz, amely közvetlenül a helyi iCloud Drive mappájához ugrik. Csak akkor jelenik meg, ha az iCloud Drive be van állítva a Macen.
- **Notes** — tartson egy jegyzetet bármely fájl vagy mappa mellett. Egy kis **●** jelvény jelöli az olyan elemeket, amelyekhez tartozik; szerkessze a jegyzeteket egy dokkolt **Notes** oldalsávban vagy egy teljes rich-text szerkesztőben (**Parancsok ▸ Jegyzet szerkesztése…**), és böngéssze mindet a **Jegyzetek áttekintése…** paranccsal.
- **Log Viewer** — nyisson meg egy fájlt színkódolt, szint szerint besorolt, élőben követett naplóként (**Fájl ▸ Megtekintés naplóként…**), szintenkénti szűrőkkel, kereséssel, valamint a gyakori naplóformátumok és a saját regex-formátumai támogatásával. A több gigabájtos naplókat azonnal kezeli.
- **CSV Lister** — nyomjon F3-at egy `.csv` vagy `.tsv` fájlon, és igazi táblázatként nyílik meg rendezhető oszlopokkal, nem nyers szövegként. A határolójelet automatikusan felismeri, így a pontosvesszővel elválasztott exportok is illeszkednek, a megjelenítő keresése pedig cellánként találja meg az értékeket.
- **AI Column** — hozzáad egy *AI Language* oszlopot, amely az eszközön felismeri minden szövegfájl uralkodó nyelvét (az Apple NaturalLanguage keretrendszerével — nem felhőmodellel).
- **Archívumformátumok** — megtanítja az appnak, hogy több archívumtípust böngésszen és csomagoljon ki (7z, tar-család, gzip/bzip2/xz/zstd, valamint RAR, ahol egy segédeszköz telepítve van), amelyek aztán mappaként nyílnak meg.

## Bővítmények be- vagy kikapcsolása

1. Válassza a Konfiguráció ▸ Bővítmények… lehetőséget a bővítmények ablak megnyitásához.
2. Minden telepített bővítmény megjelenik a listában névvel, típussal és egy „Engedélyezve" jelölőnégyzettel.
3. Jelölje be vagy törölje a jelölőnégyzetet egy bővítmény engedélyezéséhez vagy letiltásához. A változtatások azonnal életbe lépnek — az engedélyezett bővítmények hozzáadják a menüiket, oszlopaikat és funkcióikat; a letiltottak félreállnak.

![A bővítmények ablak felsorolja a telepített bővítményeket jelölőnégyzetekkel és a Telepítés és Eltávolítás gombokkal](screenshots/plugins-window.png)
*(Ábra: a bővítmények ablak, ahol engedélyez, letilt, telepít vagy eltávolít bővítményeket.)*

## Új bővítmény telepítése

1. Válassza a Konfiguráció ▸ Bővítmények… lehetőséget.
2. Kattintson a **Telepítés mappából…** lehetőségre.
3. Válasszon egy bővítménycsomagot vagy egy `.zip`-et, amely egyet tartalmaz, és erősítse meg. A bővítmény hozzáadódik a listához és engedélyeződik.

## Bővítmény eltávolítása

1. A bővítmények ablakban jelölje meg a bővítményt a listában.
2. Kattintson az **Eltávolítás**-ra. A beépített funkciók nem érintettek; csak a kiválasztott bővítmény távolodik el.

## Megjegyzések

- A bővítménylista minden bővítmény típusát és felületverzióját mutatja a neve és helye mellett, így megerősítheti, mi van telepítve.
- Ha nincs bővítmény telepítve, az ablak egy rövid felszólítást mutat, amely a **Telepítés mappából…** felé irányítja.
- Egyes bővítmények csak akkor adnak hozzá saját oszlopokat, menüelemeket vagy panelhelyeket, amíg engedélyezve vannak. Ha egy várt funkció hiányzik, ellenőrizze, hogy a bővítmény itt be van-e kapcsolva.
