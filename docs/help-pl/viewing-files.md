---
title: Podgląd plików
slug: viewing-files
section: Podgląd i edycja
order: 70
related: [editing-files, searching]
---

Peach Commander ma wbudowaną przeglądarkę, która pozwala zajrzeć do wnętrza pliku bez otwierania innej aplikacji ani zmiany pliku. Naciśnij F3 na elemencie pod kursorem, a przeglądarka otwiera się natychmiast, nawet dla bardzo dużych plików. Automatycznie wybiera najlepszy sposób pokazania zawartości: czytelny tekst, kod z kolorowaniem składni, surowy zrzut szesnastkowy lub obraz w pełnym rozmiarze. Możesz również podejrzeć plik prosto w oknie za pomocą Szybkiego podglądu, albo przekazać go do Quick Look w macOS.

## Wyświetl plik

1. Przesuń kursor na plik w aktywnym panelu.
2. Naciśnij F3 (lub wybierz Wyświetl w menu Plik). Przeglądarka otwiera się we własnym oknie.
3. Użyj paska narzędzi, aby przełączać sposób pokazania zawartości: Tekst, Kod, Szesnastkowy, Obraz lub Renderowany. Pozostaw ustawienie automatyczne, aby pozwolić Peach Commanderowi zdecydować.
4. Przewijaj strzałkami, Page Up/Page Down i paskiem przewijania. Przy długim tekście włącz przycisk minimapy, aby widzieć cały plik i szybko się po nim poruszać.
5. Naciśnij N, aby przeskoczyć do następnego wybranego pliku, lub zamknij okno klawiszem Esc.

![Wbudowana przeglądarka pokazująca plik tekstowy z minimapą po prawej](screenshots/lister-text.png)
*(Rysunek: podgląd pliku tekstowego, z selektorem reprezentacji i minimapą na pasku narzędzi.)*

## Znajdź tekst i zmień kodowanie

- Naciśnij Ctrl+F, aby wyszukać wewnątrz pliku. Naciśnij F3, aby przeskoczyć do następnego dopasowania, i Shift+F3 do poprzedniego.
- Zaznacz **Wyrażenie regularne** w oknie wyszukiwania, aby szukać wzorcem zamiast zwykłego tekstu — `ERROR \d+` albo `^Warning` dla wierszy zaczynających się tym słowem. `^` i `$` oznaczają początek i koniec wiersza. Wzorzec, którego nie da się skompilować, jest zgłaszany jako taki, zamiast po cichu niczego nie znajdować.
- Bardzo duże pliki są przeszukiwane w nakładających się oknach, więc pojedyncze trafienie dłuższe niż około 64 KB może zostać pominięte, jeśli akurat przypadnie na granicę okna. Zwykłe wyszukiwanie tekstu nie ma takiego ograniczenia — nie ma go też wzorzec pasujący do czegoś krótszego.
- Jeśli tekst wygląda na zniekształcony, kliknij Kodowanie na pasku narzędzi (lub naciśnij E), aby przełączać kodowania tekstu, dopóki nie odczyta się poprawnie; ustawienie automatyczne zwykle trafia.
- Naciśnij W, aby przełączyć zawijanie wierszy dla długich linii.
- Naciśnij Ctrl+G, aby przejść do wiersza, a w trybie szesnastkowym do przesunięcia w bajtach. Można liczyć między systemami liczbowymi: `0x1000 + 15 + 1` prowadzi do 4112 — szesnastkowo z `0x`, `$` lub końcowym `h`, dwójkowo z `0b`, ósemkowo z `0o`, i `+ - * /` z nawiasami.
- Jeśli otworzysz trafienie z Znajdź pliki, w którym wypełnione było pole **Znajdź tekst**, przeglądarka zaczyna od tego wyszukiwania: tekst jest już w pasku wyszukiwania, a pierwsze wystąpienie widać na ekranie, więc trafiasz na dopasowanie, a nie na początek pliku. Jeśli go tam zmienisz lub wyczyścisz, zostaje twoja wersja. W Ustawieniach ▸ Edycja/Podgląd można to wyłączyć, jeśli wolisz, by każdy plik otwierał się od początku.

