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
4. Naciśnij Cmd+S (lub kliknij Zapisz), aby zapisać zmiany. Zapis zastępuje plik; jeśli chcesz zachować poprzednią treść obok niego, włącz kopie zapasowe w Ustawieniach ▸ Edycja/Podgląd.

Aby utworzyć zupełnie nowy plik tekstowy w bieżącej lokalizacji, naciśnij Shift+F4.

![Wbudowany edytor tekstu pokazujący podświetlanie składni, konspekt symboli i minimapę](screenshots/editor.png)
*(Rysunek: edytor z podświetlaniem składni, konspektem symboli po lewej i minimapą po prawej.)*

Jeśli plik należy do `root` — wpis w `/etc`, plist launchd, konfiguracja serwera WWW — zapis proponuje zrobić to **jako administrator**: macOS poprosi o autoryzację jak zwykle, treść jest przekazywana przez prywatny plik tymczasowy, a nie przez wiersz poleceń, i plik zachowuje własnego właściciela oraz uprawnienia, zamiast po cichu stać się twoim.

Jeśli do pliku nie można pisać, dowiesz się o tym przy otwarciu, a nie dopiero przy zapisie: tytuł nosi kłódkę, a wiersz stanu nazywa przeszkodę — należy do innego użytkownika, uprawnienia zabraniają zapisu, plik jest zablokowany, wolumin jest tylko do odczytu albo chroni go system. Tylko pierwszą da się rozwiązać, autoryzując zapis, i tylko tam jest to proponowane; w pozostałych kosztowałoby to hasło i mimo to by się nie udało.

Marginesw pokazuje numery wierszy, wiersz z kursorem jaśniej niż pozostałe; przycisk obok menu kodowania go ukrywa. Zawinięty wiersz jest numerowany raz, więc numer zawsze oznacza ten sam wiersz, o którym mówi błąd kompilatora albo uwaga z przeglądu.

## Wyszukiwanie, zamiana i nawigacja

