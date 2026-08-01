---
title: Wygląd
slug: appearance
section: Dostosowywanie
order: 114
related: [settings]
---

Peach Commander może dopasować się do wyglądu reszty Twojego Maca lub przybrać własny styl. Możesz podążać za jasnym lub ciemnym ustawieniem systemu (albo wymusić jedno z nich), zmienić kolory paneli plików, wyróżnić pliki według typu oraz dostosować rozmiar czcionki listy i format daty, aby panele czytały się dokładnie tak, jak lubisz.

## Wybierz motyw kolorów

Motyw zastępuje całą paletę paneli w jednym kroku.

1. Otwórz okno ustawień, wybierając Konfiguracja > Opcje…, lub naciśnij Cmd+,.
2. Wybierz stronę **Kolory**.
3. Wybierz z menu **Motyw**:
   - **System (domyślnie)** — bez motywu. Panele stosują się do ustawienia Wygląd poniżej, dokładnie tak jak dotychczas. To ustawienie domyślne.
   - **Jasny** / **Ciemny** — ustala wbudowaną jasną lub ciemną paletę niezależnie od tego, co robi macOS.
   - **Północ** — ciemny motyw, który nie jest tylko szary: głęboko indygowe panele z miękkim niebieskoszarym tekstem, białym wierszem kursora i bursztynem dla zaznaczonych plików.
   - **Norton Commander** — klasyczny niebiesko-turkusowy wygląd pierwotnego menedżera plików DOS, w autentycznych barwach CGA: niebieskie panele, turkusowy tekst, jasnoturkusowy wiersz kursora i żółty dla zaznaczonych plików.

Motyw wnosi własną jasną/ciemną podstawę, dzięki czemu arkusze, paski przewijania i standardowe kontrolki do niego pasują — dlatego menu **Wygląd** jest wyszarzone, gdy wybrany jest motyw. Własne kolory paneli (poniżej) nadal mają pierwszeństwo przed motywem.

![Peach Commander w palecie Norton Commander](screenshots/theme-norton.png)
*(Rysunek: paleta Norton Commander — oryginalny błękit, turkus i żółć CGA.)*

Motyw Norton Commander używa autentycznych wartości CGA z oryginału z 1986 roku: `#0000AA` niebieski, `#00AAAA` turkusowy, `#55FFFF` dla wiersza kursora, `#FFFF55` dla zaznaczonych plików. Pasek kursora odwraca się na ciemny tekst na turkusie, tak jak rysował go oryginał, a zaznaczone pliki zachowują żółć.

![Zbliżenie wiersza kursora w palecie Norton](screenshots/theme-norton-cursor-crop.png)
*(Rysunek: pasek kursora się odwraca; zaznaczone pliki pozostają żółte.)*

![Strona ustawień Kolory w palecie Norton Commander](screenshots/theme-norton-settings.png)
*(Rysunek: własne okna programu również stosują się do motywu.)*

Motywy to wyłącznie kolory. Układ paneli, ramki i kroje pisma pozostają bez zmian — Norton Commander nie przywraca podwójnych ramek ani rastrowego kroju DOS.

## Napisz własny motyw

Motywy to zwykłe pliki tekstowe, po jednym na motyw, w folderze `themes` wewnątrz folderu konfiguracji.

1. Na stronie **Kolory** kliknij **Folder motywów…**. Folder zostanie utworzony, jeśli nie istnieje, a gdy jest pusty po raz pierwszy, Peach Commander umieszcza w nim skomentowany plik `example-norton.ini` z listą wszystkich kolorów, jakie można ustawić.
2. Skopiuj ten plik, nadaj mu nową nazwę i edytuj. Nazwa pliku (bez `.ini`) jest identyfikatorem motywu; wiersz `Name` to nazwa pokazywana w menu Motyw.
3. Zapisz. Otwórz menu **Motyw** ponownie — Twój motyw jest na liście. Ponowne uruchomienie nie jest potrzebne.

Minimalny motyw to trzy wiersze:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander we własnoręcznie napisanym motywie](screenshots/theme-custom.png)
*(Rysunek: motyw wczytany z pliku w folderze motywów.)*

