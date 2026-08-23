---
title: Amazon S3 i magazyny zgodne z S3
slug: amazon-s3
section: Wtyczki
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Bucket S3 można przeglądać w panelu jak każdy folder. Wybierz **Połącz z Amazon S3…** z menu Sieć, podaj punkt końcowy i klucze, a magazyn pojawi się w aktywnym panelu — z **listą bucketów jako najwyższym poziomem**, a każdy bucket będzie zwykłym katalogiem poniżej.

Działa z Amazon S3 i ze wszystkim, co mówi tym samym protokołem: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 i DigitalOcean Spaces są dostępne.

To wtyczka, więc możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Łączenie

Menu **Usługa** wypełnia dwa ustawienia, których nie da się odgadnąć — czy używać HTTPS i czy punkt końcowy wymaga adresowania w stylu ścieżki — a sam punkt końcowy pozostawia tobie, bo zwykle zależy od konta. Oba te ustawienia zawodzą w sposób wyglądający na coś innego: adresowanie przez nazwę hosta wobec zwykłego adresu IP to błąd rozwiązywania nazw, a adresowanie w stylu ścieżki wobec Amazona to „nie ma takiego bucketa”, co czyta się jak brakujący bucket.

**Tajny klucz dostępu** trafia przez program nadrzędny do **Pęku kluczy**, nigdy do pliku konfiguracyjnego. Zostaw pole puste przy następnym połączeniu i zostanie użyty zapisany.

**Zapamiętaj to połączenie** zachowuje punkt końcowy, region, identyfikator klucza i sposób adresowania — nigdy tajny klucz — w `~/Library/Application Support/PeachCommander/s3/profiles.json`. Zapamiętane połączenie staje się też przyciskiem na pasku napędów, a klik na nim łączy bezpośrednio, bez ponownego otwierania tego okna.

### Profile, które już masz

Jeśli używasz wiersza poleceń AWS, jego profile są proponowane w menu **Nazwa** z oznaczeniem *(AWS CLI)*, czytane z `~/.aws/credentials` i `~/.aws/config` — wraz z regionem, tokenem sesji i `s3.addressing_style`. Nic nie jest tam zapisywane, a taki profil **nie** jest zapamiętywany domyślnie: trzymanie drugiej kopii tajnego klucza to coś, o co się prosi, a nie coś, co dzieje się dlatego, że wybrano nazwę z menu.

### Publiczne buckety

**Połącz anonimowo** nie wysyła żadnego podpisu, czego oczekuje bucket czytelny publicznie. Jeśli bucket nie jest publiczny, dowiesz się właśnie tego — a nie że klucz został odrzucony. Klucza nie było.

## Co można zrobić

Listowanie, czytanie, zapis, tworzenie folderów i bucketów, usuwanie, zmiana nazwy i przenoszenie działają. Kopiowanie i przenoszenie odbywa się **na serwerze**: bajty nie przechodzą przez twojego Maca.

Folder w S3 nie jest niczym rzeczywistym — to albo wspólny przedrostek kluczy pod nim, albo obiekt o zerowej długości, którego nazwa kończy się na `/`. Oba są pokazywane jako foldery. Utworzenie takiego zapisuje ten znacznik; usunięcie usuwa każdy obiekt poniżej, bo nie ma nic innego do usunięcia.

Na najwyższym poziomie **Nowy folder tworzy bucket** — ten poziom *jest* listą bucketów, nic innego nie mogłoby tam znaczyć.

**Klasa magazynu** i **ETag** są dostępne jako kolumny panelu (prawy klik na nagłówku). Oba pochodzą z listy, która już się odbyła, więc nic nie kosztują.

## Czego można się spodziewać

**Bucketa nie da się przemianować.** S3 nie ma takiej operacji, a alternatywa — skopiowanie każdego obiektu do nowego bucketa i usunięcie starego — nie jest tym, o co prosiło okno zmiany nazwy. Jest to odmawiane, nie udawane.

**Transfery obejmują całe pliki.** Plik jest pobierany lub wysyłany w jednym kawałku; przerwany transfer zaczyna się od nowa, a nie wznawia. Duże wysyłki są automatycznie dzielone na części; jeśli część zawiedzie, części są sprzątane, a nie zostawiane do zapłaty.

**Zmiana nazwy folderu nie jest atomowa.** Kopiuje i usuwa obiekt po obiekcie i zatrzymuje się na pierwszym błędzie, zamiast przechodzić w stan przeniesiony do połowy.

**Zarchiwizowanych obiektów nie da się czytać wprost.** Obiekt w Glacier lub Deep Archive trzeba najpierw przywrócić, w konsoli AWS albo przez CLI. Panel to mówi, zamiast zawodzić tak, jakby obiekt był uszkodzony.

**Listowanie bardzo dużego folderu trwa tyle, ile trwa u serwera.** Obiekty przychodzą po tysiąc, a panel zapełnia się, gdy dotrze ostatnia strona.

**Każde żądanie kosztuje w usłudze płatnej.** Wtyczka jest napisana tak, by pytać jak najmniej — kolumny pochodzą z listy, która już się odbyła, region bucketa jest poznawany raz i pamiętany — ale przeglądanie bucketa nie jest darmowe tak jak przeglądanie dysku.
