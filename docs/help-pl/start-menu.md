---
title: Menu Start i polecenia niestandardowe
slug: start-menu
section: Dostosowywanie
order: 111
related: [toolbar, keyboard-shortcuts]
---

Menu **Start** to Twoje własne osobiste menu, znajdujące się na pasku menu obok Plik, Edycja i pozostałych. Zawiera polecenia, które sam definiujesz, dzięki czemu akcje, po które sięgasz najczęściej, są zawsze o jedno kliknięcie. W tradycji klasycznych dwupanelowych menedżerów plików każda pozycja może uruchomić wbudowane polecenie, uruchomić zewnętrzny program lub aplikację, albo przeskoczyć prosto do folderu. Peach Commander jest dostarczany z pustym menu Start, gotowym do wypełnienia przez Ciebie.

## Jak dodać własne polecenia

1. Wybierz **Start > Zmień menu Start…**. Peach Commander otwiera Twój plik poleceń użytkownika (tworząc go z zakomentowanym przykładem za pierwszym razem).
2. Dodaj jedną sekcję na polecenie. Każda sekcja zaczyna się od nazwy w nawiasach kwadratowych, a następnie kilka prostych kluczy:
   - **cmd** — co uruchomić: ścieżkę programu, aplikację, wbudowane polecenie `cm_`, lub inne z Twoich poleceń.
   - **param** — parametry przekazywane do programu. Symbole zastępcze są wypełniane przy uruchomieniu polecenia: `%P` (folder źródłowy), `%N` (bieżący plik), `%T` (folder drugiego panelu), `%M` (plik drugiego panelu), `%S` (wybrane pliki).
   - **path** — folder, w którym zacząć (domyślnie bieżący folder).
   - **menu** — tytuł pokazywany w menu Start.
   - **key** — opcjonalny skrót, np. `C+S+B`.
3. Zapisz plik. Menu Start aktualizuje się samo następnym razem, gdy Peach Commander stanie się aktywny, więc Twoje nowe pozycje pojawiają się od razu.

## Wskazówki

- Aby otworzyć bieżący folder w Terminalu, ustaw **cmd** na `open`, **param** na `-a Terminal %P`, a **menu** na `Otwórz Terminal tutaj`.
- Skieruj **cmd** na polecenie `cm_`, aby dać wbudowanej akcji własną pozycję menu Start i skrót.
- Kolejność w pliku jest kolejnością w menu, więc umieść najczęściej używane polecenia na górze.

## Uwagi

- Możesz również zastąpić cały pasek menu własnym. Wybierz **Konfiguracja > Edytuj plik menu…**, aby otworzyć plik menu zaczerpnięty z bieżącego, w pełni zlokalizowanego wbudowanego menu; edytuj go swobodnie, a Twoje zmiany zostaną zastosowane następnym razem, gdy aplikacja zostanie aktywowana. Usuń plik, aby przywrócić standardowy pasek menu.
