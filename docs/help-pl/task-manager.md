---
title: Task Manager
slug: task-manager
section: Wtyczki
order: 125
related: [plugins, viewing-files, deleting-files]
---

Wtyczka Task Manager zamienia procesy działające na Twoim Macu w folder, który możesz przeglądać. Pojawia się jako dysk **TaskManager** na pasku dysków; otwórz go, a każdy proces jest wierszem, który możesz sortować, badać jak plik lub zakończyć — używając tych samych klawiszy, których już używasz do plików. Jest to wtyczka, więc możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Otwórz

1. Kliknij pozycję **📊 TaskManager** na pasku dysków (znajduje się tuż za Twoim dyskiem startowym).
2. Panel wypełnia się jednym wierszem na każdy działający proces. Nazwą każdego wiersza jest nazwa procesu, po której następuje jego PID, na przykład `Finder (462)`.
3. Przycisk **TaskManager** pozostaje wybrany, dopóki w nim jesteś, a karta nosi nazwę napędu. Przełącz się na inną kartę i wróć — albo zamknij i ponownie otwórz aplikację — a karta znów pokaże listę procesów. Aby ją opuścić, przejdź o poziom wyżej lub kliknij inny wolumin na pasku napędów.

![Task Manager wymieniający działające procesy z kolumnami PID, CPU, pamięci i polecenia](screenshots/task-manager.png)
*(Rysunek: działające procesy pokazane jako lista plików, którą możesz sortować i na której możesz działać.)*

## Co oznacza każda kolumna

Obok zwykłych kolumn Rozmiar (pamięć) i Data (czas uruchomienia) Task Manager dodaje kolumny procesów:

| Kolumna | Znaczenie |
| --- | --- |
| **PID** | Identyfikator procesu |
| **CPU %** | Ostatnie użycie procesora (pojawia się dopiero po drugim odświeżeniu) |
| **Threads** | Liczba wątków |
| **State** | R działający · S śpiący · T zatrzymany · Z zombie · I bezczynny |
| **User** | Właściciel |
| **PPID** | Identyfikator procesu nadrzędnego |
| **Command** | Pełny wiersz poleceń |

Sortuj według dowolnej kolumny (na przykład CPU % lub Rozmiar/pamięć) tak samo jak w zwykłym folderze.

## Zbadaj lub zakończ proces

- **Podgląd (F3)** pokazuje raport *Informacje o procesie*: nazwę, PID, proces nadrzędny, użytkownika, stan, wątki, pamięć, procesor, czas uruchomienia, ścieżkę pliku wykonywalnego i pełny wiersz poleceń.
- **Usuń (F8)** kończy proces. Pierwsze usunięcie wysyła łagodne **zakończenie** (SIGTERM); usunięcie po raz drugi procesu, który wciąż działa, eskaluje do **wymuszonego zakończenia** (SIGKILL). Wtyczka nigdy nie celuje w PID 1.

## Uwagi

- Podstawowe szczegóły (PID, proces nadrzędny, użytkownik, stan) są odczytywalne dla każdego procesu, jak w `ps`. Pamięć, wątki i procesor można odczytać tylko dla **Twoich własnych** procesów; inne procesy pokazują te kolumny puste (wymagają podwyższonych uprawnień, co zostanie dodane później).
- CPU % to zmiana między dwiema próbkami, więc jest puste, dopóki panel nie odświeży się po raz drugi (panel odświeża się mniej więcej co dwie sekundy).
- Lista jest tylko do odczytu, poza kończeniem procesu — nie możesz kopiować do niej plików.