## Powiększanie obrazu

W reprezentacji obrazu przeglądarka otwiera obraz dopasowany do okna, a mały obraz zostawia w jego własnym rozmiarze, zamiast go rozdymać.

| Czynność | Menu | Klawisze |
| --- | --- | --- |
| Powiększ | Widok ▸ Powiększ | Cmd++ / + |
| Pomniejsz | Widok ▸ Pomniejsz | Cmd+- / - |
| Rozmiar rzeczywisty (100%) | Widok ▸ Rozmiar rzeczywisty | Cmd+0 / 0 |
| Dopasuj do okna | Widok ▸ Dopasuj do okna | Cmd+9 / F |

Możesz też uszczypnąć na gładziku albo przewijać z wciśniętym Cmd. Poziom widać w wierszu stanu, a *rozmiar rzeczywisty* oznacza jeden piksel obrazu na punkt ekranu — nie tylko „cofnij moje powiększanie”. Dopasowanie idzie za oknem: zmień jego rozmiar, a obraz pozostanie dopasowany.

## Notatki do wiersza

Jeśli wtyczka Notatki jest zainstalowana, notatka może dotyczyć konkretnego wiersza pliku, a nie całego pliku.

- Ustaw kursor w wierszu i wybierz **Widok ▸ Notatka do tego wiersza…** (Cmd+Shift+N). Edytor notatek otworzy się z nazwą pliku i numerem wiersza w tytule.
- Wiersze, które już mają notatkę, pojawiają się jako grupa **Notatki** w panelu znaczników na dole okna, obok wyników wyszukiwania. Cmd+Ctrl+M otwiera panel; dwukrotne kliknięcie pozycji przenosi do wiersza.
- Same notatki leżą razem ze wszystkimi innymi, więc przegląd notatek i Znajdź pliki odnajdują je tak samo. Usuwa się je w edytorze notatek — przycisk zamknięcia w panelu jedynie ukrywa grupę.

## Szybki podgląd i Quick Look

Szybki podgląd pokazuje podgląd na żywo w panelu, którego *nie* używasz, dzięki czemu możesz kontynuować przeglądanie po jednej stronie, podglądając po drugiej.

1. Naciśnij Ctrl+Q. Nieaktywny panel zmienia się w obszar podglądu.
2. Przesuwaj kursor po różnych plikach w aktywnym panelu, aby podejrzeć każdy z nich.
3. Naciśnij Ctrl+Q ponownie, lub Esc, aby przywrócić panelowi normalną listę plików.

Obraz w szybkim podglądzie ma te same przyciski powiększania co podgląd w panelu bocznym — w narożniku panelu, który zajął.

Aby uzyskać szybki podgląd pełnoekranowy obsługiwany przez sam macOS, naciśnij Cmd+Y (Quick Look). Naciśnij Cmd+Y lub Spację ponownie, aby go zamknąć.

## Strona informacji w panelu bocznym

Panel boczny (**Widok > Panel podglądu** lub Cmd+Shift+P) ma stronę **Informacje**, która pokazuje element pod kursorem tak, jak robi to pasek informacji Findera.

- Podgląd wypełnia szerokość panelu — po poszerzeniu panelu podgląd rośnie razem z nim. Przeciągnij lewą krawędź panelu, aby go poszerzyć lub zwęzić; szerokość jest zapamiętywana.
- To prawdziwy podgląd macOS, a nie mała miniatura: działa każdy format, który potrafi pokazać Szybki podgląd, a dokument wielostronicowy przewijasz w podglądzie strona po stronie.
- Obraz ma własne przyciski powiększania w narożniku podglądu — pomniejsz, powiększ, rozmiar rzeczywisty i dopasuj — a obok nich aktualny poziom; uszczypnięcie i Cmd+przewijanie też tam działają. Wszystko inne, co rysuje podgląd, na przykład PDF albo film, zachowuje się jak dotąd.
- Poniżej znajdują się nazwa, rodzaj i rozmiar, a dalej data utworzenia i zmiany oraz folder, w którym element się znajduje.

