---
title: Rozwiązywanie problemów
slug: troubleshooting
section: Pomoc i rozwiązywanie problemów
order: 140
related: [privacy-and-security, known-limitations]
---

Ten temat obejmuje problemy, na które ludzie natrafiają najczęściej: macOS blokujący dostęp do niektórych folderów, folder, który wydaje się utknięty na starej zawartości, bezpieczny serwer FTP, który odmawia połączenia, oraz pakowanie do RAR. Każda sekcja mówi, co się dzieje i jak to naprawić.

## macOS prosi o zezwolenie lub foldery wyglądają na puste

Niektóre lokalizacje — jak Twój folder `~/Library`, foldery innych użytkowników i obszary systemowe — są chronione przez macOS i pozostają ukryte, dopóki nie przyznasz dostępu. Peach Commander wykrywa, kiedy to się dzieje, i oferuje poprowadzenie Cię do właściwego ustawienia.

1. Gdy zostaniesz poproszony, wybierz otwarcie Ustawień systemowych, lub otwórz je sam.
2. Przejdź do Prywatność i bezpieczeństwo, a następnie Pełny dostęp do dysku.
3. Włącz przełącznik obok Peach Commandera. Jeśli nie jest wymieniony, użyj przycisku Dodaj, aby go dodać.
4. Zakończ i ponownie otwórz Peach Commander, aby nowe uprawnienie weszło w życie.

Peach Commander nie działa wewnątrz ograniczonej piaskownicy, więc po przyznaniu Pełnego dostępu do dysku może przeglądać i zarządzać plikami dokładnie jak Finder.

## Folder nie pokazuje ostatnich zmian

Panele normalnie aktualizują się same, gdy pliki zmieniają się na dysku. Jeśli folder został zmieniony przez inny program, znajduje się na woluminie sieciowym, lub po prostu wygląda na nieaktualny, odśwież go ręcznie.

1. Kliknij panel, który chcesz zaktualizować.
2. Naciśnij F2 (lub Ctrl+R), aby ponownie odczytać ten folder.

Woluminy sieciowe i zamontowane nie zawsze zgłaszają zmiany do macOS, więc ręczne odświeżenie jest tam niezawodnym rozwiązaniem.

## Serwer FTPS nie chce się połączyć

Jeśli bezpieczne połączenie FTP zawodzi, sprawdź te ustawienia w szczegółach połączenia:

- Dopasuj tryb bezpieczeństwa serwera: jawny FTPS (AUTH TLS) a niejawny FTPS (port 990) nie są zamienne.
- Jeśli połączenie zawiesza się po zalogowaniu, przełącz między pasywnym a aktywnym trybem transferu — większość serwerów za zaporą potrzebuje pasywnego.
- Jeśli serwer używa certyfikatu z podpisem własnym, musisz go wyraźnie zezwolić; w przeciwnym razie połączenie jest odrzucane.
- Potwierdź host, port, nazwę użytkownika i hasło oraz to, czy w Twojej sieci wymagany jest serwer proxy SOCKS5.

## Pakowanie do RAR nic nie robi

Peach Commander może samodzielnie tworzyć archiwa ZIP, 7z, TAR, TAR.GZ, BZ2 i XZ. RAR jest inny: ponieważ RAR to format własnościowy, tworzenie archiwów RAR wymaga oddzielnego narzędzia wiersza poleceń RAR zainstalowanego na Twoim Macu. Bez niego RAR jest niedostępny, gdy pakujesz pliki (Option+F5). Aby odczytać istniejące archiwa RAR, nadal możesz otwierać je jak folder. Jeśli nie potrzebujesz konkretnie RAR, wybierz zamiast tego ZIP lub 7z — oba obsługują silne szyfrowanie AES-256 i podzielone woluminy.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Odśwież aktywny folder | F2 lub Ctrl+R |
| Połącz się z serwerem FTP/FTPS | Ctrl+F |
| Zamontuj udział sieciowy | Cmd+K |
| Spakuj wybrane pliki | Option+F5 |

## Uwagi

- Hasła i inne dane uwierzytelniające są przechowywane tylko w pęku kluczy macOS, nigdy w plikach konfiguracji w postaci jawnej.
- Montowanie udziału sieciowego (Cmd+K, lub menu Sieć ▸ Zamontuj udział sieciowy…) używa tego samego połączenia, którego używa sam macOS, więc pojawi się również w Finderze.
- Jeśli problem utrzymuje się po odświeżeniu i ponownym uruchomieniu, może to być znane ograniczenie, a nie usterka — zobacz Znane ograniczenia.
