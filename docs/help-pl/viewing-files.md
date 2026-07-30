---
title: Podgląd plików
slug: viewing-files
section: Podgląd i edycja
order: 70
related: [editing-files, searching]
---

Peach Commander ma wbudowaną przeglądarkę, która pozwala zajrzeć do wnętrza pliku bez otwierania innej aplikacji ani zmiany pliku. Naciśnij F3 na elemencie pod kursorem, a przeglądarka otwiera się natychmiast, nawet dla bardzo dużych plików. Automatycznie wybiera najlepszy sposób pokazania zawartości: czytelny tekst, kod z kolorowaniem składni, surowy zrzut szesnastkowy lub obraz w pełnym rozmiarze. Możesz również podejrzeć plik prosto w oknie za pomocą Szybkiego podglądu, albo przekazać go do Quick Look w macOS.

## Wyświetl plik

1. Przesuń kursor na plik w aktywnym panelu.
2. Naciśnij F3 (lub wybierz Wyświetl w menu Plik). Przeglądarka otwiera się we własnym oknie.
3. Użyj paska narzędzi, aby przełączać sposób pokazania zawartości: Tekst, Kod, Szesnastkowy, Obraz lub Renderowany. Pozostaw ustawienie automatyczne, aby pozwolić Peach Commanderowi zdecydować.
4. Przewijaj strzałkami, Page Up/Page Down i paskiem przewijania. Przy długim tekście włącz przycisk minimapy, aby widzieć cały plik i szybko się po nim poruszać.
5. Naciśnij N, aby przeskoczyć do następnego wybranego pliku, lub zamknij okno klawiszem Esc.

![Wbudowana przeglądarka pokazująca plik tekstowy z minimapą po prawej](screenshots/lister-text.png)
*(Rysunek: podgląd pliku tekstowego, z selektorem reprezentacji i minimapą na pasku narzędzi.)*

## Znajdź tekst i zmień kodowanie

- Naciśnij Ctrl+F, aby wyszukać wewnątrz pliku. Naciśnij F3, aby przeskoczyć do następnego dopasowania, i Shift+F3 do poprzedniego.
- Jeśli tekst wygląda na zniekształcony, kliknij Kodowanie na pasku narzędzi (lub naciśnij E), aby przełączać kodowania tekstu, dopóki nie odczyta się poprawnie; ustawienie automatyczne zwykle trafia.
- Naciśnij W, aby przełączyć zawijanie wierszy dla długich linii.

## Szybki podgląd i Quick Look

Szybki podgląd pokazuje podgląd na żywo w panelu, którego *nie* używasz, dzięki czemu możesz kontynuować przeglądanie po jednej stronie, podglądając po drugiej.

1. Naciśnij Ctrl+Q. Nieaktywny panel zmienia się w obszar podglądu.
2. Przesuwaj kursor po różnych plikach w aktywnym panelu, aby podejrzeć każdy z nich.
3. Naciśnij Ctrl+Q ponownie, lub Esc, aby przywrócić panelowi normalną listę plików.

Aby uzyskać szybki podgląd pełnoekranowy obsługiwany przez sam macOS, naciśnij Cmd+Y (Quick Look). Naciśnij Cmd+Y lub Spację ponownie, aby go zamknąć.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Wyświetl plik pod kursorem | F3 |
| Wyświetl tylko plik pod kursorem (ignoruj oznaczone pliki) | Shift+F3 |
| Otwórz w zewnętrznej przeglądarce | Option+F3 |
| Znajdź w przeglądarce | Ctrl+F |
| Następne / poprzednie dopasowanie | F3 / Shift+F3 |
| Szybki podgląd w drugim panelu | Ctrl+Q |
| Quick Look (podgląd macOS) | Cmd+Y |
| Zamknij przeglądarkę lub Szybki podgląd | Esc |

## Uwagi

- Przeglądarka jest tylko do odczytu. Aby zmienić plik, użyj zamiast tego edytora (zobacz Edycja plików).
- Bardzo duże pliki otwierają się bez opóźnienia: tekst otwiera szybki, przewijalny widok, a widok szesnastkowy jest strumieniowany prosto z dysku przy dowolnym rozmiarze.
- Naciśnij F3 na folderze, aby zobaczyć podsumowanie jego zawartości i całkowity rozmiar zamiast bajtów pliku.
- Tryb Renderowany wyświetla sformatowaną zawartość, taką jak strony internetowe; tryb szesnastkowy pokazuje surowe bajty obok ich znaków, co jest przydatne do badania plików binarnych.
