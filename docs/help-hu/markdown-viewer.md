---
title: Markdown és HTML a megjelenítőben
slug: markdown-viewer
section: Bővítmények
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Nyomja meg az F3-at egy `.md` vagy `.html` fájlon, és formázva jelenik meg, nem forrásként: címsorok, listák, táblázatok, hivatkozások, tennivaló-listák és nyelv szerint színezett kódblokkok. A ` ```mermaid ` blokként írt diagramok kirajzolódnak, a dollárjelek közé írt matematika pedig szedésre kerül.

Ez egy bővítmény. Minden, ami ezen az oldalon szerepel, a **Markdown and HTML** bővítménytől jön, amelyet kikapcsolhat a **Konfiguráció ▸ Bővítmények…** menüben — lentebb olvasható, mi változik akkor.

## Hol jelenik meg a formázott nézet

- **A megjelenítő (F3).** A formázott oldal. A **Nézet** menü továbbra is felajánlja a Szöveg, Kód és Hex lehetőséget, tehát a forrás egy kattintásra van, és a bővítmény neve is szerepel abban a listában.
- **A Quick View (Ctrl+Q) és az oldalsáv információs lapja** ugyanazt a megjelenítést mutatja, így egy előnézet és egy teljes nézet ugyanarról a fájlról soha nem mond ellent egymásnak.
- **A galéria** egy Markdown-fájl kezdetének kis képét mutatja általános dokumentumikon helyett.
- **A Quick Look (Cmd+Y)** a macOS saját előnézete, és *nem* érinti — az a panel a rendszeré, és egyetlen bővítmény sem rajzolhat bele.

## A szimbólumvázlat

Nyomja meg a **Szimbólumok** gombot a megjelenítőben a dokumentum címsoraiért, úgy egymásba ágyazva, ahogy meg vannak írva, és kattintson egyre, hogy az oldalon odaugorjon. Működik a formázott nézetben és a forrásban is, és a kettő egyetért abban, hol van egy címsor.

## Diagramok és matematika

Egy `mermaid` nyelvű kódblokk diagrammá válik; a `$…$` és a `$$…$$` szedett matematikává. Mindkettőt **az Ön Macén** rajzolja ki a bővítményben szállított két eszköz — semmi sem töltődik le, és a dokumentum egyetlen része sem kerül elküldésre. Egy dollárjel kódblokkban vagy soron belüli kódban dollárjel marad.

Egy diagram és formula nélküli dokumentum egyik eszközt sem tölti be, tehát egy hétköznapi README nem kerül semmi többe. Egy olvashatatlan diagram ott jelzi a hibát, ahol a blokk volt, alatta a blokk saját szövegével, ahelyett hogy eltűnne.

Mindkettő külön kikapcsolható a **Konfiguráció ▸ Beállítások ▸ Markdown** oldalon, ahol az is látszik, melyik verzió van használatban és honnan származik.

## A saját verziója

Ha a Mermaid vagy a KaTeX újabb vagy más változatára van szüksége, tegye abba a mappába, amelyet az **Engine Folder…** gomb megnyit, és a szállított helyett azt fogja használni. A fájlnevek: `mermaid.min.js`, `katex.min.js`, `katex.min.css` és `auto-render.min.js`. Az internetről soha semmit nem tölt le Ön helyett.

## Amit a formázott oldal nem tesz meg

A formázott oldal szándékosan el van szigetelve, mert egy Markdown-fájl máshonnan érkezett tartalom:

- **Semmit nem tölt be a hálózaton.** Egy kép, amelynek címe `http`-vel kezdődik, szándékosan üresen marad: a letöltése elárulná annak a kiszolgálónak, mikor nyitotta meg a fájlt, és milyen címről. A dokumentum mellett a lemezen fekvő kép rendesen betöltődik.
- **A dokumentum saját szkriptjei és HTML-je soha nem futnak le.** A Markdown-fájlba írt HTML szövegként jelenik meg, a `.html` fájl pedig kikapcsolt szkriptekkel kerül megjelenítésre.

## Kikapcsolás

Kapcsolja ki a bővítményt a **Konfiguráció ▸ Bővítmények…** menüben, és a `.md` és `.html` fájlok szövegként nyílnak meg. A vázlat továbbra is működik, a szintaxisszínezés továbbra is működik, és semmi más nem változik — a formázott nézet egyszerűen nem elérhető többé. Ugyanez igaz, ha a bővítmény beállítási lapján csak a formázott nézetet kapcsolja ki.

## Korlátok

- A méretkorlát (alapértelmezés szerint 8 MB, a beállítási lapon) felett a fájlok szövegként nyílnak meg. Egy nagyon nagy generált dokumentumot formázott oldallá alakítani lassú, a szövegmegjelenítő pedig azonnal megnyitja.
- A formázott oldal nem szerkeszthető. Ehhez használja az F4-et, vagy a Szöveg nézetet a **Formázás**, **Kódolás** és **Ugrás** funkciókhoz, amelyek a forrásra érvényesek és nem egy kirajzolt oldalra.
