---
title: Pobieranie z adresu URL
slug: downloading-from-url
section: Sieć i dostęp zdalny
order: 102
related: [ftp-and-sftp]
---

Peach Commander może pobrać plik prosto z adresu internetowego HTTP lub HTTPS do aktywnego panelu, bez otwierania przeglądarki. Wklej łącze, potwierdź nazwę, pod którą zostanie zapisany, a pobieranie przebiega samo — ze wznawianiem, jeśli połączenie zostanie zerwane, pobieraniem wsadowym wielu łączy naraz i opcjonalną weryfikacją sumy kontrolnej, dzięki której wiesz, że plik dotarł nienaruszony.

## Pobierz plik

1. Otwórz folder panelu, w którym chcesz umieścić plik.
2. Wybierz **Sieć > Pobierz z adresu URL** lub naciśnij Cmd+Shift+U.
3. Wklej adres internetowy w polu **Adres(y) URL**. Jeśli wcześniej skopiowałeś łącze, jest ono wypełniane za Ciebie.
4. Sprawdź nazwę **Zapisz jako** — jest sugerowana na podstawie łącza i możesz ją dowolnie edytować.
5. Kliknij **Pobierz**.

![Okno dialogowe Pobierz z adresu URL z łączem, edytowalną nazwą pliku i opcjami](screenshots/download-url.png)
*(Rysunek: okno dialogowe pobierania — wklej łącze, edytuj nazwę i ustaw opcjonalną weryfikację, dane uwierzytelniające, nagłówki lub serwer proxy.)*

Domyślnie pobieranie działa **w tle**, więc możesz kontynuować pracę w panelach podczas transferu. Wyłącz **Pobierz w tle**, aby na nie czekać, lub włącz **Dodaj do kolejki na później**, aby skonfigurować je bez rozpoczynania.

## Pobierz kilka plików naraz

Wklej jeden adres internetowy w wierszu w polu **Adres(y) URL**. Gdy obecnych jest więcej niż jedno łącze, nazwa każdego pliku jest wyprowadzana automatycznie z jego łącza, a pola **Zapisz jako** i **Weryfikuj** dla poszczególnych plików są wyłączane.

## Wznawianie przerwanego pobierania

Jeśli transfer zostanie przerwany, Peach Commander zachowuje to, co już otrzymał, w tymczasowym pliku `.part`. Ponowne uruchomienie tego samego pobierania wznawia je od miejsca, w którym się zatrzymało, ilekroć serwer to obsługuje, zamiast zaczynać od nowa. Plik `.part` otrzymuje ostateczną nazwę dopiero po pomyślnym zakończeniu pobierania.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Pobierz z adresu URL | Cmd+Shift+U |

## Wskazówki

- **Zweryfikuj plik.** W przypadku pojedynczego pobierania wklej oczekiwaną sumę kontrolną **SHA-256** w polu **Weryfikuj**. Po transferze suma kontrolna pliku jest z nią porównywana, dzięki czemu możesz zaufać, że plik odpowiada temu, co podał wydawca.
- **Wymagane logowanie?** Wprowadź nazwę użytkownika i hasło w polach **Uwierz.** dla witryn korzystających z uwierzytelniania podstawowego. W przypadku dostępu opartego na tokenie dodaj wiersz `Authorization: Bearer …` w polu **Nagłówki**.
- **Niestandardowe nagłówki.** Dodaj jeden nagłówek w wierszu w polu **Nagłówki**, na przykład `Referer: …` lub `Cookie: …`, dla łączy, które działają tylko z określonymi nagłówkami żądania.
- **Serwer proxy.** Przekieruj pobieranie przez serwer proxy HTTP lub SOCKS5, wypełniając host, port i typ **Proxy**.
- **Niezaufane certyfikaty.** Włącz **Zezwól na niezaufany certyfikat** tylko dla zaufanej witryny używającej certyfikatu z podpisem własnym; wyłącza to normalną kontrolę bezpieczeństwa HTTPS dla tego pobierania.
- **Uwaga:** skrót był Cmd+Shift+D, którego używa też Idź ▸ Biurko — jeden z dwóch nigdy nie działał. Pobieranie jest teraz na Cmd+Shift+U (U jak URL), a Biurko zachowuje Cmd+Shift+D, tak jak w Finderze.
