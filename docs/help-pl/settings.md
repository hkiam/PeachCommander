---
title: Ustawienia
slug: settings
section: Dostosowywanie
order: 116
related: [appearance, keyboard-shortcuts]
---

Okno Ustawienia to miejsce, w którym dopasowujesz Peach Commander do sposobu, w jaki pracujesz: które paski się pojawiają, jak wyświetlane są pliki, jak zachowują się operacje kopiowania i usuwania, format archiwum używany przy pakowaniu, zachowanie kart, wartości domyślne FTP, język wyświetlania i więcej. Ustawienia są pogrupowane w strony, dzięki czemu szybko znajdziesz opcję, a każda zmiana jest automatycznie zapisywana w Twoim osobistym folderze konfiguracji.

## Otwórz Ustawienia

1. Wybierz **Peach Commander > Ustawienia…** lub naciśnij Cmd+, (przecinek).
2. To samo okno możesz otworzyć również z **Konfiguracja > Opcje…**.
3. Wybierz stronę z listy po lewej; opcje tej strony pojawiają się po prawej.
4. Dostosuj elementy sterujące. Zmiany wchodzą w życie od razu, chyba że uwaga na stronie mówi inaczej.

![Okno Ustawienia pokazujące stronę Układ z polami wyboru dla pasków interfejsu](screenshots/settings-layout.png)
*(Rysunek: strona Układ kontroluje, które paski są pokazywane wokół paneli.)*

## Strony

Okno ma następujące strony, w kolejności:

- **Układ** — pokaż lub ukryj pasek dysków, pasek kart, pasek ścieżki i pasek stanu.
- **Widok** — jak wymieniane są pliki i foldery, w tym format daty.
- **Ikony** — wygląd ikon na listach plików.
- **Obsługa** — ogólne zachowanie, jak to, co dzieje się, gdy piszesz w panelu (szybkie wyszukiwanie kontra wiersz poleceń).
- **Kolory** — niestandardowe kolory paneli, lub pozostaw je podążające za bieżącym motywem.
- **Potwierdzenie** — które akcje najpierw proszą o potwierdzenie, jak usuwanie.
- **Edycja/Podgląd** — czy zapis w edytorze zachowuje kopię zapasową `.bak`, programy używane do edycji i wyświetlania plików oraz skojarzenia według typu.
- **Kopiowanie/Usuwanie** — zachowaj metadane plików, użyj szybkiego klonowania, kopiuj tylko nowsze pliki, weryfikuj po kopiowaniu, wysyłaj usunięcia do Kosza i ustaw opcjonalny limit prędkości.
- **Zip/Pakowacz** — domyślny format archiwum i poziom kompresji używane przy pakowaniu.
- **Wtyczki** — włącz lub wyłącz zainstalowane wtyczki.
- **Karty** — jak otwierają się i zachowują karty folderów.
- **FTP** — wartości domyślne sieci, jak interwał keep-alive.
- **Klawiatura** — przejrzyj i zmień skróty klawiaturowe.
- **Język** — wybierz Domyślny systemowy, English lub Deutsch.
- **AI** — skonfiguruj asystenta AI: preferowany model, punkt końcowy i klucz chmury, autonomię oraz opcjonalny serwer MCP (zobacz [Asystent AI](ai-assistant.md)).
- **Różne** — otwórz folder konfiguracji w Finderze.

Włączone wtyczki mogą dodawać własne strony po wbudowanych — na przykład **Mapa dysku** i **System Monitor** — więc ich opcje żyją w tym samym oknie (zobacz [Wtyczki](plugins.md)).

![Okno Ustawienia pokazujące opcje strony Widok dla wyświetlania plików](screenshots/settings-display.png)
*(Rysunek: strona Widok kontroluje, jak wymieniane są pliki i foldery.)*

![Okno Ustawienia pokazujące stronę Obsługa](screenshots/settings-operation.png)
*(Rysunek: strona Obsługa rządzi szybkim wyszukiwaniem i zachowaniem myszy.)*

## Gdzie przechowywane są Twoje ustawienia

Twoja konfiguracja jest przechowywana w plikach zwykłego tekstu wewnątrz Twojego osobistego folderu Application Support, w `~/Library/Application Support/PeachCommander`. Aby go otworzyć, przejdź do strony **Różne** i kliknij **Otwórz folder konfiguracji**. Zapisane hasła FTP nie są przechowywane w tych plikach; są bezpiecznie przechowywane w pęku kluczy macOS.

Ustawienia są zapisywane w miarę ich zmiany. Możesz również wymusić zapis w dowolnej chwili za pomocą **Konfiguracja > Zapisz ustawienia** oraz zapisać bieżące położenie okna i układ paneli za pomocą **Konfiguracja > Zapisz położenie**.

## Przeniesienie ustawień z Total Commandera

Jeśli przechodzisz z Total Commandera na Windows, możesz zaimportować zapisane witryny FTP. Wybierz **Konfiguracja > Importuj wincmd.ini…** i wybierz swój plik konfiguracji FTP z Total Commandera. Twoje połączenia są dodawane do Peach Commandera w tej samej kolejności, w jakiej się tam pojawiały.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz Ustawienia | Cmd+, |

## Uwagi

- Strona **Język** oferuje Domyślny systemowy, English i Deutsch. Zmiana języka wchodzi w życie dopiero po ponownym uruchomieniu Peach Commandera.
- Kolory ustawione na stronie **Kolory** zastępują motyw; użyj tam **Przywróć domyślne**, aby wrócić do kolorów motywu.
- Peach Commander przechowuje swoje ustawienia tylko we własnym folderze konfiguracji, więc Twoje zmiany nigdy nie wpływają na inne aplikacje i można je łatwo utworzyć w kopii zapasowej, kopiując ten folder.