`Base` wybiera wbudowaną paletę (`light` lub `dark`), która dostarcza wszystkie kolory niewymienione przez Ciebie, więc zapisujesz tylko to, co chcesz zmienić. Kolory podaje się jako `#RRGGBB`. Wiersze zaczynające się od `;` lub `#` są komentarzami.

Jeśli coś w pliku jest błędne, Peach Commander pomija ten jeden wiersz i zachowuje resztę motywu — nie odrzuca pliku. Powód trafia do dziennika systemowego, widocznego w Konsoli po odfiltrowaniu `[theme]`.

Nazwy `light`, `dark`, `norton` i `system` należą do motywów wbudowanych; plik o takiej nazwie jest pomijany, aby nie mógł przesłonić motywu dostarczonego z programem. Po usunięciu pliku wybranego motywu Peach Commander wraca do **System (domyślnie)**.
## Ustaw wygląd jasny, ciemny lub systemowy

1. Otwórz okno ustawień, wybierając Konfiguracja > Opcje…, lub naciśnij Cmd+,.
2. Wybierz stronę **Kolory**.
3. Z menu **Wygląd** wybierz jedną z opcji:
   - **System (podążaj za macOS)** — automatycznie dopasowuje się do bieżącego jasnego/ciemnego ustawienia Twojego Maca.
   - **Jasny** — zawsze używaj jasnej palety.
   - **Ciemny** — zawsze używaj ciemnej palety.

![Strona ustawień Kolory pokazująca menu Wygląd i niestandardowe studnie kolorów paneli](screenshots/settings-colors.png)
*(Rysunek: strona Kolory: wybierz wygląd i zastąp poszczególne kolory paneli.)*

## Dostosuj kolory paneli

Na tej samej stronie **Kolory**, w sekcji **Niestandardowe kolory paneli**, zaznacz pole obok dowolnego elementu i wybierz kolor ze studni obok:

- **Tekst** — nazwy plików i folderów.
- **Tło** — tło panelu.
- **Zaznaczony tekst** — kolor używany dla oznaczonych plików.
- **Ramka kursora** — obrys wokół bieżącego elementu.

Pozostaw pole niezaznaczone, aby zachować wbudowany kolor tego elementu. Kliknij **Przywróć domyślne**, aby wyczyścić wszystkie zastąpienia naraz.

## Koloruj pliki według typu

1. Otwórz Konfiguracja > Opcje… i wybierz stronę **Widok**.
2. Kliknij **Kolory typów plików…**.
3. Dodaj regułę z maską nazwy, taką jak `*.zip` lub `*.txt`, a następnie wybierz kolor dla pasujących plików.
4. Użyj **Dodaj regułę** dla większej liczby masek; kliknij **Gotowe**, aby zapisać, lub **Anuluj**, aby odrzucić.

Pasujące pliki pojawią się wtedy w wybranym kolorze w obu panelach.

## Dostosuj rozmiar czcionki i format daty

Na stronie **Widok** możesz również:

- Wybrać **rozmiar czcionki** listy paneli w punktach.
- Wprowadzić wzorzec **formatu daty**, aby kontrolować sposób wyświetlania dat modyfikacji; pozostaw puste, aby użyć formatu regionalnego Twojego Maca. Pod polem pojawia się podgląd na żywo w miarę pisania.
- Włączyć **Naprzemienne tło wierszy** dla paskowania typu zebra, które ułatwia przeglądanie długich list.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz ustawienia | Cmd+, |

## Uwagi

- Menu Wygląd działa tylko wtedy, gdy motyw to **System (domyślnie)**; motyw sam określa swoją podstawę.
- Motyw koloruje także własne okna programu. Okna systemowe — Otwórz, Zapisz, próbniki koloru i czcionki oraz alerty — zachowują standardowy wygląd, podobnie jak okna otwierane przez wtyczki.
- Ustawienie wyglądu stylizuje panele plików. Okna dialogowe systemu, alerty i standardowe elementy sterujące zawsze podążają za macOS.
- Wbudowana przeglądarka plików używa dopasowanych jasnych i ciemnych palet podświetlania składni, dzięki czemu podświetlony kod pozostaje czytelny w obu wyglądach.
- Niestandardowe kolory i reguły typów plików są zapisywane z Twoimi ustawieniami i stosowane ponownie za każdym razem, gdy otwierasz aplikację.
