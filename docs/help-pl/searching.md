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

1. Aby szukać wewnątrz plików, wybierz **Znajdź tekst** na karcie Ogólne i wpisz tekst do wyszukania. Opcje pozwalają uczynić go **z uwzględnieniem wielkości**, dopasować tylko **całe słowo**, traktować tekst jako **wyrażenie regularne**, wykonać **szesnastkowe wyszukiwanie zawartości** lub znaleźć pliki **niezawierające** tekstu.
2. Przełącz na kartę **Zaawansowane**, aby zawęzić wyniki według **rozmiaru** (na przykład od `10K` do `5M`), według zakresu **daty modyfikacji** lub do plików zmienionych w ciągu ostatnich N dni.
3. Włącz **Szukaj wewnątrz archiwów**, aby zaglądać do archiwów rodziny zip (zip, jar, war i podobnych).
4. Aby ograniczyć wyszukiwanie do tego, co już wybrałeś, włącz **Szukaj tylko w zaznaczonych elementach** przed startem.

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

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz Znajdź pliki | Cmd+Shift+F lub Option+F7 |
| Rozpocznij / zatrzymaj wyszukiwanie | Przycisk Start w oknie |
| Wyświetl zaznaczony wynik | F3 |

## Uwagi

- Wyszukiwanie zawartości odczytuje całe pliki dla folderów lokalnych; w innych lokalizacjach bardzo duże pliki są pomijane (około 16 MB, lub 64 MB przy użyciu wyrażenia regularnego).
- Wyszukiwanie wewnątrz archiwów schodzi do czterech poziomów zagnieżdżonych archiwów.
- **Uwzględnij foldery w wynikach** wymienia również foldery, których nazwy pasują, nie tylko pliki.
- Spotlight obejmuje tylko zindeksowane foldery lokalne; w przypadku lokalizacji sieciowych lub dopasowania opartego na wzorcach pozostaw go wyłączonym i pozwól, aby Znajdź pliki skanowało.
