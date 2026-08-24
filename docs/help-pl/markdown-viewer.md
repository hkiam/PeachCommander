---
title: Markdown i HTML w podglądzie
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Naciśnij F3 na pliku `.md` lub `.html` i pojawi się sformatowany, a nie jako źródło: nagłówki, listy, tabele, odnośniki, listy zadań i bloki kodu pokolorowane według języka. Diagramy zapisane jako bloki ` ```mermaid ` są rysowane, a matematyka między znakami dolara jest składana.

To wtyczka. Wszystko na tej stronie pochodzi z **Markdown and HTML**, którą można wyłączyć w **Konfiguracja ▸ Wtyczki…** — niżej opisano, co się wtedy zmienia.

## Gdzie pojawia się widok sformatowany

- **Podgląd (F3).** Strona sformatowana. Menu **Widok** nadal oferuje Tekst, Kod i Hex, więc źródło jest w jednym kliknięciu, a nazwa wtyczki również znajduje się na tej liście.
- **Quick View (Ctrl+Q) i strona informacji** w panelu bocznym pokazują to samo, więc podgląd i pełny widok tego samego pliku nigdy się nie różnią.
- **Galeria** pokazuje mały obraz początku pliku Markdown zamiast ogólnej ikony dokumentu.
- **Quick Look (Cmd+Y)** to własny podgląd systemu macOS i *nie* jest objęty — ten panel należy do systemu i żadna wtyczka nie może w nim rysować.

## Zestawienie symboli

Naciśnij **Symbole** w podglądzie, aby uzyskać nagłówki dokumentu, zagnieżdżone tak, jak zostały zapisane, i kliknij jeden, aby przejść do niego na stronie. Działa w widoku sformatowanym i w źródle, a oba są zgodne co do miejsca nagłówka.

## Diagramy i matematyka

Blok kodu o języku `mermaid` staje się diagramem; `$…$` i `$$…$$` stają się złożoną matematyką. Oba są rysowane **na Twoim Macu**, przez silniki dostarczone wewnątrz wtyczki — nic nie jest pobierane i żadna część dokumentu nigdzie nie jest wysyłana. Znak dolara w bloku kodu lub w kodzie wewnątrz wiersza pozostaje znakiem dolara.

Dokument bez diagramu i bez formuły nie ładuje żadnego silnika, więc zwyczajny README nie kosztuje nic dodatkowo. Diagram, którego nie da się odczytać, pokazuje błąd tam, gdzie był blok, z jego własnym tekstem poniżej, zamiast zniknąć.

Oba można wyłączyć osobno w **Konfiguracja ▸ Ustawienia ▸ Markdown**, gdzie widać także, która wersja jest używana i skąd pochodzi.

## Własna wersja

Jeśli potrzebujesz nowszej lub innej wersji Mermaid albo KaTeX, umieść ją w folderze, który otwiera przycisk **Engine Folder…**, i zostanie użyta zamiast dostarczonej. Nazwy plików to `mermaid.min.js`, `katex.min.js`, `katex.min.css` i `auto-render.min.js`. Nic nigdy nie jest pobierane z internetu.

## Czego strona sformatowana nie zrobi

Strona sformatowana jest celowo odcięta, bo plik Markdown to treść, która przyszła z zewnątrz:

- **Nie ładuje niczego przez sieć.** Obraz, którego adres zaczyna się od `http`, celowo pozostaje pusty: pobranie go powiedziałoby tamtemu serwerowi, kiedy otworzyłeś plik i z jakiego adresu. Obraz leżący obok dokumentu na dysku ładuje się normalnie.
- **Skrypty i HTML dokumentu nigdy się nie wykonują.** HTML zapisany w pliku Markdown jest pokazywany jako tekst, a plik `.html` jest wyświetlany z wyłączonymi skryptami.

## Wyłączanie

Wyłącz wtyczkę w **Konfiguracja ▸ Wtyczki…**, a pliki `.md` i `.html` otworzą się jako tekst. Zestawienie nadal działa, kolorowanie składni nadal działa i nic więcej się nie zmienia — widok sformatowany po prostu nie jest już oferowany. To samo dotyczy wyłączenia samego widoku sformatowanego na stronie ustawień wtyczki.

## Ograniczenia

- Pliki powyżej limitu rozmiaru (domyślnie 8 MB, na stronie ustawień) otwierają się jako tekst. Zamiana bardzo dużego wygenerowanego dokumentu w stronę sformatowaną jest wolna, a podgląd tekstu otwiera go od razu.
- Strony sformatowanej nie da się edytować. Użyj do tego F4 albo widoku Tekst dla **Formatuj**, **Kodowanie** i **Idź do**, które dotyczą źródła, a nie strony wyrenderowanej.
