---
title: Znane ograniczenia
slug: known-limitations
section: Pomoc i rozwiązywanie problemów
order: 144
related: [troubleshooting]
---

Peach Commander robi wiele, ale kilka funkcji ma w bieżącej wersji szczere ograniczenia. Poznanie ich z wyprzedzeniem oszczędza zamieszania, gdy coś zachowuje się nieoczekiwanie. Ta strona wymienia bieżące ograniczenia oraz, gdzie to możliwe, proste obejście.

## Archiwa

- **Archiwów podzielonych (wieloczęściowych) nie można otworzyć.** Standardowy ZIP — w tym ZIP64, czyli ponad 65 535 elementów lub powyżej 4 GB — a także TAR i TAR skompresowany gzipem otwierają się bezpośrednio jako foldery. Archiwum rozłożone na kilka plików (`.z01`, `.zip.001`) nie jest obsługiwane: najpierw połącz części albo rozpakuj je narzędziem, które je utworzyło.
- **Zaszyfrowane archiwa ZIP** (zarówno starsze ZipCrypto, jak i WinZip AES) są obsługiwane do przeglądania, ale zostaniesz poproszony o hasło.
- Inne formaty, takie jak CPIO, ISO, CAB, LZH, XAR i PAX, otwierają się przez narzędzie pomocnicze, a nie natywny czytnik.

## Sieć (SFTP / SCP)

- **Zmiana atrybutów plików przez SFTP nie ma efektu w tej wersji.** Możesz przeglądać, pobierać i wysyłać przez SFTP/SCP, ale żądania zmiany uprawnień, własności lub znaczników czasu na serwerze zdalnym są po cichu ignorowane. Wprowadź te zmiany na samym serwerze lub przez inny protokół.
- Przy pierwszym połączeniu z serwerem SFTP zostaniesz poproszony o zaufanie jego kluczowi hosta. Peach Commander zapamiętuje go później (zaufanie przy pierwszym użyciu).

## Odświeżanie folderów

- **Na zmiany z zewnątrz obserwowane są tylko foldery na tym Macu.** Folder na tym Macu aktualizuje się sam, gdy tylko inny program utworzy, zmieni lub usunie w nim plik. Lokalizacja zdalna (FTP lub SFTP) ani wnętrze archiwum nie są obserwowane, ponieważ te protokoły nie dają możliwości powiadomienia — tam naciśnij F2 lub Ctrl+R, aby odczytać ponownie.

## Inne bieżące ograniczenia

- **Niektóre bardzo długie ścieżki bezwzględne** (głęboko zagnieżdżone foldery, których pełna ścieżka jest niezwykle długa) mogą nie być obsługiwane niezawodnie. Praca bliżej szczytu drzewa folderów pozwala tego uniknąć.
- **Ta wersja podglądowa nie jest podpisana.** Gatekeeper w macOS może ostrzec, że aplikacja pochodzi od niezidentyfikowanego dewelopera przy pierwszym otwarciu. Kliknij aplikację prawym przyciskiem i wybierz Otwórz, a następnie potwierdź, aby ją uruchomić. Automatyczne aktualizacje nie są jeszcze dostępne w tej wersji.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Odśwież aktywny panel | F2 lub Ctrl+R |
| Pobierz z adresu URL | Cmd+Shift+U |

## Uwagi

To są ograniczenia bieżącej wersji i oczekuje się, że poprawią się w późniejszych wydaniach. Jeśli napotkasz zachowanie nieopisane tutaj, zobacz temat rozwiązywania problemów.
