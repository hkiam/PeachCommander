---
title: Wyszukiwanie plików
slug: searching
section: Wyszukiwanie plików
order: 60
related: [selecting-files, quick-search-and-filter]
---

Gdy potrzebujesz wytropić pliki gdziekolwiek na swoim Macu — po nazwie, po tym, co zawierają, lub po rozmiarze i dacie — użyj okna Znajdź pliki. Przeszukuje ono jeden lub więcej folderów (i ich podfoldery), potrafi zaglądać do wnętrza plików tekstowych i archiwów oraz pozwala wysłać wszystko, co znajdzie, prosto do panelu, dzięki czemu możesz działać na wynikach jak na zwykłym folderze.

## Znajdź pliki po nazwie

1. W panelu pokazującym folder, który chcesz przeszukać, wybierz **Polecenia > Znajdź pliki…** (lub naciśnij Cmd+Shift+F).
2. Na karcie **Ogólne** wpisz wzorzec nazwy w polu **Szukaj**. Możesz używać symboli wieloznacznych, takich jak `*.pdf` lub `raport_*.docx`. Aby przeszukać kilka folderów naraz, wymień je w polu folderu początkowego rozdzielone średnikiem (`;`).
3. Kliknij **Start**. Dopasowania pojawiają się na liście wyników poniżej w miarę ich znajdowania.
4. Kliknij dwukrotnie dowolny wynik, aby przeskoczyć do tego pliku w aktywnym panelu, lub zaznacz wynik i kliknij **Wyświetl** (F3), aby otworzyć go we wbudowanej przeglądarce.

![Okno Znajdź pliki na karcie Ogólne, pokazujące wzorzec nazwy, folder i listę wyników](screenshots/find-files-general.png)
*(Rysunek: karta Ogólne — wyszukiwanie według wzorca nazwy w jednym lub kilku folderach.)*

## Szukaj według zawartości, rozmiaru i daty

1. Aby szukać wewnątrz plików, wpisz tekst w polu **Znajdź tekst** na karcie Ogólne — szukane jest to, co znajduje się w polu, a puste pole szuka tylko po nazwach. Opcje pozwalają uczynić go **z uwzględnieniem wielkości**, dopasować tylko **całe słowo**, traktować tekst jako **wyrażenie regularne**, wykonać **szesnastkowe wyszukiwanie zawartości** lub znaleźć pliki **niezawierające** tekstu.
2. Przełącz na kartę **Zaawansowane**, aby zawęzić wyniki według **rozmiaru** (na przykład od `10K` do `5M`), według zakresu **daty modyfikacji** lub do plików zmienionych w ciągu ostatnich N dni.
3. Włącz **Szukaj wewnątrz archiwów**, aby zajrzeć do znalezionych archiwów — te same formaty, które otwierasz klawiszem Enter, w tym dodane przez wtyczkę pakującą. Archiwa, których nie udało się otworzyć, są zgłaszane po zakończeniu wyszukiwania.
4. Aby ograniczyć wyszukiwanie do tego, co już wybrałeś, włącz **Szukaj tylko w zaznaczonych elementach** przed startem.
5. Włącz **Szukaj także w komentarzach plików** i tekst będzie szukany w komentarzu każdego pliku obok jego treści. Tak odnajdziesz plik po tym, co o nim napisałeś — „oryginał klienta”, „zastąpione eksportem 2026” — gdy w samym pliku nic takiego nie ma. Wynik znaleziony w ten sposób pokazuje komentarz zamiast wiersza pliku i żadnego numeru wiersza, bo trafienie nie leży w tekście pliku. Wielkość litery, całe słowo i wyrażenia regularne dotyczą komentarza tak samo jak treści; wyszukiwanie szesnastkowe nie, bo komentarz to wpisany tekst. **Nie zawierające** pozostaje spójne: plik trafia na listę, gdy tekstu nie ma ani w treści, ani w komentarzu. Gdy wtyczka Notatki jest włączona, jej notatka jest dostępna jako pole treści, na które można nałożyć warunek w sekcji **Plugins** — zobacz [Praca z wtyczkami](plugins.md).
6. Niektóre wtyczki potrafią zamienić plik na tekst, którego sam plik nie zawiera — wtyczka dekompilatora zamienia `.class` na źródło Javy. Włącz **Szukaj w tekście dostarczanym przez wtyczki** i takie pliki będą przeszukiwane jako ten tekst, a nie jako własne bajty, więc zwrot ze źródła znajdzie się w skompilowanej klasie. Opcja pojawia się tylko wtedy, gdy taka wtyczka jest zainstalowana, i jest wolniejsza: wytworzenie tekstu może oznaczać jeden dekompilator na plik.

