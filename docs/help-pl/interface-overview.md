---
title: Okno główne
slug: interface-overview
section: Pierwsze kroki
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander pokazuje dwie listy plików obok siebie, dzięki czemu jednocześnie widzisz, skąd pliki pochodzą i dokąd trafiają. Większość pracy odbywa się w tych dwóch panelach; paski wokół nich pozwalają przełączać dyski, przechodzić do folderu i uruchamiać najczęstsze polecenia na plikach bez odrywania rąk od klawiatury. Ten przewodnik nazywa każdą część okna, aby reszta pomocy była zrozumiała.

![Główne okno Peach Commander z dwoma panelami i otaczającymi paskami](screenshots/main-window.png)
*(Rysunek: Okno główne — dwa panele z paskiem przycisków, paskiem dysków i paskami ścieżki u góry oraz paskiem klawiszy funkcyjnych na dole.)*

## Dwa panele i panel aktywny

Okno jest podzielone na panel lewy i panel prawy, z których każdy pokazuje zawartość jednego folderu. W danej chwili aktywny jest tylko jeden panel: wyświetla on kursor (wyróżniony wiersz), a jego pasek ścieżki jest rysowany na kolorowym tle. Polecenia takie jak kopiowanie i przenoszenie zawsze działają na panelu aktywnym i wysyłają pliki do drugiego.

1. Kliknij w dowolnym miejscu panelu, aby uczynić go aktywnym, lub naciśnij Tab, aby przełączać się między nimi.
2. Klawiszami strzałek przesuwaj kursor w górę i w dół aktywnego panelu.
3. Naciśnij Enter na folderze, aby go otworzyć, lub na `..` na górze listy, aby przejść o poziom wyżej.

## Paski wokół paneli

- **Pasek przycisków** (na górze): rząd płaskich przycisków dla częstych poleceń. Kliknij przycisk, aby uruchomić jego polecenie; kliknij przycisk prawym przyciskiem myszy, aby edytować pasek.
- **Pasek napędów**: jeden przycisk na każdy dostępny dysk lub wolumin, przy każdym wolne miejsce. Kliknij wolumin, aby przełączyć do niego ten panel; kliknij prawym przyciskiem, aby go wysunąć — dostępne dla woluminów wymiennych i zamontowanych obrazów dysków, wyszarzone dla dysku startowego i udziałów sieciowych.
- **Pasek ścieżki**: pokazuje bieżący folder jako klikalną ścieżkę nawigacyjną. Kliknij segment, aby przejść bezpośrednio do tego folderu, lub kliknij ścieżkę, aby wpisać lokalizację.
- **Pasek stanu** (pod każdą listą): bieżące podsumowanie panelu — ile plików i folderów jest zaznaczonych oraz ich łączny rozmiar.
- **Wiersz poleceń** (na dole): pole tekstowe, w którym możesz wpisać polecenie w stylu powłoki, uruchamiane w bieżącym folderze.
- **Pasek klawiszy funkcyjnych** (na samym dole): sześć przycisków oznaczonych F3 Podgląd, F4 Edytuj, F5 Kopiuj, F6 Przenieś, F7 NowyFolder i F8 Usuń. Kliknij przycisk lub naciśnij odpowiadający mu klawisz.

![Zbliżenie paska dysków pokazujące przyciski woluminów i wolne miejsce](screenshots/drive-bar-crop.png)
*(Rysunek: pasek napędów — jeden przycisk na wolumin, z pozostałym wolnym miejscem; kliknij wolumin prawym przyciskiem, aby go wysunąć.)*

## Skróty

| Akcja | Skrót |
|---|---|
| Przełącz aktywny panel | Tab |
| Otwórz folder / element pod kursorem | Enter |
| Przejdź o folder wyżej | Backspace |
| Podgląd pliku | F3 |
| Edytuj plik | F4 |
| Kopiuj do drugiego panelu | F5 |
| Przenieś / zmień nazwę do drugiego panelu | F6 |
| Nowy folder | F7 |
| Usuń (do Kosza) | F8 |

## Uwagi

- Pasek klawiszy funkcyjnych zmienia swoje etykiety na żywo, gdy przytrzymasz modyfikator. Przytrzymanie na przykład klawisza Shift zmienia F6 na akcję zmiany nazwy w miejscu, więc przyciski zawsze pokazują, co klawisze zrobią w danej chwili.
- Niemal każdy pasek można pokazać lub ukryć. Zajrzyj do menu Widok i Konfiguracja, aby włączyć lub wyłączyć pasek przycisków, pasek dysków, wiersz poleceń albo pasek klawiszy funkcyjnych, lub aby ułożyć oba panele jeden nad drugim zamiast obok siebie.
- Na wielu klawiaturach Mac klawisze F domyślnie działają jako sterowanie multimediami i jasnością. Przytrzymaj klawisz Fn razem z F3-F8 lub włącz „Używaj klawiszy F1, F2 itp. jako standardowych klawiszy funkcyjnych" w Ustawieniach systemowych, aby używać ich bezpośrednio.
