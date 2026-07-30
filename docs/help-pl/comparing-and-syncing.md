---
title: Porównywanie i synchronizacja
slug: comparing-and-syncing
section: Zaawansowane narzędzia
order: 90
related: [multi-rename]
---

Gdy przechowujesz dwie kopie tego samego folderu — folder roboczy i kopię zapasową, laptop i udział sieciowy, projekt i jego archiwum — Peach Commander pomaga zobaczyć dokładnie, co się zmieniło, i przywrócić obie strony do zgodności. Możesz synchronizować dwa katalogi, porównywać poszczególne pliki wiersz po wierszu oraz sprawdzać pliki bajt po bajcie, gdy potrzebujesz pewności co do ostatniego znaku.

## Synchronizuj dwa katalogi

1. Otwórz folder, który chcesz zsynchronizować, w lewym panelu, a folder do porównania z nim w prawym panelu.
2. Wybierz **Polecenia ▸ Synchronizuj katalogi…**. Ścieżki obu folderów są wypełniane z Twoich paneli.
3. Ustaw, jak dokładne ma być porównanie: uwzględnij podfoldery, porównuj **według zawartości** (nie tylko według daty i rozmiaru) lub ignoruj datę modyfikacji.
4. Dodaj maskę filtra (na przykład `*.jpg;*.png`), jeśli chcesz synchronizować tylko określone pliki.
5. Przejrzyj siatkę wyników. Każdy wiersz pokazuje plik po lewej, strzałkę kierunku pośrodku i pasujący plik po prawej. Strzałki mówią, co się stanie: **→** kopiuje z lewej na prawą, **←** kopiuje z prawej na lewą, a **=** oznacza, że oba są identyczne.
6. Dostosuj poszczególne wiersze, jeśli nie zgadzasz się z sugerowanym kierunkiem, a następnie kliknij przycisk synchronizacji, aby przeprowadzić zmiany.

![Okno synchronizacji katalogów z dwiema ścieżkami folderów i siatką wyników plików ze strzałkami w lewo, równości i w prawo](screenshots/sync-dialog.png)
*(Rysunek: okno Synchronizuj katalogi porównuje obie strony i proponuje kierunek kopiowania dla każdego pliku.)*

## Porównaj dwa pliki według zawartości

1. Zaznacz jeden plik w każdym panelu (lub dwa pliki w tym samym panelu).
2. Wybierz **Plik ▸ Porównaj według zawartości…**.
3. Oba pliki otwierają się obok siebie z podświetlonymi różnicami. Użyj elementów sterujących następny/poprzedni, aby przeskakiwać między zmienionymi blokami.
4. Jeśli włączysz tryb edycji, możesz dostosować dowolny plik bezpośrednio i zapisać zmiany.

![Okno porównania pokazujące dwa pliki tekstowe obok siebie z podświetlonymi różniącymi się wierszami](screenshots/diff-window.png)
*(Rysunek: porównywanie dwóch plików tekstowych; zmienione wiersze są podświetlone po obu stronach.)*

## Porównaj pliki bajt po bajcie

Gdy dwa pliki wyglądają tak samo, ale musisz udowodnić, że są naprawdę identyczne (lub znaleźć ten jeden różniący się bajt), użyj porównania binarnego. Pokazuje oba pliki w widoku szesnastkowym z zaznaczonymi niepasującymi bajtami, co jest idealne do weryfikacji pobranych plików, sprawdzania zakodowanych danych lub potwierdzania dokładnej kopii.

## Porównaj listy katalogów

Aby dostrzec różnice między dwoma otwartymi folderami na pierwszy rzut oka, wybierz **Zaznacz ▸ Porównaj katalogi** (Shift+F2). Peach Commander oznaczy pliki, które się różnią lub brakuje ich po drugiej stronie, dzięki czemu możesz na nich działać zwykłymi poleceniami kopiowania, przenoszenia i usuwania.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Porównaj listy katalogów (oznacz różniące się pliki) | Shift+F2 |
| Porównaj według zawartości | Plik ▸ Porównaj według zawartości… |
| Synchronizuj katalogi | Polecenia ▸ Synchronizuj katalogi… |

## Uwagi

- **Według zawartości a według daty/rozmiaru.** Szybkie porównanie dopasowuje pliki według rozmiaru i daty modyfikacji, co jest szybkie, ale można je oszukać, gdy znaczniki czasu różnią się dla identycznych plików. Włącz **według zawartości** dla wiarygodnego wyniku kosztem odczytu każdego pliku.
- **Podfoldery i filtry.** Okno synchronizacji może schodzić do podfolderów i można je ograniczyć maską filtra, więc możesz synchronizować tylko interesujące Cię typy plików.
- **Zachowujesz kontrolę.** Synchronizacja nigdy nie działa sama — przeglądasz proponowane kierunki w siatce wyników i możesz zmienić dowolny z nich, zanim cokolwiek zostanie skopiowane.
- **Ustawienia wstępne.** Często używane konfiguracje synchronizacji można zapisać i użyć ponownie, dzięki czemu nie musisz za każdym razem wpisywać tych samych opcji.
