---
title: Podgląd plików, których nie ma na tym Macu
slug: remote-previews
section: Podgląd i edycja
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander pokazuje podgląd pliku pod kursorem w bocznym panelu informacji, w Quick View i jako miniatury w widoku galerii. Gdy tego pliku nie ma na dysku podłączonym do tego Maca, pokazanie go kosztuje coś realnego — pobranie, rozpakowanie albo jedno i drugie — a nikt o to nie prosił: kursor po prostu na niego najechał. Dlatego Peach Commander z góry ustala, ile podgląd może kosztować; ta strona wyjaśnia, co ustala i jak to zmienić.

## Pliki wewnątrz archiwum

Plik w archiwum można podejrzeć dokładnie tak samo jak plik poza nim. Peach Commander rozpakowuje go w tle do tymczasowej kopii i pokazuje tę kopię. To samo dotyczy Quick Look, otwierania w innym programie klawiszem Enter lub dwukrotnym kliknięciem oraz podmenu Otwórz w programie.

To, co dostaje inny program, jest kopią i jest tylko do odczytu: zmiany wprowadzone tam nie są zapisywane z powrotem do archiwum. Peach Commander mówi o tym za pierwszym razem, z polem pozwalającym przestać o tym mówić. Aby edytować plik znajdujący się w archiwum, najpierw rozpakuj go klawiszem F5 i pracuj na rozpakowanym pliku.

## Ile może kosztować podgląd

Podgląd podąża za kursorem, więc odbywa się bez proszenia. Dlatego obowiązuje limit zależny od tego, gdzie naprawdę znajduje się zawartość pliku:

- Na dysku podłączonym do tego Maca nie ma żadnego limitu, a podglądy działają dokładnie tak jak dotąd.
- W lokalizacji sieciowej — zamontowanym zasobie, FTP, SFTP, Amazon S3 lub dysku wtyczki — pliki są podglądane do 4 MB, dopóki Peach Commander nie zmierzy, jak szybkie naprawdę jest to połączenie. Potem dopuszcza wszystko, co da się odczytać w około półtorej sekundy, więc szybki zasób pokazuje duże pliki, a wolny odrzuca małe.
- W archiwum plik jest rozpakowywany do podglądu do 32 MB.
- Plik, którego usługa chmurowa jeszcze nie pobrała na tego Maca, nigdy nie jest pobierany tylko dlatego, że kursor na niego najechał.
- W formatach archiwów, które trzeba rozpakowywać plik po pliku — CPIO, ISO, CAB, LZH i podobne — nic nie jest podglądane automatycznie, bo każdy pojedynczy plik kosztuje pełne przejście przez archiwum.

Odrzucony podgląd to nie pusty panel: panel boczny pokazuje ikonę pliku, jego nazwę, rozmiar i datę oraz jeden wiersz z powodem. Quick Look pokaże go mimo to i nie podlega żadnemu z tych limitów.

## Zmiana limitów

1. Otwórz Ustawienia ▸ Edycja/Podgląd.
2. Wyłącz „Automatycznie podglądaj pliki w lokalizacjach sieciowych”, aby całkowicie zatrzymać podglądy sieciowe, albo ustaw „Pliki sieciowe do (MB)” na żądany rozmiar.
3. Włącz „Pobieraj pliki z chmury, aby je podejrzeć”, jeśli wolisz podgląd niż zaoszczędzony transfer.
4. Ustaw „Rozpakowuj z archiwów do (MB)”, aby określić, jak duży może być plik w archiwum.

Dwa kolejne ustawienia nie mają własnej kontrolki i znajdują się w `peachcmd.ini` w sekcji `[Preview]`: `AutoPreviewSeconds` to limit czasu obowiązujący po zmierzeniu połączenia (domyślnie 1,5; 0 go wyłącza), a `AutoPreviewLocalMB` to pułap dla dysków lokalnych (0 oznacza brak limitu).

## Gdzie trafiają rozpakowane kopie

Kopie są zapisywane w tymczasowym folderze systemu, a podglądy współdzielą je, zamiast każdy tworzyć własną. Kopia zrobiona na potrzeby podglądu jest usuwana po wyjściu z archiwum; kopia przekazana innemu programowi zostaje do zamknięcia Peach Commandera, bo ten program wciąż ma ją otwartą. To, co pozostawi nieoczekiwane zakończenie, jest rozpoznawane przy następnym uruchomieniu i wtedy usuwane.

Miniatury w widoku galerii podlegają temu samemu limitowi i tworzone są tylko komórki naprawdę widoczne na ekranie — folder z dwoma tysiącami plików kosztuje więc jeden ekran, a nie dwa tysiące. Pliki w archiwum również dostają prawdziwe miniatury; każdy jest do tego rozpakowywany, dlatego właśnie tam limit liczy się najbardziej.
