---
title: Git
slug: git
section: Wtyczki
order: 123
related: [plugins, view-modes-and-sorting]
---

Wtyczka Git pokazuje stan repozytorium Git bezpośrednio w panelu plików — bez osobnej aplikacji, bez terminala. Dodaje dwie kolumny prezentujące stan każdego pliku w drzewie roboczym oraz bieżącą gałąź, podmenu **Git** dla codziennych poleceń (status, dodawanie do przechowalni, commit, pull, push) i korzysta z programu `git` już zainstalowanego na Twoim Macu. Jest to wtyczka, więc możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Co dodaje

- **Dwie kolumny listy plików** — *Git Status* i *Branch*. W repozytorium każdy plik pokazuje krótkie słowo stanu (Zmodyfikowany, Dodany, Usunięty, Nieśledzony, Przemianowany, Skopiowany, Konflikt, Ignorowany lub Zmieniony), a panel pokazuje bieżącą gałąź. Włącz te kolumny w **Konfiguracja ▸ Kolumny…** (zobacz [Tryby widoku i sortowanie](view-modes-and-sorting.md)).
- **Menu Git** — w **Polecenia ▸ Git** oraz w menu prawego przycisku pliku, z pozycjami: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull** i **Git Push**.

![Okno Git Status pokazujące bieżącą gałąź i zmienione pliki w repozytorium](screenshots/git-status.png)
*(Rysunek: Git Status raportuje gałąź i każdą zmianę w drzewie roboczym.)*

## Sprawdź stan

1. Ustaw kursor na pliku lub folderze wewnątrz repozytorium Git.
2. Wybierz **Polecenia ▸ Git ▸ Git Status…** (lub kliknij prawym przyciskiem ▸ **Git ▸ Git Status…**).
3. Pojawia się podsumowanie: bieżąca gałąź (lub *(odłączona)*), a następnie albo *Drzewo robocze czyste.*, albo lista zmian, gdzie każdy wiersz pokazuje stan i ścieżkę pliku.

Jeśli kursor nie znajduje się wewnątrz repozytorium, wtyczka po prostu informuje *To nie jest repozytorium Git.*

## Dodawanie do przechowalni, commit, pull, push

- **Git Add (stage)** dodaje plik pod kursorem do przechowalni (`git add`).
- **Git Commit…** prosi o komunikat commita, a następnie zatwierdza wszystkie zmiany (`git commit -a`). Pokazywane jest łączne wyjście, dzięki czemu widzisz dokładnie, co się stało.
- **Git Pull** wykonuje pull tylko z przewinięciem w przód (`git pull --ff-only`).
- **Git Push** wypycha bieżącą gałąź (`git push`).

Po poleceniu, które zmienia repozytorium, aktywny panel jest odświeżany, więc kolumny stanu pozostają aktualne.

## Uwagi

- Wtyczka używa systemowego Gita w `/usr/bin/git`. Jeśli Git nie jest zainstalowany, polecenia zgłaszają, że Git jest niedostępny. (Zapewnia go instalacja narzędzi wiersza poleceń Xcode.)
- Stan repozytorium jest odczytywany raz na folder i buforowany, więc przewijanie dużego repozytorium pozostaje szybkie; bufor odświeża się po każdym poleceniu, które zmienia drzewo.
- Commit używa `git commit -a`, który zatwierdza śledzone zmiany; zupełnie nowe pliki nadal wymagają najpierw **Git Add (stage)**.
- Nagłówki kolumn *Git Status* i *Branch* są obecnie wyświetlane po angielsku nawet w innych językach interfejsu; wartości i okna dialogowe są zlokalizowane.
