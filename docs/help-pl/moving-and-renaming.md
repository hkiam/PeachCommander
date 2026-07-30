---
title: Przenoszenie i zmiana nazw
slug: moving-and-renaming
section: Pliki i foldery
order: 26
related: [copying-files, multi-rename]
---

Przenoszenie przemieszcza pliki i foldery, zamiast je powielać, a zmiana nazwy zmienia ich nazwy bez naruszania zawartości. Ponieważ Peach Commander pokazuje dwa panele obok siebie, przenoszenie sprowadza się do wybrania tego, co chcesz, w jednym panelu i wysłania tego do folderu otwartego w drugim. Możesz też zmienić nazwę elementu w miejscu lub nadać przenoszonym elementom nowe nazwy w locie za pomocą maski wieloznacznej.

## Przenoszenie plików do drugiego panelu

1. W panelu źródłowym otwórz folder zawierający elementy, które chcesz przenieść, a w drugim panelu otwórz folder docelowy.
2. Zaznacz plik lub folder do przeniesienia. Aby przenieść kilka naraz, najpierw zaznacz je wszystkie (zobacz *Zaznaczanie plików*).
3. Naciśnij F6 lub wybierz **Plik > Przenieś**.
4. Sprawdź folder docelowy pokazany w oknie dialogowym i kliknij **OK** (lub naciśnij Return), aby rozpocząć przenoszenie.

![Okno dialogowe przenoszenia z polem ścieżki docelowej, opcjami i polem wyboru kolejki](screenshots/copy-dialog.png)
*(Rysunek: Okno dialogowe przenoszenia używa tego samego pola docelowego co kopiowanie — wpisz ścieżkę lub dodaj maskę wieloznaczną, aby zmienić nazwę podczas przenoszenia.)*

Przenoszenie na tym samym dysku odbywa się niemal natychmiast. Gdy miejsce docelowe znajduje się na innym dysku, Peach Commander kopiuje elementy, a następnie usuwa oryginały dopiero po bezpiecznym dotarciu każdego pliku.

## Zmiana nazwy w miejscu

1. Zaznacz pojedynczy plik lub folder.
2. Naciśnij Shift+F6 lub wybierz **Plik > Zmień nazwę**.
3. Edytuj nazwę bezpośrednio w panelu, a następnie naciśnij Return, aby potwierdzić, lub Esc, aby anulować.

## Zmiana nazwy podczas przenoszenia

Pole docelowe w oknie dialogowym przenoszenia przyjmuje maskę wieloznaczną, więc możesz zmieniać nazwy elementów w trakcie przenoszenia:

1. Zaznacz elementy i naciśnij F6.
2. W polu docelowym dodaj maskę nazwy po folderze docelowym, na przykład `/Users/you/Archive/*_backup.*`.
3. `*` oznacza oryginalną nazwę, a `.*` oryginalne rozszerzenie. Potwierdź, aby przenieść i zmienić nazwę w jednym kroku.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Przenieś do drugiego panelu | F6 |
| Zmień nazwę w miejscu | Shift+F6 |

## Wskazówki

- Okno dialogowe przenoszenia oferuje ten sam przycisk opcji i pole wyboru kolejki w tle co kopiowanie, więc możesz kolejkować duże przenoszenia i pozwolić im działać w tle.
- Przenoszenie w obrębie tego samego dysku to szybka operacja w miejscu, więc jest bezpieczne dla bardzo dużych folderów. Przenoszenie między dyskami trwa dłużej, ponieważ dane są najpierw kopiowane, a potem źródło jest usuwane.
- Aby zmienić nazwy wielu plików naraz z numeracją, funkcją wyszukaj-i-zamień lub wzorcami, użyj zamiast tego Narzędzia zmiany nazw wielu plików (zobacz *Zmiana nazw wielu plików*).
