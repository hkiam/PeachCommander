---
title: Szybkie wyszukiwanie i filtr
slug: quick-search-and-filter
section: Organizacja widoku
order: 44
related: [searching, view-modes-and-sorting]
---

Gdy folder zawiera setki elementów, rzadko musisz przewijać. Peach Commander pozwala przeskoczyć prosto do pliku, wpisując jego nazwę (szybkie wyszukiwanie), ograniczyć listę tylko do interesujących Cię elementów (szybki filtr) oraz pokazać lub ukryć pliki z kropką, które macOS zwykle trzyma poza wzrokiem. Wszystkie trzy działają wewnątrz aktywnego panelu, bez otwierania okna dialogowego.

## Przeskok do pliku przez pisanie (szybkie wyszukiwanie)

1. Kliknij panel plików, aby był aktywny.
2. Zacznij wpisywać początek nazwy. Kursor przeskakuje do pierwszego pasującego elementu.
3. Pisz dalej, aby zawęzić dopasowanie, lub naciśnij tę samą literę ponownie, aby przechodzić między elementami zaczynającymi się na tę literę.
4. Wpisany tekst czyści się po krótkiej pauzie, więc możesz w dowolnej chwili rozpocząć nowe wyszukiwanie.

Domyślnie zwykłe litery trafiają do wiersza poleceń, a szybkie wyszukiwanie jest uruchamiane skrótem Ctrl+Option+litera (klasyczne zachowanie). Możesz przełączyć szybkie wyszukiwanie tak, aby zamiast tego reagowało na zwykłe pisanie, lub wyłączyć je w ustawieniach Konfiguracji.

## Filtrowanie listy (szybki filtr)

1. W aktywnym panelu naciśnij Ctrl+S, aby włączyć szybki filtr.
2. Wpisz maskę filtra. Panel na żywo zawęża się do pasujących elementów w miarę pisania.
3. Naciśnij Esc, aby wyczyścić filtr i ponownie pokazać wszystko.

Filtr przyjmuje kilka rodzajów masek:

- **Zwykły tekst** dopasowuje każdą nazwę, która zawiera to, co wpisałeś (na przykład `report` pokazuje każdy element mający „report" gdziekolwiek w nazwie).
- **Symbole wieloznaczne** używają `*` (dowolne znaki) i `?` (jeden znak). Oddziel kilka masek średnikiem i dodaj wykluczenia po pionowej kresce, na przykład `*.jpg;*.png|*thumb*`, aby pokazać obrazy, ale ukryć miniatury.
- **Etykiety Findera** filtrują według koloru etykiety: wpisz `tag:red` (lub `#red`), aby pokazać tylko elementy oznaczone na czerwono, albo samo `tag:`, aby pokazać wszystko, co nosi jakąkolwiek etykietę.

## Pokazywanie ukrytych plików

Naciśnij Ctrl+H lub wybierz polecenie z menu Widok, aby przełączać ukryte elementy (nazwy zaczynające się od kropki oraz pliki ukryte przez system). Ustawienie dotyczy aktywnego panelu i jest zapamiętywane między sesjami.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Szybkie wyszukiwanie (tryb klasyczny) | Ctrl+Option+litera |
| Szybki filtr wł./wył. | Ctrl+S |
| Wyczyść filtr / anuluj | Esc |
| Pokaż/ukryj ukryte pliki | Ctrl+H |

## Uwagi

- Szybkie wyszukiwanie tylko przesuwa kursor; szybki filtr faktycznie zmienia to, które elementy są wyświetlane. Użyj filtra, gdy chcesz pracować na podzbiorze (na przykład zaznaczyć lub skopiować tylko dopasowania).
- Ustawienia filtra i ukrytych plików są przypisane do panelu, więc obie strony mogą jednocześnie pokazywać różne rzeczy.
- Szybkie wyszukiwanie dopasowuje nazwy od początku; tryb zwykłego tekstu szybkiego filtra dopasowuje w dowolnym miejscu nazwy. Użyj symbolu wieloznacznego jak `*text*`, jeśli chcesz, aby filtr zachowywał się tak samo.
