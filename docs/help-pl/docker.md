---
title: Kontenery i wolumeny Dockera
slug: docker
section: Wtyczki
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

System plików kontenera Dockera można przeglądać w panelu jak każdy folder, a wolumen Dockera tak samo. Wybierz **Połącz z Dockerem…** z menu Sieć albo kliknij przycisk **Docker** na pasku napędów, a silnik pojawi się w aktywnym panelu.

To wtyczka i **jest dostarczana wyłączona**. Włącz ją w **Konfiguracja ▸ Wtyczki…**. Startuje wyłączona, ponieważ połączenie z demonem Dockera ma na Twoim Macu te same uprawnienia co Ty — zobacz *Do czego ma dostęp* poniżej.

## Co widzisz

Najwyższy poziom to trzy foldery:

- **Compose Projects** — wszystkie kontenery uruchomione przez Docker Compose, pogrupowane według projektu, a następnie usługi. Usługa z jednym kontenerem *jest* tym kontenerem: `my-stack/backend/etc` to `/etc` backendu. Usługa z kilkoma zachowuje dla nich poziom, jeden folder na kontener.
- **Standalone Containers** — cała reszta, działająca lub nie.
- **Volumes** — każdy wolumen Dockera, jako osobny napęd.

Poniżej znajdujesz się w prawdziwym systemie plików: F3 podgląda plik, F4 go edytuje, F5 kopiuje do drugiego panelu, F7 tworzy folder. Drugi panel może być czymkolwiek — folderem lokalnym, archiwum, zasobnikiem S3.

Grupowanie odczytywane jest z etykiet, które Compose nadaje własnym kontenerom i wolumenom, jest więc poprawne nawet dla stosu, którego `docker-compose.yml` dawno zniknął z tej maszyny.

**Wolumeny są wymienione osobno celowo.** Wolumen przeżywa kontener, który go utworzył, może być współdzielony przez wiele kontenerów i zwykle to w nim naprawdę są dane, po które przyszedłeś. Wolumen, którego nic obecnie nie montuje, nadal można przeglądać.

## Kolumny

Kliknij prawym przyciskiem nagłówek kolumny panelu, aby dodać własne kolumny dostawcy:

- **Stan** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Dostęp** — `RW`, `RO` dla systemu plików lub montowania tylko do odczytu, `VOL` dla wolumenu Dockera, `BIND` dla Twojego folderu zamontowanego w kontenerze, `TMP` dla tmpfs.
- **Obraz**, **ID**.
- **Montowanie** — na katalogu, który w rzeczywistości jest montowaniem: czym jest. `Volume: my-stack_db-data` albo ścieżka hosta za montowaniem bind. Tak znajdziesz, który wolumen w **Volumes** zawiera dane kontenera.

## Zatrzymane kontenery

Zatrzymane kontenery są wymieniane, a ich systemy plików można czytać i zapisywać. Plikowe API Dockera odpowiada również dla kontenera, który nie działał od miesiąca, i to właśnie sprawia, że przypomina to napęd, a nie listę procesów.

Dwie rzeczy wymagają naprawdę działającego kontenera: **usuwanie** i **zmiana nazwy**. API silnika Dockera nie ma operacji dla żadnej z nich — jedynym sposobem usunięcia lub przeniesienia pliku wewnątrz kontenera jest uruchomienie w nim czegoś — więc w zatrzymanym kontenerze obie są odrzucane zamiast udawane.

## Czego się spodziewać

**Zapisy trafiają do środka jako `root`, usuwanie działa jako własny użytkownik kontenera.** To układ Dockera, a nie decyzja podjęta tutaj: skopiowanie pliku do środka korzysta z archiwalnego API silnika, które zapisuje jako root; usunięcie lub zmiana nazwy uruchamia polecenie wewnątrz kontenera, działające jako użytkownik ustawiony przez obraz. Usunięcie może więc zostać odrzucone jako *brak uprawnień* dla pliku, który chwilę wcześniej udało się skopiować. Peach Commander nie obchodzi tego, działając jako root — mówi Ci, co powiedział kontener.

**Kontener lub montowanie tylko do odczytu odmawia zapisu** i zgłasza to jako błąd uprawnień, a nie jako niepowodzenie.

**Odczyt dowiązania symbolicznego czyta to, na co ono wskazuje.** Panel nadal pokazuje je jako dowiązanie w kolumnie Attr; F3 pokazuje treść celu, a nie pusty plik.

**Katalogu głównego dużego zatrzymanego kontenera może nie dać się wyświetlić.** Docker nie ma wywołania, które wypisuje zawartość katalogu. Odczyt katalogu oznacza pobranie go jako archiwum, które zawiera wszystko poniżej — dla zatrzymanego kontenera zbudowanego na pełnowymiarowym obrazie może to być wiele gigabajtów, a wypis jest wtedy odrzucany zamiast czytać całość. Głębsze katalogi pozostają nietknięte, podobnie jak *działający* kontener: katalog zbyt duży, by odczytać go jako archiwum, wypisuje sam kontener. Jeśli chcesz wyłącznie drogi archiwalnej, zobacz ustawienie poniżej.

**Skopiowanie całego kontenera kopiuje cały jego system plików** — łącznie z `/proc` i `/dev`. Kopiuj katalog, którego potrzebujesz, a nie `/`.

## Do czego ma dostęp

Wtyczka rozmawia z tym silnikiem, do którego dotarłbyś z terminala: `DOCKER_HOST`, jeśli go ustawiłeś, w przeciwnym razie bieżący `docker context`, a dalej zwykłe gniazda Docker Desktop, Colimy, Rancher Desktop, Limy i Podmana. Podman działa, bo udostępnia to samo API.

Dostęp do demona Dockera oznacza zwykle bardzo szeroki dostęp do maszyny, na której działa. Wtyczka ma dokładnie Twoje uprawnienia i nie prosi o więcej: nie przechowuje żadnych poświadczeń, nigdy nie dotyka własnych katalogów Dockera na Twoim dysku i nie wykonuje w Twoim imieniu żadnych uprzywilejowanych działań.

Jedyne, co tworzy, to **kontener jednorazowy** — i tylko po to, by dotrzeć do wolumenu, którego nie montuje żaden istniejący kontener, ponieważ wolumen widać wyłącznie od wewnątrz czegoś, co go montuje. Nigdy nie jest uruchamiany, jest oznaczony jako należący do Peach Commandera i zostaje usunięty, gdy opuszczasz napęd.

## Ustawienia

Wtyczka prowadzi mały plik w `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — adres używany zamiast znalezionego.
- `ExecFallback` — `0` sprawia, że wtyczka używa wyłącznie archiwalnego API Dockera: nigdy wtedy niczego nie uruchamia w kontenerze, kosztem niemożności wypisania bardzo dużego katalogu, usunięcia i zmiany nazwy.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — ile archiwum katalogu warto przeczytać, zanim nastąpi awaryjne przejście lub rezygnacja.
- `HelperImage` — obraz, z którego powstaje powyższy kontener jednorazowy (domyślnie dowolny obraz już obecny na maszynie).
- `ShowAnonymousVolumes` — `0` ukrywa wolumeny, którym Docker nadał długi skrót jako nazwę, bo nikt inny ich nie nazwał.

## Nie ma w tej wersji

Zdalnych silników przez SSH lub TLS, uruchamiania i zatrzymywania kontenerów, dzienników kontenera jako pliku, interaktywnej powłoki oraz obrazów jako systemów plików tylko do odczytu.