Przy przesuwaniu kursora nazwa i dane odświeżają się natychmiast; podgląd pojawia się chwilę później, aby przytrzymanie strzałki przez długi folder nie uruchamiało podglądu dla każdego mijanego wiersza.

## Dekompilacja plików .class języka Java

Przy włączonej wtyczce **Java Decompiler** klawisz F3 na pliku `.class` pokazuje czytelny kod zamiast danych binarnych — również dla klas wewnątrz archiwum JAR lub ZIP, do którego można wejść i czytać bez rozpakowywania.

Wtyczka nie zawiera własnego dekompilatora. Steruje silnikiem, który instalujesz sam, i silnik można wymienić w każdej chwili:

- **CFR** (licencja MIT) i **Vineflower** (Apache 2.0) tworzą kod źródłowy Javy. Umieść `cfr.jar` lub `vineflower.jar` w folderze silników.
- **Procyon** (Apache 2.0) to trzeci dekompilator do kodu źródłowego.
- **javap** nie wymaga żadnego pobierania — należy do każdego JDK i pokazuje kod bajtowy zamiast źródła Javy.

Nic nie jest pobierane za ciebie: to programy innych autorów na własnych licencjach, a Peach Commander ich nie pobiera ani nie aktualizuje. Przycisk **Folder silników…** w podglądzie otwiera folder, do którego należą, i zostawia tam notatkę z nazwą każdego silnika i miejscem pobrania. Wszystkie poza javap wymagają zainstalowanej Javy.

Silnik zmieniasz menu u góry podglądu; wybrany działa natychmiast, a wynik jest zachowywany, więc porównanie dwóch silników na tym samym pliku jest błyskawiczne.

Kod jest podświetlany składniowo, a dwa przyciski prowadzą dalej: **Zapisz jako…** zapisuje go do pliku, a **Otwórz w edytorze** przekazuje go temu, co otwiera `.java` na twoim Macu. Bardzo duży wynik pokazywany jest bez podświetlenia, aby pojawił się od razu, a nie po chwili; wiersz stanu o tym informuje.

Wyniki są zapisywane w pamięci podręcznej na dysku, więc ponowne otwarcie już oglądanego pliku jest natychmiastowe; klucz obejmuje rozmiar i datę pliku oraz argumenty silnika, dlatego przebudowana klasa lub zmieniona opcja jest dekompilowana ponownie. Wybrany silnik jest pamiętany dla każdego rodzaju plików. Profil może dziedziczyć po silniku wbudowanym przez `extends = cfr` i nadpisywać tylko opcje — przydatne, gdy utrzymujesz dwa warianty tego samego silnika.

Włącz **Porównaj**, aby otworzyć drugi panel z własnym menu silnika. Dwa dekompilatory zawodzą w różnych miejscach, więc zobaczenie ich obok siebie jest często szybsze niż rozstrzyganie, któremu zaufać; wybór `javap` z jednej strony stawia kod bajtowy obok źródła. Oba panele dzielą pamięć podręczną, więc przełączanie między już uruchomionymi silnikami jest natychmiastowe.

F3 na całym pliku `.jar`, `.apk` lub `.dex` dekompiluje go w całości i pokazuje drzewo pakietów obok źródła. Pole wyszukiwania nad drzewem przeszukuje każdą klasę — dokładnie to pytanie, na które jedna klasa odpowiedzieć nie może: gdzie napis, wywołanie albo stała rzeczywiście występuje, gdy jeszcze nie wiadomo, w której klasie. Trafienia zawężają drzewo, a pierwsze otwiera się na swojej linii. Enter nadal otwiera JAR jako archiwum — oba czasowniki pozostają rozdzielone.

Jest druga, bardziej bezpośrednia droga: ustaw kursor na pliku `.class` albo na całym archiwum i wybierz **Zdekompiluj do źródeł** (menu Polecenia, menu kontekstowe lub ⌘⇧J). Klasy zostaną zdekompilowane, a wynik otworzy się w drugim panelu jako zwykłe pliki `.java`. Od tej chwili obowiązuje cały menedżer plików — F3 pokazuje je z własnym podświetlaniem Javy Peach Commandera, Alt+F7 szuka wśród nich, F5 kopiuje je na zewnątrz, a porównywać i oznaczać można je jak wszystko inne. Do większości pracy bije to osobne okno; dlatego drzewo wtyczki można wyłączyć w Ustawieniach ▸ Dekompilator.

