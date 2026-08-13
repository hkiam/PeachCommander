---
title: Transfery w tle
slug: background-transfers
section: Pliki i foldery
order: 32
related: [copying-files, downloading-from-url]
---

Duże kopiowania, przenoszenia, usuwania i pobierania nie muszą wstrzymywać Twojej pracy. Peach Commander może uruchamiać je w tle i zbierać wszystkie w jednym miejscu: w Menedżerze transferów w tle. Stamtąd obserwujesz postęp i prędkość transferu każdego zadania, wstrzymujesz je lub wznawiasz, anulujesz albo ustawiasz zadania w kolejce do późniejszego uruchomienia. Ponieważ zadanie w tle działa samodzielnie, nigdy nie powstrzymuje Cię od przeglądania, otwierania plików czy rozpoczynania kolejnego transferu.

## Jak to zrobić

1. Rozpocznij kopiowanie, przenoszenie, usuwanie lub pobieranie i wybierz uruchomienie w tle. Zadanie pojawia się w Menedżerze transferów w tle.
2. Otwórz menedżera w dowolnej chwili z menu **Polecenia ▸ Menedżer transferów w tle…** (lub naciśnij Cmd+Shift+B).
3. Każde zadanie pokazuje tytuł, pasek postępu oraz wiersz na żywo z liczbą wykonanych plików, przesłanych bajtów i bieżącą prędkością.
4. Użyj przycisków przy zadaniu, aby **Wstrzymać**, **Wznowić** lub **Anulować** w trakcie działania zadania.
5. Trwające zadanie ma też menu prędkości. Wybierz limit — 1, 5 lub 20 MB/s albo pełną prędkość — aby usunąć jeden transfer z drogi innemu, nie spowalniając pozostałych. Działa od razu; **Domyślne** zwraca zadanie do limitu ustawionego w Konfiguracji.
6. W przypadku zadań dodanych, ale jeszcze nieuruchomionych (wstrzymanych), kliknij **Uruchom** przy zadaniu lub **Uruchom wszystkie**, aby ruszyć całą listę oczekujących. Przyciskami **▲** i **▼** przesuniesz oczekujące zadanie wcześniej lub później w kolejce; pojawiają się tylko tam, gdzie przesunięcie jest możliwe, więc oczekujące zadanie nigdy nie wyprzedzi transferu już trwającego.
7. Gdy wszystko, na czym Ci zależy, zostanie ukończone, kliknij **Wyczyść ukończone**, aby uporządkować listę.

![Menedżer transferów w tle z listą aktywnych i oczekujących zadań, paskami postępu oraz przyciskami Wstrzymaj, Wznów i Anuluj.](screenshots/transfer-manager.png)

*Każdy transfer to wiersz, który możesz niezależnie wstrzymać, wznowić lub anulować.*

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz Menedżera transferów w tle | Cmd+Shift+B |

## Wskazówki

- **Ogranicz prędkość.** Aby duży transfer nie wysycił Twojego połączenia lub dysku, ustaw ograniczenie prędkości w oknie dialogowym kopiowania, zanim rozpoczniesz zadanie. Menedżer pokaże wtedy na żywo ograniczoną prędkość.
- **Kolejkuj na później.** Zadania wstrzymane siedzą na liście, nie działając, dopóki nie naciśniesz Rozpocznij (lub Rozpocznij wszystkie), więc możesz przygotować kilka transferów i uruchomić je razem.
- **Uruchamiaj kilka naraz.** Zadania działają niezależnie, więc możesz wstrzymać jedno, podczas gdy inne działa dalej.

## Uwagi

Ponieważ zadanie w tle działa bez Twojego nadzoru, nie może się zatrzymać, aby zadać pytania. Jeśli w miejscu docelowym plik już istnieje, zadanie w tle nadpisuje go; jeśli poszczególnego elementu nie da się przesłać, ten element jest pomijany, a zadanie działa dalej. Gdy zadanie się kończy, wszystkie pominięte elementy są zbierane w dzienniku błędów, abyś mógł dokładnie sprawdzić, co poszło nie tak.
