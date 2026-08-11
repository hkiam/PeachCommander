---
title: Serwery WebDAV
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Serwer WebDAV — Nextcloud, ownCloud, Synology, uczelniany magazyn plików — można przeglądać w panelu jak każdy folder. Wybierz **Połącz przez WebDAV…** z menu Sieć, podaj URL, a serwer pojawi się w aktywnym panelu.

To wtyczka: możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Łączenie

URL to kolekcja, w której chcesz wylądować, z twoją nazwą użytkownika przed hostem:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

O hasło pyta się osobno i trafia ono przez program do **pęku kluczy**, nigdy do pliku konfiguracyjnego. Zostaw je puste przy kolejnym połączeniu, a zostanie użyte zapisane.

Każdy URL, z którym się łączysz, jest zapamiętywany — ostatnich trzydzieści, najnowszy pierwszy — i proponowany następnym razem w menu rozwijanym. Ta lista leży w `~/Library/Application Support/PeachCommander/webdav/sites.json` i zawiera **wyłącznie adresy URL**; hasło nigdy nie jest tam zapisywane.

## Używaj https

Uwierzytelnianie to HTTP Basic, co oznacza, że twoja nazwa użytkownika i hasło podróżują zakodowane w base64 — zakodowane, nie zaszyfrowane. Przez `https://` chroni je połączenie. Przez `http://` są praktycznie jawne i wszystko między tobą a serwerem może je odczytać. Samo `http://` jest akceptowane, bo serwer na własnym komputerze albo w zamkniętej sieci laboratoryjnej to uzasadniony przypadek — dobrym ustawieniem domyślnym nie jest.

## Co możesz robić

Wyświetlanie, odczyt, zapis, tworzenie folderów, usuwanie, zmiana nazwy i przenoszenie działają — odpowiadają czasownikom WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` i `MOVE`. Panel na serwerze WebDAV zachowuje się więc w codziennej pracy jak panel na dysku.

## Czego się spodziewać

**Transfery obejmują cały plik.** Plik jest pobierany lub wysyłany w jednym kawałku; nie ma transferu zakresowego, więc przerwany transfer dużego pliku zaczyna się od nowa, zamiast być wznowiony.

**Kopiowanie w obrębie serwera idzie przez twojego Maca.** Wtyczka nie używa czasownika `COPY`, więc powielenie pliku na serwerze pobiera go i wysyła z powrotem. Na wolnym łączu przeniesienie — które serwer wykonuje sam — jest znacznie szybsze niż kopiowanie.

**Nic nie jest blokowane.** `LOCK` z WebDAV nie jest używany, więc gdy dwie osoby piszą ten sam plik jednocześnie, rozstrzyga ta, która zapisze jako ostatnia — dokładnie jak na udziale sieciowym bez blokad.

**Tylko uwierzytelnianie Basic.** Serwery wymagające Digest, tokenu bearer albo logowania jednokrotnego odrzucą połączenie. Wiele z nich oferuje zamiast tego hasło dla konkretnej aplikacji, a takie tutaj działa.