Druga wtyczka robi to samo dla .NET: F3 na zarządzanym `.dll`, `.exe` lub `.winmd` pokazuje jego typy jako C#, **Zdekompiluj assembly do źródeł** (⌘⇧N) umieszcza je w panelu, a wyszukiwanie potrafi zajrzeć do assembly tak samo. Steruje **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) dla źródeł albo **monodis** z Mono dla IL — odpowiednikiem `javap` w .NET. Natywny `.dll` ma to samo rozszerzenie i nie ma źródła do pokazania, więc wtyczka sprawdza to przed otwarciem i zostawia go wbudowanej przeglądarce.

Strona ustawień ma przycisk **Sprawdź silniki** i warto go użyć: „zainstalowany” gdzie indziej znaczy tylko, że plik jest na dysku, a silnik Javy na Macu bez JDK jest obecny i nie może działać. Sprawdzenie pyta każdy silnik o wersję i mówi, które naprawdę działają.

Android jest również objęty: F3 na pliku `.dex` używa **jadx** (Apache 2.0, `brew install jadx`), który zamienia kod bajtowy Dalvik z powrotem na Javę. Wystarczył jeden opis silnika — ten sam mechanizm, inny format.

Wtyczka jest **wyłączona, dopóki jej nie włączysz**, w Ustawienia ▸ Wtyczki — większość osób nigdy nie otwiera pliku .class, a bez silnika i tak nic nie da.

Aby dodać własny silnik, utwórz `decompilers.ini` w folderze silników:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` i `{outdir}` są podstawiane przy uruchomieniu. Twoje wpisy mają pierwszeństwo przed wbudowanymi, a użycie wbudowanej nazwy (`cfr`, `vineflower`, `procyon`, `javap`) zastępuje ją zamiast dodawać drugi wpis.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Wyświetl plik pod kursorem | F3 |
| Wyświetl tylko plik pod kursorem (ignoruj oznaczone pliki) | Shift+F3 |
| Otwórz w zewnętrznej przeglądarce | Option+F3 |
| Znajdź w przeglądarce | Ctrl+F |
| Notatka do wiersza pod kursorem | Cmd+Shift+N |
| Pokaż lub ukryj panel znaczników | Cmd+Ctrl+M |
| Następne / poprzednie dopasowanie | F3 / Shift+F3 |
| Szybki podgląd w drugim panelu | Ctrl+Q |
| Quick Look (podgląd macOS) | Cmd+Y |
| Zamknij przeglądarkę lub Szybki podgląd | Esc |

## Uwagi

- Przeglądarka jest tylko do odczytu. Aby zmienić plik, użyj zamiast tego edytora (zobacz Edycja plików).
- Bardzo duże pliki otwierają się bez opóźnienia: tekst otwiera szybki, przewijalny widok, a widok szesnastkowy jest strumieniowany prosto z dysku przy dowolnym rozmiarze.
- Naciśnij F3 na folderze, aby zobaczyć podsumowanie jego zawartości i całkowity rozmiar zamiast bajtów pliku.
- Tryb Renderowany wyświetla sformatowaną zawartość, taką jak strony internetowe; tryb szesnastkowy pokazuje surowe bajty obok ich znaków, co jest przydatne do badania plików binarnych.
- W trybie Renderowanym można zaznaczać i kopiować tekst, a Znajdź przeszukuje wyrenderowaną stronę. Przyciski, których nie da się zastosować do wyrenderowanej strony — Formatuj, Kodowanie, Zaznacz wszystko, Zaznaczenia i Idź do — są wyszarzone, zamiast pozostawać bez efektu.
- Przycisk Formatuj ponownie wcina pliki strukturalne (JSON, XML, HTML, INI, YAML i więcej, jeśli masz odpowiednie narzędzie wiersza poleceń). Jest w pełni opisany w [Edycja plików](editing-files.md#formatting-a-file) i działa tu tak samo.
