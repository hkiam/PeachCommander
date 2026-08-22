---
title: Obrazy systemów plików
slug: filesystem-images
section: Wtyczki
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

## Oprogramowanie układowe bez tablicy partycji

Plik oprogramowania układowego wyciągnięty z routera lub kamery zwykle nie ma żadnej tablicy partycji. To nagłówek producenta, program rozruchowy, jądro i rootfs zapisane jeden po drugim pod przesunięciami, których nigdzie nie odnotowano. Taki plik otwiera się z jednym wpisem na każdą część, nazwanym od przesunięcia, w którym się zaczyna: `0x00230044-squashfs` to system plików, w który można wejść, a `0x00030040-kernel.uimage` plik do skopiowania na zewnątrz.

![Panel we wnętrzu pliku oprogramowania układowego routera: nagłówek producenta, jądro U-Boot i główny system plików SquashFS, każdy nazwany od przesunięcia, w którym się zaczyna](screenshots/filesystem-images-carved.png)

Części znajdowane są przez przeszukanie pliku w poszukiwaniu samych systemów plików i otwarcie każdego trafienia, by sprawdzić, czy naprawdę tam jest. Wzorzec bajtów pasujący przypadkiem kosztuje chwilę i zostaje odrzucony, zamiast stać się zmyślonym wpisem; a plik, w którym nie znaleziono żadnego systemu plików, nadal jest odrzucany i otwiera się tak, jak zawsze by się otworzył.

To samo dotyczy wszystkiego, co leży poza partycjami obrazu z tablicą partycji. Raspberry Pi trzyma swój program rozruchowy w megabajtach przed partycją 1, a U-Boot na większości płyt ARM siedzi pod stałym przesunięciem w tej samej nieprzydzielonej przestrzeni. Te odcinki są wypisane obok partycji, żeby można je było zobaczyć i skopiować.

## Zapisanie budowy

**Polecenia ▸ Analizuj budowę obrazu** zapisuje wynik jako plik tekstowy obok obrazu i ustawia na nim kursor: każdy obszar z przesunięciem, rozmiarem i tym, czym się okazał, a do tego tablica partycji, jeśli obraz ją ma. Zwykle to właśnie ta tabela jest potrzebna przy analizie albo w zgłoszeniu, a odtwarzanie jej przez chodzenie po panelu i przepisywanie liczb to żmudna praca.

Raport pokazuje też to, co panel pomija — na przykład małe przerwy wyrównania między partycjami — i podaje płytę, dla której zbudowano jądro U-Boot, jeśli obraz to odnotowuje.

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
- Obraz jest przeszukiwany pod kątem osadzonych systemów plików tylko wtedy, gdy nie ma ani tablicy partycji, ani systemu plików na początku, więc zwykły obraz otwiera się dokładnie tak samo szybko jak dotąd.
- Wtyczka dodaje jedno polecenie menu i żadnych własnych ustawień poza przełącznikiem, który ją włącza.