- Naciśnij Cmd+F, aby otworzyć pasek wyszukiwania. Aby zamienić tekst, otwórz pasek wyszukiwania i przełącz go na widok zamiany, lub kliknij Znajdź/Zamień na pasku narzędzi.
- Do **wyrażenia regularnego** użyj Szukaj ▸ *Znajdź wyrażeniem regularnym…* (Ctrl+Cmd+F) lub *Zamień wyrażeniem regularnym…* (Ctrl+Opt+Cmd+F). `^` i `$` pasują do początku i końca wiersza, a w zamienniku `$1` oznacza pierwszą grupę — `(\w+) (\d+)` zamienione na `$2=$1` zmienia więc `alpha 11` w `11=alpha`. **Tylko w zaznaczeniu** utrzymuje zmianę w zaznaczonym tekście; **Zamień wszystko** przepisuje wszystkie trafienia w jednym kroku, który cofa Cmd+Z.
- Znajdź następne (Cmd+G) podąża za ostatnio użytym wyszukiwaniem, zwykłym lub wzorcem. Wzorzec, którego nie da się skompilować, jest zgłaszany w oknie zamiast po cichu niczego nie znajdować.
- Kliknij Formatuj JSON/XML, aby ponownie wciąć dokument JSON lub XML do czystego, czytelnego układu.
- Kliknij Symbole (lub naciśnij Cmd+Shift+O), aby wyświetlić pasek boczny wymieniający klasy, funkcje i metody w kodzie — albo, w pliku JSON, YAML czy XML, jego klucze i elementy. Kliknij wpis, aby przeskoczyć do niego bezpośrednio. Do czego jeszcze służy ta struktura, zobacz [Praca z JSON, YAML i XML](#praca-z-json-yaml-i-xml).
- Naciśnij Cmd+L, aby przeskoczyć do konkretnego wiersza.
- Naciśnij Cmd+\, aby przeskakiwać między nawiasem a jego pasującym odpowiednikiem.
- Kliknij przycisk mapy, aby pokazać lub ukryć minimapę, skalowany przegląd całego pliku, w który możesz kliknąć, aby przewinąć.
- Użyj menu Kodowanie na pasku narzędzi, jeśli plik został zapisany w innym niż domyślne kodowaniu tekstu.

## Praca z JSON, YAML i XML

Te trzy formaty mają własne traktowanie, bo po pliku konfiguracyjnym poruszamy się według struktury, a nie numerów wierszy.

Pasek boczny **Symbole** wymienia klucze pliku JSON lub YAML oraz elementy pliku XML, zagnieżdżone tak jak sam dokument. Element bierze nazwę ze swojego atrybutu `id`, `name` lub `key`, jeśli go ma, więc dwadzieścia wpisów `<server>` da się rozróżnić. Lista pokazuje swoje wpisy jako `[0]`, `[1]`, a gdy wpis zaczyna się kluczem, pokazany jest również on — `[0] name`. Pole filtra nad listą znajduje klucz po nazwie w pliku dowolnej wielkości, a pasek stanu zawsze pokazuje ścieżkę do tego, w czym stoi kursor.

Nawet uszkodzony plik dostaje konspekt aż do miejsca, w którym się psuje — i właśnie wtedy jest najbardziej potrzebny.

Menu **Struktura** — w pasku menu, dopóki edytor jest na wierzchu — przenosi cię po tej strukturze:

- **Przejdź do węzła nadrzędnego** (Ctrl+Cmd+Góra) wychodzi do bloku zawierającego kursor: od `image:` do usługi, do której należy.
- **Przejdź do pierwszego dziecka** (Ctrl+Cmd+Dół) wchodzi w głąb.
- **Przejdź do poprzedniego / następnego rodzeństwa** (Ctrl+Cmd+Lewo / Prawo) przechodzi między wpisami tego samego poziomu, przeskakując cały blok pomiędzy — z jednego serwera na następny bez przewijania czterdziestu wierszy ustawień.
- **Zaznacz węzeł nadrzędny** (Ctrl+Cmd+A) zaznacza blok, w którym stoi kursor. Naciśnij ponownie i zaznaczenie rośnie do bloku wokół niego, więc zaznaczysz dokładnie jedną usługę albo dokładnie jeden element bez przeciągania.
- **Kopiuj ścieżkę strukturalną** (Ctrl+Cmd+C) kopiuje pozycję jako wyrażenie, które przyjmują narzędzia danego formatu: `.services.web.ports[0]` dla JSON i YAML, czego oczekują `jq` i `yq`, oraz `//server[@id='web-1']/port` dla XML, czyli XPath. Klucze, które nie są zwykłymi słowami, są za ciebie ujmowane w cudzysłowy — `."content-type"`, a nie `.content-type`, co w `jq` znaczy coś zupełnie innego.
- **Sprawdź dokument** (Ctrl+Cmd+V) sprawdza plik i ustawia kursor **na problemie**, z powodem w tytule okna. Zgłasza też to, czego nie zgłosi nic innego w łańcuchu narzędzi: zduplikowany klucz, który każdy parser JSON przyjmuje w milczeniu, odrzucając jedną z dwóch wartości, oraz przecinek na końcu, który parser Apple przyjmuje, a Python, Go i `jq` odrzucają.

Długie pliki czyta się, zwijając to, nad czym się w danej chwili nie pracuje. **Zwiń węzeł** (Option+Cmd+Lewo) zwija blok, w którym stoi kursor — najbliższy, który ma treść, więc naciśnięcie na pojedynczym wierszu zwija otaczające go odwzorowanie —, **Rozwiń węzeł** (Option+Cmd+Prawo) otwiera go ponownie, **Zwiń najwyższy poziom** (Option+Cmd+Góra) zwija dla przeglądu wszystko na najbardziej zewnętrznym poziomie, a **Rozwiń wszystko** (Option+Cmd+Dół) przywraca stan. Wiersz z kluczem albo znacznikiem pozostaje widoczny i jest oznaczony, więc zwinięty blok widocznie jest zwinięty; numery wierszy pomijają to, co ukryte. Z dokumentu nic nie jest usuwane — tekst po prostu nie jest rysowany, więc zapisywanie, cofanie i wyszukiwanie pozostają bez zmian, a wyszukiwanie nadal znajduje tekst wewnątrz zwiniętego bloku. Ustawienie kursora w zwinięciu otwiera je, a każda edycja otwiera wszystko: zwinięcie to para pozycji, a wstawiony tekst je przesuwa.

To samo menu zawiera przekształcenia, które przepisują cały dokument — albo, gdy tekst jest zaznaczony, tylko ten fragment — w jednym kroku, który da się cofnąć: **Zmniejsz (jeden wiersz)** dla treści JSON, która musi zmieścić się w poleceniu `curl`, **Sortuj klucze rekurencyjnie**, aby dwa eksporty tych samych ustawień nie pokazywały żadnej różnicy, **Zakoduj jako łańcuch JSON** i **Odkoduj łańcuch JSON** do codziennej mozolnej pracy wstawiania certyfikatu, skryptu albo całego dokumentu JSON *do* pola JSON, oraz **Przekształć JSON na YAML**. Zmniejszanie zachowuje kolejność kluczy i dokładny zapis każdej liczby, bo `1.0` i `1` to nie ta sama wersja; sortowanie celowo tego nie robi, bo sortowanie jest zmianą kolejności. Kodowanie dotyczy każdego pliku, nie tylko JSON. Z YAML do JSON nie ma nic i jest to decyzja: wymagałoby to parsera YAML, którego system nie ma, a błędne założenie co do zakotwiczenia albo `true` w cudzysłowie zmienia plik konfiguracyjny w inny.

Dla JSON i XML plik sprawdza prawdziwy parser. Dla YAML nie ma go w systemie, więc sprawdzanie obejmuje błędy, które da się znaleźć bez niego — tabulator użyty do wcięcia, czego YAML wyraźnie zabrania, wcięcie niepasujące do niczego, zduplikowany klucz, niezamknięty cudzysłów — i mówi to wprost, zamiast uznawać plik za prawidłowy.

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
4. Naciśnij Cmd+S, aby zapisać. Podobnie jak w edytorze tekstu poprzednia treść zostaje zachowana tylko wtedy, gdy włączyłeś kopie zapasowe.

## Ciągi w edytowanym pliku

Edytor szesnastkowy ma ten sam panel **Ciągi** co przeglądarka: każdą czytelną sekwencję tekstu w pliku, w czterech kodowaniach naraz, a kliknięcie ustawia na niej kursor i zaznaczenie.

- Czyta bajty w postaci, w jakiej je zmieniono, a nie w takiej, w jakiej są na dysku, więc przesunięcia wskazują właściwe miejsce także po wstawieniu, które przesunęło wszystko poniżej.
- Lista podąża za zmianami: po zmianie bajtu jest przebudowywana chwilę po tym, jak przestaniesz pisać.
- Jest w pełni opisana w [Przeglądanie plików](viewing-files.md#read-the-strings-in-a-binary) i zachowuje się tu tak samo.

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
| Przejdź do węzła nadrzędnego (JSON/YAML/XML) | Ctrl+Cmd+Góra |
| Przejdź do pierwszego dziecka | Ctrl+Cmd+Dół |
| Przejdź do poprzedniego / następnego rodzeństwa | Ctrl+Cmd+Lewo / Prawo |
| Zaznacz węzeł nadrzędny | Ctrl+Cmd+A |
| Kopiuj ścieżkę strukturalną | Ctrl+Cmd+C |
| Sprawdź dokument | Ctrl+Cmd+V |
| Zwiń / rozwiń węzeł | Option+Cmd+Lewo / Prawo |
| Zwiń najwyższy poziom / rozwiń wszystko | Option+Cmd+Góra / Dół |
| Cofnij / Ponów (edytor szesnastkowy) | Cmd+Z / Cmd+Shift+Z |
| Filtruj zaznaczenie przez polecenie | Shift+Cmd+\ |

## Uwagi

- Podświetlanie składni obejmuje JSON, C, C#, Java, JavaScript, TypeScript, Python i Rust. Inne typy plików nadal otwierają się i edytują normalnie z podstawowym kolorowaniem, ale szczegółowe podświetlanie jest dostępne tylko dla obsługiwanych języków.
- Konspekt obejmuje obsługiwane języki programowania oraz JSON, YAML i XML — w tym formaty oparte na XML, takie jak `.plist`, `.svg`, `.csproj` i `.storyboard`. Polecenia nawigacji strukturalnej, ścieżki i sprawdzania dotyczą JSON, YAML i XML.
- Konspekt symboli i Przejdź do wiersza dotyczą edytora tekstu. Edytor szesnastkowy jest przeznaczony do inspekcji binarnej i edycji na poziomie bajtów, a nie do tekstu.
- Żaden z edytorów nie zachowuje kopii zapasowej, dopóki o nią nie poprosisz. Włącz „Podczas zapisywania zachowaj kopię zapasową (.bak) poprzedniej treści” w Ustawieniach ▸ Edycja/Podgląd, a pierwszy zapis zapisze oryginał obok pliku jako `name.bak`, więc przypadkową zmianę łatwo cofnąć.
