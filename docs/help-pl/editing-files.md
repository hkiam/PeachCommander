---
title: Edycja plików
slug: editing-files
section: Podgląd i edycja
order: 72
related: [viewing-files]
---

Gdy potrzebujesz zmienić plik, a nie tylko go obejrzeć, Peach Commander otwiera go we wbudowanym edytorze. Pliki tekstowe i kodu otwierają się w pełnym edytorze z podświetlaniem składni, wyszukiwaniem i zamianą, konspektem symboli w kodzie oraz minimapą do szybkiej nawigacji. Pliki binarne można otworzyć w osobnym edytorze szesnastkowym, gdzie możesz sprawdzać i zmieniać poszczególne bajty. Nigdy nie musisz opuszczać aplikacji, aby dokonać szybkiej edycji.

## Edytuj plik tekstowy lub kodu

1. W dowolnym panelu przesuń kursor na plik, który chcesz zmienić.
2. Naciśnij F4 lub wybierz Plik ▸ Edytuj. Plik otwiera się w oknie edytora.
3. Wprowadź zmiany. Jeśli plik jest rozpoznanym formatem programowania lub danych, słowa kluczowe, ciągi i komentarze są automatycznie kolorowane.
4. Naciśnij Cmd+S (lub kliknij Zapisz), aby zapisać zmiany. Pierwszy zapis zachowuje kopię zapasową oryginału obok pliku, więc zawsze możesz do niej wrócić.

Aby utworzyć zupełnie nowy plik tekstowy w bieżącej lokalizacji, naciśnij Shift+F4.

![Wbudowany edytor tekstu pokazujący podświetlanie składni, konspekt symboli i minimapę](screenshots/editor.png)
*(Rysunek: edytor z podświetlaniem składni, konspektem symboli po lewej i minimapą po prawej.)*

Jeśli plik należy do `root` — wpis w `/etc`, plist launchd, konfiguracja serwera WWW — zapis proponuje zrobić to **jako administrator**: macOS poprosi o autoryzację jak zwykle, treść jest przekazywana przez prywatny plik tymczasowy, a nie przez wiersz poleceń, i plik zachowuje własnego właściciela oraz uprawnienia, zamiast po cichu stać się twoim.

Jeśli do pliku nie można pisać, dowiesz się o tym przy otwarciu, a nie dopiero przy zapisie: tytuł nosi kłódkę, a wiersz stanu nazywa przeszkodę — należy do innego użytkownika, uprawnienia zabraniają zapisu, plik jest zablokowany, wolumin jest tylko do odczytu albo chroni go system. Tylko pierwszą da się rozwiązać, autoryzując zapis, i tylko tam jest to proponowane; w pozostałych kosztowałoby to hasło i mimo to by się nie udało.

Marginesw pokazuje numery wierszy, wiersz z kursorem jaśniej niż pozostałe; przycisk obok menu kodowania go ukrywa. Zawinięty wiersz jest numerowany raz, więc numer zawsze oznacza ten sam wiersz, o którym mówi błąd kompilatora albo uwaga z przeglądu.

## Wyszukiwanie, zamiana i nawigacja

- Naciśnij Cmd+F, aby otworzyć pasek wyszukiwania. Aby zamienić tekst, otwórz pasek wyszukiwania i przełącz go na widok zamiany, lub kliknij Znajdź/Zamień na pasku narzędzi.
- Kliknij Formatuj JSON/XML, aby ponownie wciąć dokument JSON lub XML do czystego, czytelnego układu.
- Kliknij Symbole (lub naciśnij Cmd+Shift+O), aby wyświetlić pasek boczny wymieniający klasy, funkcje i metody w kodzie. Kliknij wpis, aby przeskoczyć do niego bezpośrednio.
- Naciśnij Cmd+L, aby przeskoczyć do konkretnego wiersza.
- Naciśnij Cmd+\, aby przeskakiwać między nawiasem a jego pasującym odpowiednikiem.
- Kliknij przycisk mapy, aby pokazać lub ukryć minimapę, skalowany przegląd całego pliku, w który możesz kliknąć, aby przewinąć.
- Użyj menu Kodowanie na pasku narzędzi, jeśli plik został zapisany w innym niż domyślne kodowaniu tekstu.

