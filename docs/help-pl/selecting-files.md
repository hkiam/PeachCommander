---
title: Zaznaczanie plików
slug: selecting-files
section: Pliki i foldery
order: 22
related: [copying-files, searching]
---

Zanim skopiujesz, przeniesiesz, usuniesz lub spakujesz cokolwiek, najpierw mówisz Peach Commander, na których elementach ma wykonać operację. Element, na którym spoczywa kursor, jest zawsze elementem bieżącym, ale możesz też *zaznaczyć* jeden lub wiele plików i folderów, aby polecenie zadziałało na wszystkich naraz. Zaznaczone elementy wyróżniają się w panelu odmiennym kolorem nazwy.

## Zaznaczanie plików i folderów

1. Kliknij wiersz, aby przenieść na niego kursor. Pojedyncze kliknięcie zaznacza tylko ten jeden element.
2. Aby zaznaczyć kilka elementów naraz, przytrzymaj Cmd i kliknij każdy z nich, albo przytrzymaj Shift i kliknij, aby zaznaczyć zakres.
3. Aby zaznaczyć element pod kursorem i zejść w dół jednym ruchem, naciśnij Insert. Naciskaj wielokrotnie, aby szybko zaznaczyć ciąg kolejnych elementów. Klawisz Spacja również przełącza zaznaczenie bieżącego elementu (i pokazuje rozmiar folderu).
4. Aby zaznaczyć wszystko w panelu, wybierz Zaznacz > Zaznacz wszystko (Ctrl+Num+) lub naciśnij Cmd+A. Wybierz Zaznacz > Odznacz wszystko (Ctrl+Num-), aby usunąć wszystkie zaznaczenia.

## Zaznaczanie lub odznaczanie według wzorca

1. Wybierz Zaznacz > Zaznacz grupę… (Num+), aby dodać elementy, których nazwy pasują do wzorca, lub Zaznacz > Odznacz grupę… (Num-), aby usunąć pasujące elementy z bieżącego zaznaczenia.
2. Wpisz maskę z symbolami wieloznacznymi. Użyj `*` dla dowolnych znaków i `?` dla pojedynczego znaku. Oddziel kilka masek średnikiem, a wyjątki wypisz po pionowej kresce — na przykład `*.jpg;*.png` zaznacza wszystkie obrazy, a `*.*|*.bak` zaznacza wszystko oprócz plików kopii zapasowych.

![Okno dialogowe Zaznacz grupę z maską wieloznaczną wpisaną w polu wzorca](screenshots/select-by-mask.png)
*(Rysunek: Zaznaczanie plików według maski wieloznacznej.)*

## Odwracanie, to samo rozszerzenie i przywracanie

- **Odwróć zaznaczenie** (Num*, menu Zaznacz) odwraca każde zaznaczenie: elementy zaznaczone stają się niezaznaczone i odwrotnie — przydatne dla „wszystko oprócz tych".
- **Zaznacz wszystkie z tym samym rozszerzeniem** (Alt+Num+, menu Zaznacz) zaznacza każdy plik, który dzieli rozszerzenie z elementem pod kursorem, więc jedno naciśnięcie klawisza obejmuje na przykład wszystkie pliki `.pdf`.
- **Przywróć zaznaczenie** (Num/, menu Zaznacz) przywraca poprzedni zestaw zaznaczeń — przydatne, jeśli polecenie je wyczyściło lub zaznaczyłeś niewłaściwą grupę.

## Skróty

| Akcja | Klawisz |
|---|---|
| Przełącz zaznaczenie, przejdź w dół | Insert |
| Przełącz zaznaczenie (bieżący element) | Space |
| Zaznacz wszystko / Odznacz wszystko | Ctrl+Num+ / Ctrl+Num- |
| Zaznacz wszystko (alternatywnie) | Cmd+A |
| Zaznacz grupę według maski | Num+ |
| Odznacz grupę według maski | Num- |
| Odwróć zaznaczenie | Num* |
| Zaznacz wszystkie z tym samym rozszerzeniem | Alt+Num+ |
| Przywróć poprzednie zaznaczenie | Num/ |

## Uwagi

- Zaznaczenia i kursor są niezależne: przesuwanie kursora klawiszami strzałek nie zmienia tego, co jest zaznaczone.
- Wpis folderu nadrzędnego (`..`) nigdy nie może zostać zaznaczony.
- Zaznacz grupę, Odznacz grupę i Odwróć zaznaczenie dopasowują się do nazwy pliku, więc możesz uwzględnić lub pominąć foldery w zależności od opcji okna dialogowego.
- Po zakończeniu kopiowania, przenoszenia lub usuwania elementy, które zostały pomyślnie obsłużone, są automatycznie odznaczane, a te, które się nie powiodły, pozostają zaznaczone, abyś mógł ponowić na nich operację.
