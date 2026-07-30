---
title: Zmiana nazw wielu plików
slug: multi-rename
section: Zaawansowane narzędzia
order: 92
related: [moving-and-renaming]
---

Narzędzie masowej zmiany nazw zmienia nazwy całej partii plików w jednym przebiegu. Zamiast edytować nazwy pojedynczo, opisujesz zmianę raz — wzorzec nazewnictwa, wyszukiwanie i zamianę, schemat numeracji lub zmianę wielkości liter — a Peach Commander stosuje ją do każdego wybranego pliku. Podgląd na żywo pokazuje dokładnie, jak będzie się nazywał każdy plik, zanim cokolwiek się stanie, a pojedyncze Cofnij przywraca oryginalne nazwy, jeśli wynik nie był taki, jak chciałeś.

## Zmień nazwy partii plików

1. Zaznacz pliki, których nazwy chcesz zmienić (zobacz *Zaznaczanie plików*). Dotyczy to tylko wybranych elementów.
2. Wybierz **Polecenia > Narzędzie masowej zmiany nazw…** lub naciśnij Ctrl+M.
3. Zbuduj regułę zmiany nazw za pomocą pól opisanych poniżej. Siatka podglądu aktualizuje się w miarę pisania, pokazując każdą **Starą nazwę** obok jej **Nowej nazwy**.
4. Sprawdź podgląd. Wiersz pokazany kolorem podświetlenia oznacza nazwę, której nie można użyć (na przykład duplikat lub niedozwoloną nazwę), więc możesz dostosować regułę.
5. Gdy podgląd wygląda dobrze, kliknij **Start**. Jeśli zmienisz zdanie, kliknij **Cofnij**, aby przywrócić oryginalne nazwy.

![Okno masowej zmiany nazw z polami maski, opcjami i siatką podglądu od starej do nowej](screenshots/multi-rename.png)
*(Rysunek: siatka podglądu aktualizuje się na żywo podczas edycji reguły zmiany nazw; nic nie zmienia się na dysku, dopóki nie klikniesz Start.)*

## Budowanie reguły zmiany nazw

- **Maska zmiany nazwy** i **Rozszerzenie** — wzorce budujące nową nazwę i rozszerzenie. Użyj przycisków szybkiego wstawiania lub wpisz symbole zastępcze bezpośrednio: `[N]` dla oryginalnej nazwy, `[N1-9]` dla zakresu znaków z niej, `[C]` dla licznika, `[d]` dla części daty i czasu oraz `[P]` dla nazwy folderu nadrzędnego.
- **Szukaj / Zamień na** — zamień tekst wewnątrz nazw. Włącz **Regex** dla dopasowania wzorca, **Uwzględnij wielkość** dla dokładnego dopasowania wielkości liter i **Powtarzaj** dla zamiany każdego wystąpienia.
- **Wielkość liter** — konwertuj nazwy na małe litery, WIELKIE LITERY, Pierwsza litera wielka lub Każde Słowo Wielką.
- **Licznik** — ustaw **początkowy** numer, **krok** między plikami oraz do ilu **cyfr** uzupełniać (na przykład 001, 002, 003), wszędzie tam, gdzie pojawia się `[C]`.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz narzędzie masowej zmiany nazw | Ctrl+M |
| Zastosuj zmianę nazw | Enter |
| Zamknij okno | Esc |

## Wskazówki

- Nic nie jest zapisywane na dysku, dopóki nie klikniesz **Start**, więc możesz swobodnie eksperymentować z regułą i obserwować podgląd.
- Po uruchomieniu **Cofnij** odwraca zmianę nazw w jednym kroku.
- Zapisz regułę, której często używasz, jako **Ustawienie wstępne**, a następnie wybierz je z menu ustawień wstępnych następnym razem, aby wypełnić wszystkie pola naraz.
- Aby zmienić nazwę pojedynczego pliku lub zmienić nazwy plików podczas ich przenoszenia, użyj zamiast tego zmiany nazwy w miejscu lub okna dialogowego przenoszenia (zobacz *Przenoszenie i zmiana nazw*).
