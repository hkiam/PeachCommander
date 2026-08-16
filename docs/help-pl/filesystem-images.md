---
title: Obrazy systemów plików
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Obraz systemu plików to plik zawierający cały system plików — rootfs z aktualizacji routera, kartę SD skopiowaną bajt po bajcie, obraz urządzenia, które badasz. Wtyczka **Linux Filesystem Images** otwiera taki plik tak, jak Peach Commander otwiera archiwum: ustaw na nim kursor, naciśnij Enter, a panel znajdzie się wewnątrz systemu plików. Stamtąd podgląd, wyszukiwanie i kopiowanie działają dokładnie jak w folderze.

Do obrazu nigdy nic nie jest zapisywane. Wtyczka potrafi wyłącznie czytać.

## Najpierw ją włącz

Wtyczka jest dostarczana wyłączona. Otwórz **Ustawienia ▸ Wtyczki**, znajdź **Linux Filesystem Images** i włącz ją.

Domyślnie jest wyłączona ze względu na sposób, w jaki znajduje obrazy. Oprogramowanie układowe rzadko ma porządną nazwę — szukany plik nazywa się `firmware.bin`, `rootfs.img` albo po prostu `dump` co najmniej tak często jak `.squashfs` — więc gdy rozszerzenie nic nie mówi, wtyczka zagląda w pierwsze bajty. To dokładnie to, czego trzeba przy badaniu obrazów urządzeń, i zbędna praca w przeciwnym razie. Włączenie jej to sposób, by powiedzieć, który z tych dwóch przypadków dotyczy ciebie.

Plik, który okaże się nie być obrazem, po tym jednym spojrzeniu zostaje nietknięty i otwiera się tak, jak zawsze.

## Co potrafi otworzyć

| Format | Gdzie go spotkasz |
|---|---|
| SquashFS | Rootfs w niemal każdym oprogramowaniu routerów, kamer i dekoderów |
| ext2, ext3, ext4 | Główna partycja większości wbudowanych urządzeń z Linuksem |
| Btrfs | Wolumeny NAS i nowsze systemy Linux, wraz z migawkami |
| JFFS2, UBIFS | Surowa pamięć flash w starszym i obecnym sprzęcie wbudowanym |
| cramfs, initramfs | Rozruchowe systemy plików i długowieczne starsze urządzenia |
| FAT12, FAT16, FAT32 | Karty SD, pendrive'y i partycja EFI każdego współczesnego komputera |
| exFAT | Karty SD i nośniki powyżej 32 GB |
| NTFS | Wolumeny Windows, także z plikami skompresowanymi |

## Obrazy dysków z wieloma partycjami

Obraz skopiowany z całego urządzenia zwykle zawiera tablicę partycji, a nie pojedynczy system plików. Taki obraz otwiera się jako jeden folder na partycję — `1-rootfs`, `2-esp` — i wchodzisz do tej, którą chcesz. Odczytywane są zarówno tablice MBR, jak i GPT, a tam, gdzie tablica zawiera nazwy partycji, używane są te nazwy.

Partycja, której wtyczka nie potrafi odczytać, i tak się pojawia — jako pusty folder nazwany według swojego typu. Jeśli urządzenie ma trzy partycje, powinieneś móc zobaczyć, że ma trzy.

## Praca wewnątrz obrazu

Obowiązuje wszystko, co już znasz. F3 pokazuje plik, F5 kopiuje pliki do prawdziwego folderu, a **Znajdź pliki** przeszukuje zawartość obrazu. Wychodzi się z niego tak, jak z archiwum.

Dowiązania symboliczne są pokazywane z nazwą, a skopiowanie takiego na zewnątrz daje mały plik tekstowy z celem dowiązania zamiast prawdziwego dowiązania — obrazowi nie wolno pozwolić umieścić dowiązania wskazującego gdziekolwiek na twoim własnym dysku.

## Gdy obraz się nie otwiera

Wtyczka mówi dlaczego, zamiast zgłaszać uszkodzony plik, bo te dwie rzeczy prowadzą w różne miejsca:

- **Wolumen Btrfs w RAID0, RAID10, RAID5 lub RAID6**, albo rozłożony na kilka urządzeń. Dane są rozproszone po dyskach, a większości nie ma w pliku, który masz.
- **Surowy zrzut NAND wciąż zawierający obszar zapasowy.** Z obrazem wszystko w porządku; skopiowano go razem z bajtami korekcji błędów. Skopiuj go ponownie poleceniem `nanddump --omitoob`.
- **Zaszyfrowany wolumen ext4 lub NTFS**, którego nie da się odczytać bez kluczy.
- **System plików ext odłączony nieczysto** nadal się otwiera, ale z oznaczonym wpisem na górze katalogu głównego ostrzegającym, że zawartość może być nieaktualna. System plików skopiowano w trakcie użytkowania, a najnowsze zmiany są w dzienniku, którego ta wtyczka nie odtwarza. Uruchom `e2fsck` na kopii, jeśli szczegóły mają znaczenie.

## Uwagi

- Obraz jest czytany raz i zapamiętywany, więc ponowne wejście do niego jest natychmiastowe.
- Bardzo duże obrazy są czytane w miarę potrzeb zamiast wczytywane w całości; lista jest ograniczona do dwóch milionów wpisów.
- Wtyczka nie dodaje żadnych poleceń menu ani własnych ustawień poza przełącznikiem, który ją włącza.
