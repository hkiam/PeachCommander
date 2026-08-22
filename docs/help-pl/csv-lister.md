---
title: Pliki CSV jako tabela
slug: csv-lister
section: Wtyczki
order: 129
related: [plugins, viewing-files, log-viewer]
---

Naciśnij **F3** na pliku `.csv` lub `.tsv`, a otworzy się jako prawdziwa tabela — kolumny, nagłówki, sortowanie i filtr — zamiast jako wiersze tekstu z przecinkami.

To wtyczka: możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**. Bez niej F3 pokazuje plik jako zwykły tekst, co przy małym pliku wciąż dobrze się czyta.

## Separator jest ustalany, a nie zakładany

Przecinek, średnik, tabulator, kreska pionowa i dwukropek — wszystkie wchodzą w grę. Wtyczka liczy każdy z nich w pierwszych dwudziestu wierszach i wybiera ten, który w największej liczbie wierszy występuje tyle samo razy: plik, w którym każdy wiersz ma cztery średniki, jest plikiem ze średnikami, cokolwiek mówi rozszerzenie. W praktyce to ma znaczenie: `.csv` wyeksportowany przez arkusz kalkulacyjny na polskim systemie zwykle jest rozdzielony średnikami, a `.tsv` nie zawsze tabulatorami.

Pierwszy wiersz traktowany jest jako nagłówek i staje się tytułami kolumn.

## Sortowanie i filtrowanie

Kliknij nagłówek kolumny, aby po niej posortować, kliknij ponownie, aby odwrócić. Sortowanie jest **liczbowe, gdy obie wartości są liczbami**, a w przeciwnym razie alfabetyczne, więc kolumna z rozmiarami ustawi 9 przed 10, a nie po nim.

Pole wyszukiwania filtruje w trakcie pisania, bez rozróżniania wielkości liter. Domyślnie zagląda do wszystkich kolumn; wybierz kolumnę w menu obok, aby szukać tylko w niej.

## Czego nie robi

Parser jest celowo niewielki, a jedno ograniczenie warto znać, zanim cię zaskoczy: **separator wewnątrz pola w cudzysłowie nadal jest traktowany jako separator.** Wiersz taki jak

```
"Smith, John",42
```

daje trzy komórki zamiast dwóch. Otaczające cudzysłowy są usuwane, gdy obejmują całe pole, ale poza tym cytowanie nie jest interpretowane. Do pliku, w którym to ma znaczenie, lepszym narzędziem jest wbudowana przeglądarka lub arkusz kalkulacyjny.

Puste wiersze są pomijane, a pole rozciągające się na kilka wierszy nie jest obsługiwane.
