---
title: Wygląd
slug: appearance
section: Dostosowywanie
order: 114
related: [settings]
---

Peach Commander może dopasować się do wyglądu reszty Twojego Maca lub przybrać własny styl. Możesz podążać za jasnym lub ciemnym ustawieniem systemu (albo wymusić jedno z nich), zmienić kolory paneli plików, wyróżnić pliki według typu oraz dostosować rozmiar czcionki listy i format daty, aby panele czytały się dokładnie tak, jak lubisz.

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

- Ustawienie wyglądu stylizuje panele plików. Okna dialogowe systemu, alerty i standardowe elementy sterujące zawsze podążają za macOS.
- Wbudowana przeglądarka plików używa dopasowanych jasnych i ciemnych palet podświetlania składni, dzięki czemu podświetlony kod pozostaje czytelny w obu wyglądach.
- Niestandardowe kolory i reguły typów plików są zapisywane z Twoimi ustawieniami i stosowane ponownie za każdym razem, gdy otwierasz aplikację.
