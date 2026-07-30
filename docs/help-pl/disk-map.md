---
title: Mapa dysku
slug: disk-map
section: Wtyczki
order: 121
related: [plugins, deleting-files, settings]
---

Mapa dysku to wbudowana wtyczka, która pokazuje na pierwszy rzut oka, co zajmuje miejsce w folderze lub na całym woluminie. Skanuje wybrany folder i rysuje każdy element o rozmiarze proporcjonalnym do miejsca, które faktycznie zajmuje na dysku, dzięki czemu największe pożeracze miejsca od razu się wyróżniają. Możesz wchodzić w foldery, zobaczyć, jak Twój skan uzgadnia się z wolnym, możliwym do wyczyszczenia i ukrytym miejscem woluminu, oraz sprzątać bezpośrednio z mapy.

## Rozpocznij skanowanie

1. W aktywnym panelu przejdź do folderu (lub woluminu), który chcesz zmierzyć.
2. Wybierz **Polecenia ▸ Mapa dysku: Analizuj bieżący folder**.
3. Widok Mapy dysku otwiera się po prawej i skanuje w tle, pokazując bieżącą liczbę elementów i bajtów. Duże foldery kończą się w kilka sekund — skan odczytuje metadane katalogu zbiorczo i działa na kilku rdzeniach procesora.

![Mapa dysku pokazująca mapę drzewa folderu, pasek woluminu, listę największych plików i legendę kategorii](screenshots/disk-map.png)
*(Rysunek: widok mapy drzewa, pokolorowany według kategorii pliku, z paskiem woluminu na górze i listą największych plików po prawej.)*

## Odczytaj mapę

- Każdy blok (mapa drzewa) lub segment pierścienia (wykres słoneczny) ma rozmiar według **rzeczywistego rozmiaru na dysku** elementu, więc obraz odpowiada temu, co raportują Finder i system.
- Bloki są **pokolorowane według typu pliku** — wideo, obrazy, dźwięk, dokumenty, kod, archiwa, aplikacje, obrazy dysków — z legendą na dole. W ustawieniach możesz przełączyć na **mapę cieplną** według rozmiaru.
- **Kliknij folder**, aby w niego wejść; ścieżka nawigacyjna na górze pokazuje, gdzie jesteś, a przycisk **◂** cofa o poziom wyżej.
- Najedź na dowolny blok, aby zobaczyć jego pełną ścieżkę, rozmiar i liczbę elementów.

## Dwa widoki: mapa drzewa i wykres słoneczny

Mapa dysku oferuje dwie wizualizacje, między którymi możesz przełączać przyciskiem **◎ / ▦** w nagłówku lub na stronie ustawień:

- **Mapa drzewa** — zagnieżdżone prostokąty, najgęstsza do wypatrzenia pojedynczego największego pliku.
- **Wykres słoneczny** — koncentryczne pierścienie (jeden na głębokość folderu) wokół bieżącego folderu, najlepszy do zobaczenia, jak miejsce rozkłada się w głębokim drzewie.

![Widok wykresu słonecznego Mapy dysku pokazujący koncentryczne pierścienie dla głębokości folderów](screenshots/disk-map-sunburst.png)
*(Rysunek: widok wykresu słonecznego — wewnętrzny dysk to bieżący folder, a każdy pierścień to jeden poziom głębiej.)*

## Pasek woluminu

Pasek na górze uzgadnia Twój skan z całym woluminem:

- **Zeskanowane / Ten folder** — ile zajmuje analizowany folder.
- **Ukryte** (w katalogu głównym woluminu) lub **Reszta woluminu** (dla podfolderu) — wszystko, co nie jest w tym skanie, w tym foldery chronione przez system, inni użytkownicy i migawki.
- **Możliwe do wyczyszczenia** — miejsce, które macOS może automatycznie odzyskać, głównie lokalne migawki Time Machine i pamięci podręczne.
- **Wolne** — miejsce dostępne od razu.

Gdy wolumin ma lokalne migawki, pasek pokazuje element **· N migawek (ⓘ)**; kliknij go, aby uzyskać listę tylko do odczytu, ze wskazówką, aby zarządzać nimi w Narzędziu dyskowym lub Time Machine. Mapa dysku nigdy sama nie usuwa migawek.

## Największe pliki

Włącz **Pokaż listę największych plików**, aby zobaczyć największe pliki w bieżącym folderze uszeregowane według rozmiaru, każdy z kolorowym znacznikiem swojej kategorii. Kliknij jeden, aby podświetlić go na mapie.

## Sprzątaj z mapy

Kliknij prawym przyciskiem dowolny blok, aby uzyskać akcje:

- **Otwórz w lewym panelu** / **Otwórz w prawym panelu** — pokaż element w panelu plików.
- **Pokaż w Finderze**.
- **Przenieś do Kosza** — usuń tylko ten element; mapa aktualizuje się bez pełnego ponownego skanowania.

Aby usunąć kilka elementów naraz, użyj **kolekcjonera**: kliknij prawym przyciskiem ▸ **Oznacz dla kolekcjonera** na każdym elemencie, a następnie kliknij przycisk **🗑 N** w nagłówku, aby przenieść wszystko, co oznaczyłeś, do Kosza w jednym potwierdzonym kroku.

## Ustawienia

Mapa dysku dodaje własną stronę do okna Ustawień (**Konfiguracja ▸ Ustawienia ▸ Mapa dysku**):

- **Styl wykresu** — mapa drzewa lub wykres słoneczny.
- **Kodowanie kolorów** — według typu pliku (kategoria) lub według rozmiaru (mapa cieplna).
- **Pozostań na woluminie początkowym** — nie przechodź na inne zamontowane dyski.
- **Pokaż pasek woluminu** i **Pokaż listę największych plików**.

Zmiany są stosowane do otwartej Mapy dysku natychmiast.

## Uwagi

- Mapa dysku mierzy rozmiar **przydzielony** (na dysku) i liczy pliki z **dowiązaniami twardymi** tylko raz, więc jej sumy pokrywają się z użytym miejscem woluminu, zamiast je zawyżać.
- Domyślnie skan pozostaje na woluminie początkowym, więc nie zawędruje na inne zamontowane dyski ani udziały sieciowe.
