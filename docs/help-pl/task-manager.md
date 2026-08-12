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

Obok kolumny Data (czas uruchomienia) Task Manager dodaje kolumny procesów. Rozmiar wiersza procesu pokazuje `DIR`, ponieważ proces jest folderem, który można otworzyć (patrz niżej) — pamięć ma własne kolumny:

| Kolumna | Znaczenie |
| --- | --- |
| **PID** | Identyfikator procesu |
| **CPU %** | Ostatnie użycie procesora (pojawia się dopiero po drugim odświeżeniu) |
| **Memory** | Ślad pamięciowy — za co odpowiada ten proces (liczba pokazywana przez Monitor aktywności) |
| **Resident** | Rozmiar rezydentny, ze stronami współdzielonymi; wypełniany dla każdego procesu |
| **Threads** | Liczba wątków |
| **State** | R działający · S śpiący · T zatrzymany · Z zombie · I bezczynny, plus przyrostki dodawane przez `ps` (s = lider sesji, + = pierwszy plan, N = niski priorytet) |
| **User** | Właściciel |
| **PPID** | Identyfikator procesu nadrzędnego |
| **Read** | Bajty odczytane z dysku od uruchomienia procesu |
| **Written** | Bajty zapisane na dysku od uruchomienia procesu |
| **Wakeups** | Wybudzenia przerwaniami od uruchomienia procesu |
| **Signed** | Kto podpisał program: Apple, zespół z Developer ID, ad-hoc lub bez podpisu |
| **Command** | Pełny wiersz poleceń |

Sortuj według dowolnej kolumny (na przykład CPU % lub Rozmiar/pamięć) tak samo jak w zwykłym folderze.

## Zbadaj lub zakończ proces

- **Podgląd (F3)** pokazuje raport *Informacje o procesie*: nazwę, PID, proces nadrzędny, użytkownika, stan, wątki, pamięć, procesor, czas uruchomienia, ścieżkę pliku wykonywalnego i pełny wiersz poleceń.
- **Usuń (F8)** kończy proces. Pierwsze usunięcie wysyła łagodne **zakończenie** (SIGTERM); usunięcie po raz drugi procesu, który wciąż działa, eskaluje do **wymuszonego zakończenia** (SIGKILL). Wtyczka nigdy nie celuje w PID 1.

## Znajdowanie procesów używających pliku

Kliknij prawym przyciskiem myszy dowolny wiersz i wybierz **Znajdź procesy według pliku…**, a następnie wprowadź ścieżkę pliku. Każdy proces, który ma ten plik aktualnie otwarty, zostanie wyróżniony, a kursor przeskoczy do pierwszego, który może go zmienić:

- **Niebieski** — proces tylko czyta plik.
- **Pomarańczowy** — proces tylko do niego zapisuje.
- **Fioletowy** — proces robi jedno i drugie.

Ścieżka jest wstępnie wypełniana z kursora w drugim panelu, więc możesz wskazać plik tam i zapytać bez pisania. **Znajdź proces według portu…** w tym samym menu odpowiada na bliźniacze pytanie: który proces nasłuchuje na porcie TCP/UDP. Wybierz **Wyczyść wyróżnienie pliku**, aby usunąć kolory; opuszczenie listy procesów również je usuwa.

## Otwórz proces, aby zobaczyć jego pliki

Naciśnij Enter na procesie — albo kliknij go dwukrotnie — a panel wypisze pliki, które ten proces ma w tej chwili otwarte, jako zwykłe wiersze plików z prawdziwym rozmiarem i datą. Stamtąd:

- **Podgląd (F3)** otwiera sam plik.
- **Przejdź do pliku** pokazuje go w drugim panelu, gdzie możesz z nim pracować.
- **Pokaż w Finderze** przekazuje go Finderowi.

Liczą się tylko otwarte pliki: biblioteka, którą proces jedynie odwzorował w pamięci, ani jego katalog roboczy nie są otwartymi plikami. Proces innego użytkownika pokazuje pusty folder.

## Uwagi

- Podstawowe dane (PID, rodzic, użytkownik, stan, podpis) są czytelne dla każdego procesu. Ślad pamięciowy, wątki, we/wy dysku i lista otwartych plików są czytelne dla **Twoich własnych** procesów, co na zwykłym Macu stanowi większość listy. Dla procesów innych użytkowników CPU i Resident są wypełniane z `ps` — średnia z całego życia procesu zamiast różnicy dwóch pomiarów, którą niosą pozostałe wiersze — a wątki i ślad pozostają puste.
- CPU % to zmiana między dwiema próbkami, więc jest puste, dopóki panel nie odświeży się po raz drugi (panel odświeża się mniej więcej co dwie sekundy).
- Lista jest tylko do odczytu, poza kończeniem procesu — nie możesz kopiować do niej plików.
- Kolory wyróżnienia zależą od motywu kolorów: paleta Norton używa zamiast tego zieleni, czerwieni i magenty.
- Znajdowane są tylko uchwyty, w które Twoje konto może zajrzeć, co w praktyce oznacza Twoje własne procesy. Biblioteka, którą proces jedynie odwzorował w pamięci, ani jego katalog roboczy nie są otwartym uchwytem i nie są zgłaszane.
- Kolumna **Signed** wypełnia się przez pierwsze sekundy: odczyt podpisu trwa około milisekundy, a różnych programów są setki, więc przy każdym odświeżeniu odczytywanych jest kilka i potem zapamiętywanych. Pusta komórka znaczy „jeszcze nieodczytany”, a nie „bez podpisu”.
- **Signed** mówi, kto podpisał program, a nie czy jest notaryzowany: sprawdzenie notaryzacji oznacza policzenie skrótu całego programu, co dla każdego zajęłoby sekundy.
- Szybki filtr (Ctrl+S) trafia tu również w kolumny, nie tylko w nazwę, a wyrażenie może wskazać kolumnę, której dotyczy: `user:root state:R` pyta, co właśnie uruchamia root. Wyrażenia rozdziela się spacjami i wszystkie muszą pasować; tekst, który nie wskazuje kolumny, pozostaje jednym zwykłym podciągiem, ze spacjami włącznie.
