---
title: Pasek przycisków
slug: toolbar
section: Dostosowywanie
order: 110
related: [keyboard-shortcuts, settings]
---

Pasek przycisków to pas przycisków z ikonami wzdłuż górnej części okna. Każdy przycisk to skrót jednego kliknięcia, który sam definiujesz: uruchom wbudowane polecenie, uruchom zewnętrzny program lub aplikację, przeskocz do folderu, lub otwórz cały podpasek dodatkowych przycisków. Jest to najszybszy sposób, aby mieć akcje, których używasz najczęściej, w zasięgu ręki, i możesz go dopasować dokładnie do sposobu, w jaki pracujesz.

## Dostosuj pasek przycisków

1. Wybierz **Konfiguracja > Dostosuj pasek narzędzi…**, lub kliknij pasek prawym przyciskiem i wybierz **Edytuj pasek przycisków…**.
2. Lista po lewej pokazuje bieżące przyciski. Użyj **+**, aby dodać przycisk, **—**, aby dodać separator, **−**, aby usunąć zaznaczony przycisk, i **↑ / ↓**, aby zmienić kolejność.
3. Zaznacz przycisk i wypełnij formularz po prawej:
   - **Polecenie** — wpisz wbudowane polecenie, lub kliknij **Wybierz…**, aby wybrać jedno z listy. Możesz również wprowadzić ścieżkę programu lub aplikacji, folder do otwarcia, albo inny pasek przycisków do użycia jako podpasek.
   - **Podpis** — etykieta i podpowiedź pokazywane dla przycisku.
   - **Parametry** i **Ścieżka początkowa** — przekazywane do programów zewnętrznych. Symbole zastępcze, takie jak `%P` (folder źródłowy), `%N` (bieżący plik) i `%S` (wybrane pliki), są wypełniane przy uruchomieniu przycisku.
   - **Ikona** — wybierz SF Symbol lub użyj własnej ikony pliku bądź aplikacji; włącz **tylko ikona**, aby ukryć podpis.
4. Kliknij **Zapisz**. Pas ładuje się ponownie od razu.

![Pasek przycisków wzdłuż górnej części okna z przyciskami z ikonami](screenshots/button-bar-crop.png)
*(Rysunek: pasek przycisków znajduje się nad panelami plików; każdy przycisk uruchamia polecenie, program, folder lub podpasek.)*

## Podpaski i przepełnienie

Przycisk może otworzyć *podpasek* — drugi zestaw przycisków nałożony na pierwszy. Kliknij go, aby zejść; przycisk **◀** po lewej cofa Cię do poprzedniego paska. Gdy jest więcej przycisków, niż mieści się w szerokości okna, nadmiarowe zwijają się za strzałką **»** na prawym końcu; kliknij ją, aby do nich dotrzeć.

## Dodaj program, upuszczając go na pasek

Nie musisz otwierać edytora, aby umieścić narzędzie na pasku. Przeciągnij program, aplikację lub skrypt z panelu — albo z Findera — na **wolne miejsce** paska. Kreska pokazuje, gdzie wyląduje; po upuszczeniu powstaje tam przycisk.

- **Programy, aplikacje i skrypty** stają się przyciskiem, który uruchamia je na bieżącym zaznaczeniu: parametry nowego przycisku to `%S`, czyli nazwy zaznaczonych plików. Wyczyść to pole w edytorze, jeśli narzędzie nie ma otrzymywać argumentów.
- **Foldery** stają się przyciskiem, który do nich przechodzi — i który kopiuje do nich pliki, gdy później je na nim upuścisz.
- To, czego nie da się uruchomić, jest odrzucane: zwykły dokument nie ma prawa wykonywania, a przycisk dla niego zawiódłby przy pierwszym kliknięciu.

Upuszczenie na **istniejący** przycisk zachowuje jego znaczenie: przycisk uruchamia się z upuszczonymi plikami. Nowy powstaje tylko na wolnym miejscu.

## Upuść pliki na przycisk

Możesz przeciągnąć pliki lub foldery bezpośrednio na przycisk:

- **Przycisk folderu** — upuszczone elementy są kopiowane do tego folderu w tle.
- **Przycisk programu** — program uruchamia się z upuszczonymi elementami jako swoim wyborem.
- **Przycisk polecenia** — polecenie uruchamia się jak zwykle.

## Ukryj pasek przycisków

Wybierz **Widok > Pasek przycisków**, aby ukryć pasek, i ponownie, aby go przywrócić. Ten sam przełącznik jest na stronie **Układ** w ustawieniach, a wybór jest zapamiętywany.

## Pionowy pasek przycisków

Aby przenieść pas z górnej części okna do kolumny wzdłuż lewej strony, wybierz **Widok > Pionowy pasek przycisków**. Wybierz go ponownie, aby wrócić do poziomego pasa.

## Uwagi

- Pasek jest przechowywany w standardowym pliku paska przycisków zgodnym z Total Commanderem, więc paski, które już masz, można ponownie wykorzystać.
- Do tych akcji domyślnie nie są przypisane żadne skróty klawiaturowe, ale możesz dodać własne — zobacz [Skróty klawiaturowe](keyboard-shortcuts).
- Przycisk bez ikony i bez polecenia pokazuje się jako zwykły separator, przydatny do grupowania powiązanych przycisków.