## Filtrowanie przez polecenie powłoki

Kliknij **Filtruj…** (lub naciśnij Shift+Cmd+\), aby przesłać zaznaczony tekst przez polecenie i zastąpić go tym, co polecenie wypisze. Jeśli nic nie jest zaznaczone, przechodzi cały dokument. W ten sposób narzędzia, które już znasz, stają się poleceniami edytora: `sort -u` usuwa powtórzone wiersze, `jq .` czyni odpowiedź JSON czytelną, `column -t` wyrównuje tabelę, `base64 -d` dekoduje blok, `openssl x509 -noout -text` pokazuje certyfikat w czytelnej postaci.

Polecenie działa w Twojej powłoce logowania: `PATH`, aliasy i funkcje działają dokładnie tak jak w Terminalu, a potoki i cudzysłowy znaczą to, czego się spodziewasz. Katalogiem roboczym jest folder edytowanego pliku, więc ścieżki względne rozwiązują się tam, gdzie tego oczekujesz. Użyte polecenia są zapamiętywane i następnym razem proponowane na liście rozwijanej.

Jeśli polecenie zawiedzie, Twój tekst pozostaje nietknięty, a komunikat błędu polecenia pojawia się w wierszu stanu — błąd składni narzędzia `jq` nigdy nie trafi wklejony do Twojego pliku. Polecenie, które nic nie wypisze, opróżnia zaznaczenie i właśnie do tego służy filtrowanie narzędziem `grep`; Cmd+Z je przywraca. Polecenie, które się nie kończy, jest zatrzymywane po dwudziestu sekundach.

## Sortowanie, usuwanie duplikatów i porządkowanie wierszy

Menu **Wiersze** — na pasku narzędzi i, dopóki edytor jest na wierzchu, na pasku menu — wykonuje zmiany, które wracają wciąż od nowa, bez wpisywanego polecenia i bez zainstalowanego narzędzia:

- Sortuj A→Z lub Z→A, porównując liczby według wartości, tak że `file9` jest przed `file10`.
- Odwróć kolejność wierszy.
- Usuń powtórzone wiersze, zachowując pierwszy z każdego i pozostawiając resztę w ich kolejności.
- Usuń puste wiersze, w tym te, które tylko wyglądają na puste, bo zawierają spacje.
- Usuń spacje na końcu wiersza — niewidoczną różnicę, która zaśmieca diff.
- Zachowaj tylko wiersze zawierające wpisany przez Ciebie tekst albo właśnie je usuń.

Gdy tekst jest zaznaczony, każda z tych operacji działa na zaznaczonych wierszach; zaznaczenie jest najpierw rozszerzane do całych wierszy, bo sortowanie połowy wiersza nic nie znaczy. Bez zaznaczenia działają na całym dokumencie. Każda jest jednym krokiem cofnięcia, więc Cmd+Z wycofuje całą operację.

Końce wierszy znajdują się obok menu Kodowanie: **LF** dla Uniksa i macOS, **CRLF** dla Windows, **CR** dla klasycznego Mac OS oraz *(mixed)*, gdy jeden plik zawiera więcej niż jeden rodzaj — często powód błędu, który nie ma sensu. Wybierz inny, aby przekonwertować cały plik jednym krokiem, który da się cofnąć. Operacje na wierszach nigdy nie zmieniają końca wiersza same z siebie: posortowany plik CRLF pozostaje plikiem CRLF.

## Formatowanie pliku

Kliknij **Formatuj** w edytorze (to samo polecenie jest w przeglądarce), aby ponownie wciąć plik. Peach Commander wybiera formater na podstawie rozszerzenia i pokazuje w pasku stanu, którego użył, na przykład *formatted (jq)* — zawsze wiesz, co ukształtowało wynik.

