---
title: Uninstaller
slug: uninstaller
section: Wtyczki
order: 126
related: [plugins, deleting-files]
---

Przeciągnięcie aplikacji do Kosza zostawia jej pliki pomocnicze, pamięci podręczne, preferencje i kontenery rozrzucone po Twoich folderach Library. Wtyczka Uninstaller usuwa aplikację **oraz** te pozostałości: znajduje wszystko, co aplikacja po sobie zostawiła, pokazuje Ci listę z rozmiarem każdej pozycji i przenosi to wszystko do Kosza po Twoim potwierdzeniu. Jest to wtyczka, więc możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Odinstaluj aplikację pod kursorem

1. Ustaw kursor na aplikacji (`.app`) w panelu.
2. Wybierz **Plik ▸ Odinstaluj aplikację…**, lub kliknij prawym przyciskiem ▸ **Odinstaluj aplikację…**, lub naciśnij **Cmd+Shift+U**.
3. Otwiera się okno przeglądu, wymieniające aplikację oraz każdy powiązany plik, który znalazła, każdy opisany swoją kategorią, ścieżką i rozmiarem.
4. Odznacz wszystko, co chcesz zachować, a następnie kliknij **Przenieś do Kosza** (lub **Usuń trwale**).

![Okno przeglądu odinstalowania wymieniające pozostałe pliki aplikacji z polami wyboru i rozmiarami](screenshots/uninstaller.png)
*(Rysunek: przejrzyj dokładnie, co zostanie usunięte, zanim cokolwiek zostanie skasowane.)*

## Przeglądaj wszystkie zainstalowane aplikacje

Wybierz **Polecenia ▸ Odinstaluj aplikację…**, aby otworzyć przeszukiwalną listę aplikacji zainstalowanych na Twoim Macu, z nazwą, rozmiarem i datą instalacji każdej aplikacji. Wybierz jedną (lub kilka), kliknij **Odinstaluj…** i trafiasz do tego samego okna przeglądu. Możesz filtrować listę, wpisując tekst w polu wyszukiwania.

## Znajdź pozostałe pliki

Wybierz **Polecenia ▸ Znajdź pozostałe pliki…**, aby przeskanować w poszukiwaniu plików pomocniczych, pamięci podręcznych i preferencji należących do aplikacji, które **już** usunąłeś. Przejrzyj je w ten sam sposób i wyczyść. Jeśli nic nie zostanie znalezione, wtyczka Cię o tym informuje.

## Jak dokładnie skanować

Okno przeglądu ma element sterujący poziomem pewności:

- **Precyzyjne** — pliki zakotwiczone w identyfikatorze pakietu aplikacji. Wysoka pewność; wybrane wstępnie.
- **Rozszerzone** — dodaje pliki dopasowane po nazwie; pozostawione odznaczone, abyś mógł zdecydować.
- **Głębokie** — Rozszerzone plus przeszukanie Spotlight w poszukiwaniu wszystkiego innego wspominającego aplikację; również pozostawione odznaczone.

## Uwagi

- Nic nie jest usuwane bezpośrednio przez wtyczkę — pozycje przechodzą przez Kosz aplikacji lub trwałe usunięcie, dokładnie jak każda inna operacja na plikach. Usuwanie plików w `/Library` lub `/var` może wymagać hasła administratora.
- Przed usunięciem wtyczka zamyka działającą aplikację i wyładowuje jej elementy tła (launchd), a następnie proponuje uporządkowanie wszelkich pustych już folderów producenta.
- Jeśli aplikacja została zainstalowana za pomocą **Homebrew**, wtyczka ostrzega Cię i sugeruje `brew uninstall --cask`, aby Homebrew pozostał zsynchronizowany. Aplikacje z App Store również są odnotowywane.
- Dopasowania Rozszerzone i Głębokie mają z założenia niższą pewność i zaczynają odznaczone — przejrzyj je przed usunięciem. Niektórych elementów tła zainstalowanych za pomocą nowoczesnego API elementów logowania nie da się tutaj usunąć.