![Okno Znajdź pliki na karcie Zaawansowane, pokazujące filtry rozmiaru i daty](screenshots/find-files-advanced.png)
*(Rysunek: karta Zaawansowane — filtruj według rozmiaru, daty i innych atrybutów.)*

Jeśli masz wtyczki dodające pola zawartości (jak wymiary obrazów), karta **Wtyczki** pozwala wymagać, aby pole spełniało warunek — na przykład tylko obrazy szersze niż 1000 pikseli.

![Okno Znajdź pliki na karcie Wtyczki, pokazujące warunek na polu zawartości](screenshots/find-files-plugins.png)
*(Rysunek: karta Wtyczki — dopasowanie na polach zawartości dostarczanych przez wtyczki.)*

## Szybkie wyszukiwania ze Spotlight

W przypadku folderów lokalnych, które macOS już zindeksował, włącz **Użyj Spotlight** na karcie Ogólne, aby uzyskać niemal natychmiastowe wyniki. Spotlight przeszukuje indeks zamiast skanować pliki, więc ignoruje wyrażenia regularne, limity głębokości podfolderów i zakres tylko-zaznaczone.

## Ponowne użycie i przekazanie wyników

- **Wyślij do listy** umieszcza każdy wynik w aktywnym panelu jako tymczasową listę, dzięki czemu możesz skopiować, przenieść lub usunąć cały zestaw naraz.
- Na karcie **Wczytaj / Zapisz** wybierz **Zapisz jako szablon…**, aby zapamiętać bieżące wyszukiwanie (wzorce i opcje) i wybrać je ponownie później z listy szablonów.
- Pola **Szukaj** i **Znajdź tekst** zapamiętują po 20 ostatnio użytych wpisów, od najnowszego — kliknij strzałkę na końcu pola, aby wybrać któryś ponownie. Ten sam termin użyty dwa razy wraca na górę, zamiast pojawiać się dwukrotnie, a listy przetrwają zamknięcie okna i zakończenie aplikacji. **Wyczyść historię…** na karcie **Wczytaj / Zapisz** zapomina obie; zapisanych szablonów to nie dotyczy.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz Znajdź pliki | Cmd+Shift+F lub Option+F7 |
| Rozpocznij / zatrzymaj wyszukiwanie | Przycisk Start w oknie |
| Wyświetl zaznaczony wynik | F3 |

## Uwagi

- Wyszukiwanie w treści czyta całe pliki w folderach lokalnych i w archiwach; w lokalizacjach sieciowych bardzo duże pliki są czytane tylko częściowo (około 16 MB lub 64 MB przy wyrażeniu regularnym).
- Wyszukiwanie wewnątrz archiwów schodzi do czterech poziomów zagnieżdżonych archiwów.
- **Uwzględnij foldery w wynikach** wymienia również foldery, których nazwy pasują, nie tylko pliki.
- Spotlight obejmuje tylko zindeksowane foldery lokalne; w przypadku lokalizacji sieciowych lub dopasowania opartego na wzorcach pozostaw go wyłączonym i pozwól, aby Znajdź pliki skanowało.