**Bez instalowania czegokolwiek**: JSON, XML, SVG, plisty, HTML, konfiguracja w stylu INI i YAML. YAML jest przypadkiem osobnym: jest porządkowany, a nie wcinany od nowa, bo w YAML wcięcie *jest* strukturą, a przepisanie go bez prawdziwego parsera YAML mogłoby zmienić znaczenie pliku. Spacje na końcu wiersza znikają, zabłąkane tabulatory we wcięciu stają się spacjami, ciągi pustych wierszy się skracają — a wszystko wewnątrz skalara blokowego (`|` albo `>`) zostaje dokładnie tak, jak jest, bo tam biały znak jest treścią.

**Lepsze formatery przejmują automatycznie.** Jeśli masz jeden z nich, Peach Commander używa go, bo dedykowane narzędzie zwykle odpowiada temu, czego oczekuje ekosystem — a w formatach konfiguracji zachowuje twoje komentarze:

| Zainstaluj | i otrzymasz |
| --- | --- |
| `yq` albo `prettier` | pełne formatowanie YAML, komentarze zachowane |
| `taplo` | TOML |
| `sqlformat` albo `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON w przyjętym stylu |
| `xmllint` | XML i SVG |

Jeśli typ pliku nie ma formatera, przycisk jest wyszarzony, a pozycja menu wyłączona. Próba i tak powie dlaczego — *„taplo nie jest zainstalowany”* czyta się inaczej niż *„Nieprawidłowy JSON”*.

### Użycie własnego formatera

Aby sformatować typ, którego Peach Commander nie zna, albo użyć innego narzędzia, utwórz `formatters.ini` w folderze konfiguracji — jedna sekcja na rozszerzenie:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` to nazwa programu (szukana tak, jak zrobiłaby to twoja powłoka) albo ścieżka bezwzględna; `args` są przekazywane bez zmian. Tekst pliku wchodzi standardowym wejściem, a sformatowany wraca standardowym wyjściem, więc działa każdy dobrze wychowany formater wiersza poleceń. Twoje wpisy wygrywają ze wszystkim innym. Przy pierwszym uruchomieniu tworzony jest szablon z komentarzami — otwórz plik i wypełnij go.

Wtyczki też mogą dostarczać formatery — zobacz [Plugins](plugins.md).

## Edytuj plik bajt po bajcie

1. Zaznacz plik w panelu.
2. Wybierz Plik ▸ Edytuj jako szesnastkowy (lub kliknij plik prawym przyciskiem i wybierz Edytuj jako szesnastkowy).
3. Wpisuj cyfry szesnastkowe, aby nadpisywać bajty, lub użyj strzałek, aby poruszać się po pliku. Backspace i Delete usuwają bajty.
4. Naciśnij Cmd+S, aby zapisać. Podobnie jak w edytorze tekstu, zachowywana jest jednorazowa kopia zapasowa oryginału.

## Skróty

| Akcja | Klawisz |
|---|---|
| Edytuj plik | F4 |
| Utwórz i edytuj nowy plik tekstowy | Shift+F4 |
| Zapisz | Cmd+S |
| Znajdź | Cmd+F |
| Pokaż/ukryj konspekt symboli | Cmd+Shift+O |
| Przejdź do wiersza | Cmd+L |
| Przeskocz do pasującego nawiasu | Cmd+\ |
| Cofnij / Ponów (edytor szesnastkowy) | Cmd+Z / Cmd+Shift+Z |
| Filtruj zaznaczenie przez polecenie | Shift+Cmd+\ |

## Uwagi

- Podświetlanie składni obejmuje JSON, C, C#, Java, JavaScript, TypeScript, Python i Rust. Inne typy plików nadal otwierają się i edytują normalnie z podstawowym kolorowaniem, ale szczegółowe podświetlanie i konspekt symboli są dostępne tylko dla obsługiwanych języków.
- Konspekt symboli i Przejdź do wiersza dotyczą edytora tekstu. Edytor szesnastkowy jest przeznaczony do inspekcji binarnej i edycji na poziomie bajtów, a nie do tekstu.
- Oba edytory zachowują kopię zapasową oryginalnego pliku przy pierwszym zapisie, więc przypadkową zmianę łatwo cofnąć, przywracając tę kopię.
