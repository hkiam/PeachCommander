---
title: Otwieranie plików i folderów
slug: opening-files
section: Pliki i foldery
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander otwiera pliki i foldery bezpośrednio z dowolnego panelu, używając tych samych aplikacji i funkcji systemowych, na których już polegasz w Finderze. Naciśnij klawisz, aby otworzyć element pod kursorem w jego domyślnej aplikacji, lub kliknij prawym przyciskiem myszy, aby dotrzeć do pełnego menu akcji — otwórz w innej aplikacji, pokaż element w Finderze, udostępnij go lub otwórz okno Terminala dokładnie tam, gdzie się znajdujesz.

## Otwieranie elementu

1. Kliknij plik lub folder w panelu, aby ustawić na nim kursor (wyróżniony wiersz).
2. Naciśnij Enter (lub kliknij dwukrotnie).
   - Folder otwiera się w tym samym panelu.
   - Plik otwiera się w swojej domyślnej aplikacji macOS — tej samej, której użyłby Finder.
   - Archiwum (takie jak .zip) otwiera się jako folder, dzięki czemu możesz przeglądać jego zawartość.

![Główne okno Peach Commander z obydwoma panelami pokazującymi pliki i foldery](screenshots/main-window.png)
*(Rysunek: Ustaw kursor na dowolnym elemencie, a następnie naciśnij Enter, aby go otworzyć.)*

## Otwieranie w innej aplikacji, pokazywanie lub udostępnianie

Kliknij plik prawym przyciskiem myszy (lub naciśnij Shift+F10), aby otworzyć menu elementu, a następnie wybierz:

- **Otwórz** lub **Otwórz w domyślnej aplikacji** — otwiera plik tak, jak zrobiłby to Enter.
- **Otwórz za pomocą** — wybierz dowolną zainstalowaną aplikację, która może otworzyć ten plik, lub wybierz **Inne…**, aby ją wyszukać.
- **Quick Look** — podejrzyj plik bez otwierania aplikacji.
- **Pokaż w Finderze** — pokaż plik zaznaczony w oknie Findera.
- **Udostępnij…** — wyślij plik przez arkusz udostępniania macOS.

Menu scala także standardowe **Usługi** macOS dla wybranego pliku i dodaje **Etykiety**, dzięki czemu możesz stosować zwykłe kolorowe etykiety Findera.

## Otwieranie Terminala w bieżącym folderze

Wybierz **Otwórz Terminal tutaj** z menu Plik lub Polecenia (Cmd+Option+T), aby otworzyć okno Terminala już skierowane na folder aktywnego panelu.

## Skróty

| Akcja | Klawisz |
|---|---|
| Otwórz element pod kursorem | Enter |
| Podgląd pliku (przeglądarka) | F3 |
| Edytuj plik | F4 |
| Podgląd Quick Look | Cmd+Y |
| Informacje / właściwości | Option+Enter |
| Otwórz menu elementu | Shift+F10 lub prawy przycisk myszy |
| Otwórz tutaj Terminal | Cmd+Option+T |

## Uwagi

- „Domyślna aplikacja" oznacza aplikację, której macOS ma używać dla danego typu pliku; zmień ją w panelu Informacje pliku, dokładnie tak jak w Finderze.
- **Pokaż w Finderze**, **Udostępnij…** i **Otwórz za pomocą ▸ Inne…** dotyczą elementów na dysku Twojego Maca. Nie są dostępne dla elementów wewnątrz archiwum ani na połączeniu zdalnym (FTP/SFTP).
- Kliknięcie prawym przyciskiem myszy działającego procesu (w widoku procesów) pokazuje krótsze, specyficzne dla procesu menu zamiast akcji na plikach.
