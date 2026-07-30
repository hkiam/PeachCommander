---
title: Praca z archiwami
slug: archives
section: Archiwa
order: 80
related: [copying-files]
---

Peach Commander traktuje archiwa jak foldery. Możesz wejść do archiwum ZIP, TAR lub innego obsługiwanego formatu, przeglądać jego zawartość i kopiować z niego pliki — wszystko bez wcześniejszego rozpakowywania na dysk. Gdy chcesz utworzyć archiwum, polecenie Spakuj łączy Twój wybór w formacie ZIP, 7z, TAR lub innym, z opcjonalnym szyfrowaniem i podzielonymi woluminami. Jest to przydatne do pakowania plików do wysłania, zmniejszania folderu do przechowywania lub zajrzenia do pobranego pliku, zanim zdecydujesz się go wypakować.

## Przeglądaj archiwum jak folder

1. W panelu przesuń kursor na plik archiwum (na przykład `.zip` lub `.tar.gz`).
2. Naciśnij Enter lub Ctrl+PageDown, aby wejść do środka, tak jak otworzyłbyś folder.
3. Poruszaj się po zawartości normalnie. Naciśnij Backspace lub Ctrl+PageUp, aby wyjść i opuścić archiwum.
4. Aby wyciągnąć pliki, zaznacz je i skopiuj (F5) do drugiego panelu.

![Przeglądanie wnętrza archiwum tak, jakby było folderem](screenshots/archive-browse.png)
*(Rysunek: otwarte archiwum pokazane jako zwykła lista folderu, z plikami gotowymi do skopiowania.)*

ZIP, TAR i TAR skompresowany gzipem są odczytywane bezpośrednio. Inne formaty, takie jak CPIO, ISO, CAB, LZH, XAR i PAX, są odczytywane za pomocą wbudowanych narzędzi systemowych. Zaszyfrowane archiwa ZIP (zarówno klasyczne, jak i AES) można otworzyć po podaniu hasła.

## Spakuj pliki do nowego archiwum

1. Zaznacz pliki i foldery, które chcesz uwzględnić, w aktywnym panelu.
2. Wybierz Plik ▸ Spakuj… lub naciśnij Alt+F5. (Aby spakować, a następnie usunąć oryginały, użyj Alt+Shift+F5.)
3. W oknie dialogowym wybierz format archiwum (ZIP, 7z, TAR, tar.gz, bzip2, xz lub RAR), poziom kompresji i miejsce zapisu.
4. Opcjonalnie włącz szyfrowanie AES-256 i ustaw hasło lub podziel archiwum na woluminy o stałym rozmiarze.
5. Potwierdź, aby utworzyć archiwum.

![Okno dialogowe Spakuj pokazujące format, kompresję, szyfrowanie i opcje podziału](screenshots/pack-dialog.png)
*(Rysunek: okno dialogowe Spakuj, w którym wybierasz format i ustawiasz opcje szyfrowania i podziału na woluminy.)*

## Rozpakuj lub przetestuj archiwum

1. Umieść archiwum do wypakowania w aktywnym panelu, a folder docelowy w drugim panelu.
2. Wybierz Plik ▸ Rozpakuj… lub naciśnij Alt+F9, a następnie potwierdź miejsce docelowe.
3. Aby sprawdzić archiwum pod kątem uszkodzeń bez wypakowywania, wybierz Plik ▸ Testuj archiwum.

## Edytuj ZIP w miejscu

Możesz dodawać lub usuwać pliki wewnątrz istniejącego archiwum ZIP bez jego rozpakowywania. Otwórz ZIP jak folder, a następnie kopiuj do niego pliki lub usuwaj pliki jak zwykle — zmiana jest zapisywana bezpośrednio z powrotem do archiwum.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Wejdź do archiwum pod kursorem | Enter lub Ctrl+PageDown |
| Opuść archiwum (przejdź wyżej) | Backspace lub Ctrl+PageUp |
| Spakuj | Alt+F5 |
| Spakuj i usuń oryginały | Alt+Shift+F5 |
| Rozpakuj | Alt+F9 |

## Uwagi

- Pakowanie do 7z, xz, bzip2 i RAR opiera się na narzędziach zewnętrznych. RAR w szczególności wymaga zainstalowania własnościowego programu RAR; bez niego ten format jest niedostępny.
- Edycja ZIP w miejscu przepisuje całe archiwum, więc daty modyfikacji plików w jego wnętrzu nie są zachowywane.
- Bardzo duże pojedyncze elementy są ograniczone do 512 MiB podczas wypakowywania. Wypakowywanie można anulować w trakcie działania.
- Bardzo duże archiwa (ZIP64) nie są obsługiwane.
