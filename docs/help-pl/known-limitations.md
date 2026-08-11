---
title: Znane ograniczenia
slug: known-limitations
section: Pomoc i rozwiązywanie problemów
order: 144
related: [troubleshooting]
---

Peach Commander robi wiele, ale kilka funkcji ma w bieżącej wersji szczere ograniczenia. Poznanie ich z wyprzedzeniem oszczędza zamieszania, gdy coś zachowuje się nieoczekiwanie. Ta strona wymienia bieżące ograniczenia oraz, gdzie to możliwe, proste obejście.

## Archiwa

- **Archiwa ZIP podzielone (wieloczęściowe) można otworzyć, ale muszą być wszystkie części.** Standardowy ZIP — w tym ZIP64, czyli ponad 65 535 elementów lub powyżej 4 GB — a także TAR i TAR skompresowany gzipem otwierają się bezpośrednio jako foldery. Archiwum rozłożone na kilka plików również się otworzy: naciśnij Enter na pliku `.zip` zestawu `.z01`, `.z02`, … albo na pliku `.001` zestawu `name.zip.001`. Wszystkie części muszą leżeć w tym samym folderze, a zestaw, w którym jednej brakuje, zostaje odrzucony, zamiast otworzyć się przeczytany do połowy. Podzielone archiwa TAR nie są objęte.
- **Zaszyfrowane archiwa ZIP** (zarówno starsze ZipCrypto, jak i WinZip AES) są obsługiwane do przeglądania, ale zostaniesz poproszony o hasło.
- Inne formaty, takie jak CPIO, ISO, CAB, LZH, XAR i PAX, otwierają się przez narzędzie pomocnicze, a nie natywny czytnik.

## Sieć (SFTP / SCP)

- **Przez SFTP można zmieniać uprawnienia i znaczniki czasu, właściciela nie.** Protokół przenosi właściciela i grupę tylko jako liczby i nie pozwala rozwiązać nazwy użytkownika, więc zmiana właściciela jest odrzucana, a nie odgadywana — podobnie jak flagi plików macOS, których po drugiej stronie nie ma. Przez zwykły FTP można ustawić tylko uprawnienia, opcjonalnym polecenim `SITE CHMOD`; serwer, który go nie oferuje, mówi to, zamiast udawać sukces.
- Przy pierwszym połączeniu z serwerem SFTP zostaniesz poproszony o zaufanie jego kluczowi hosta. Peach Commander zapamiętuje go później (zaufanie przy pierwszym użyciu).

## Odświeżanie folderów

- **Na zmiany z zewnątrz obserwowane są tylko foldery na tym Macu.** Folder na tym Macu aktualizuje się sam, gdy tylko inny program utworzy, zmieni lub usunie w nim plik. Lokalizacja zdalna (FTP lub SFTP) ani wnętrze archiwum nie są obserwowane, ponieważ te protokoły nie dają możliwości powiadomienia — tam naciśnij F2 lub Ctrl+R, aby odczytać ponownie.

## Inne bieżące ograniczenia

- **Bardzo długie ścieżki: przeglądanie działa, kopiowanie jeszcze nie.** macOS odrzuca jako argument wywołania każdą ścieżkę dłuższą niż 1024 bajty, a foldery zagnieżdżone aż tak głęboko się zdarzają. Wyświetlanie, otwieranie, zmiana nazwy, tworzenie i usuwanie do nich docierają; **F5 Kopiuj i F6 Przenieś jeszcze nie** i zgłaszają tam błąd. Praca bliżej szczytu drzewa folderów omija pozostały przypadek.
- **Ta wersja zapoznawcza nie jest podpisana.** Gatekeeper blokuje pierwsze uruchomienie, a sposób na jego dopuszczenie zależy od wersji macOS. W **macOS 15 Sequoia i nowszym**: kliknij dwukrotnie raz, zamknij ostrzeżenie, a potem przejdź do **Ustawień systemowych ▸ Prywatność i ochrona** i kliknij **Otwórz mimo to** — Apple usunęło w macOS 15 skrót przez kliknięcie prawym przyciskiem dla niepodpisanego oprogramowania, więc kliknięcie prawym przyciskiem już nie pomaga. W **macOS 13–14**: kliknij aplikację prawym przyciskiem, wybierz Otwórz i potwierdź. Automatyczne aktualizacje nie są jeszcze dostępne w tej wersji.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Odśwież aktywny panel | F2 lub Ctrl+R |
| Pobierz z adresu URL | Cmd+Shift+U |

## Uwagi

To są ograniczenia bieżącej wersji i oczekuje się, że poprawią się w późniejszych wydaniach. Jeśli napotkasz zachowanie nieopisane tutaj, zobacz temat rozwiązywania problemów.
