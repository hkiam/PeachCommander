---
title: Przestrzenie robocze
slug: workspaces
section: Dostosowywanie
order: 118
related: [settings, panels-and-tabs]
---

Obszar roboczy to nazwany kontekst, w którym pracujesz: „Porządkowanie kopii zapasowych”, „Sortowanie dokumentów kandydatów”. Każdy pamięta oba panele, wszystkie otwarte karty, która karta jest aktywna po której stronie, tryb widoku, drzewo folderów, historię wstecz/dalej oraz które pliki były zaznaczone, szybki filtr oraz układ okna — panel boczny, dok, paski i położenie linii podziału. Przełączenie kosztuje jedno kliknięcie i po drodze nigdy nic nie ginie — obszar roboczy nigdy nie jest zapisywany, ponieważ nigdy się nie kończy.

Dopóki nie utworzysz drugiego, nie ma czego oglądać. Żadnego paska, żadnego menu, żadnych skrótów.

## Jak to zrobić

1. Przygotuj oba panele do bieżącego zadania: otwórz foldery, dodaj karty, wybierz żądany widok.
2. Otwórz menu **Idź** i wybierz **Obszary robocze…**, następnie **Nowy obszar roboczy…**. Nadaj mu nazwę.
3. U góry okna pojawia się pasek kolorowych plakietek, a na pasku menu pojawia się menu **Obszar roboczy**. Nowy obszar roboczy zaczyna jako kopia układu, w którym byłeś.
4. Przygotuj nowy obszar roboczy do jego własnego zadania. Ten, z którego przyszedłeś, zachowa to, co miał.
5. Kliknij plakietkę, aby przełączyć, albo naciśnij **Ctrl+1** do **Ctrl+9**. Przełącza się wszystko.

## Powrót do punktu wyjścia

Każdy obszar roboczy pamięta również układ, z jakim został utworzony. **Obszar roboczy ▸ Zapisz bieżący stan w obszarze roboczym** (Cmd+Ctrl+S) czyni bieżący układ tym punktem wyjścia, a **Przywróć zapisany stan** sprowadza tam z powrotem po popołudniu błądzenia.

Jest to niezależne od ciągłego zapamiętywania: nigdy nie musisz zapisywać, żeby nie stracić swojego miejsca.

## Schowek

Każdy obszar roboczy ma schowek — na to, co przy porządkach naprawdę się zdarza: trzy foldery w głąb
kopii zapasowych znajdujesz coś, co należy do zupełnie innego zadania. **Przeciągnij pliki na plakietkę
innego obszaru**, a wylądują w *jego* schowku: nie przełączasz się, nic nie jest kopiowane ani
przenoszone; licznik na plakietce rośnie, a ty pracujesz dalej. Przytrzymaj **⌥** przy upuszczaniu, aby
zamiast tego skopiować do folderu tamtego obszaru, albo **⌘**, aby przenieść. **Ctrl+Cmd+A** wkłada
zaznaczenie do schowka bieżącego obszaru, strona **Schowek** w panelu bocznym pokazuje zawartość, a
**Obszar roboczy ▸ Kopiuj schowek do drugiego panelu** załatwia cały schowek w jednej operacji.

Pliki usunięte w międzyczasie lub leżące na niezamontowanym woluminie są pokazywane jako brakujące,
zamiast zostać usunięte, a operacja zbiorcza proponuje je pominąć albo najpierw wyjąć ze schowka.
Przeniesienie opróżnia schowek z przeniesionego; kopiowanie zostawia go bez zmian.

| Działanie | Skrót |
| --- | --- |
| Przełącz na obszar roboczy 1 do 9 | Ctrl+1 … Ctrl+9 |
| Uczyń bieżący układ punktem wyjścia | Cmd+Ctrl+S |

## Wskazówki

- Kliknij plakietkę prawym przyciskiem, aby zmienić jej nazwę, nadać kolor lub ją usunąć — albo kliknij **✕** przy jej prawej krawędzi, co usuwa obszar roboczy po zapytaniu. Kolor jest tym, po czym rozpoznajesz obszary robocze na pierwszy rzut oka, gdy okno jest wąskie i nazwy już się nie mieszczą.
- Dziewięć to granica, aby każda plakietka pozostała rozpoznawalna.
- **Widok ▸ Pokaż pasek obszarów roboczych** ukrywa pasek bez wyłączania funkcji — dla tych, którzy przełączają się między obszarami z klawiatury.
- Obszary robocze można całkowicie wyłączyć w **Ustawienia ▸ Karty**. Twoje obszary robocze zostają zachowane i wracają niezmienione, gdy ponownie włączysz funkcję.

## Ograniczenie obszaru roboczego do folderu

Obszarowi roboczemu można powiedzieć, czego dotyczy, a wtedy sprawdza, zanim operacja sięgnie poza
niego. Kliknij plakietkę prawym przyciskiem, **Ogranicz do folderu ▸ Ustaw na aktywny folder**, i wybierz,
czy operacje poza mają być dozwolone, potwierdzane, czy odrzucane.

Sprawdzane jest, zanim usunięcie weźmie pliki z zewnątrz, zanim kopiowanie lub przeniesienie wyląduje
poza, i zanim zmiana nazwy albo nowy folder zapisze poza. **Nawigacja nigdy nie jest ograniczana** —
menedżer plików, który odmawia pokazania folderu, jest zepsuty, a cała wartość tkwi w chwili przed F8.
Zapisy w edytorze także nie są objęte; dzieją się we własnym oknie.

## Dziennik

Każdy obszar roboczy prowadzi zapis tego, co w nim zrobiono — odwiedzone foldery, wykonane operacje,
wpisane wiersze powłoki i wszystko, czego odmówiło ograniczenie do folderu. **Obszar roboczy ▸
Dziennik…** pokazuje go, od najnowszego dnia, z filtrem **Problemy** dla wszystkiego, co się nie udało
albo zostało zatrzymane.

Return powtarza zaznaczony wiersz według tej samej zasady co historia: jednym naciśnięciem można
powtórzyć tylko kopiowanie lub przeniesienie, a wiersz powłoki trafia do wiersza poleceń zamiast zostać
uruchomiony. Dziennik jest celowo oddzielony od globalnej historii — ta odpowiada na „gdzie zwykle
bywam” i porządkuje według częstości; ten odpowiada na „co się tu wydarzyło” i zachowuje kolejność.
Usuwa się razem ze swoim obszarem roboczym, poza tym jest przechowywany bez ograniczeń i można go
wyłączyć w **Ustawienia ▸ Karty**.

## Przekazywanie obszaru roboczego

**Obszar roboczy ▸ Eksportuj obszar roboczy…** zapisuje bieżący obszar roboczy do pliku
`.pcworkspace`, który można komuś wysłać albo trzymać w folderze projektu. **Importuj obszar
roboczy…** wczytuje go z powrotem, a dwuklik w Finderze tak samo.

Podróżuje **zapisany stan początkowy** obszaru roboczego — naciśnij najpierw ⌘⌃S, jeśli ma to być
układ, który masz przed sobą — wraz z nazwą, kolorem, ograniczeniem folderu i schowkiem. Foldery
wewnątrz twojego katalogu domowego zapisywane są w skrócie, żeby plik otworzył się w katalogu domowym
*drugiej* osoby, a nie w folderze nazwanym twoim imieniem.

Czego świadomie nie ma w pliku:

- **Wszystkiego, co mogłoby być poświadczeniem.** Karty wskazujące na połączenie lub zamontowany dysk wtyczki są przy eksporcie usuwane, a raport podaje ile. Nie ma czego stracić, bo o połączeniu nie zapisuje się nic.
- **Dziennika.** Zapisuje, co robiłeś *ty*, i wymienia foldery na twoim komputerze. Zostaje tutaj.
- Pozycji kursora, historii cofania, rozmiaru okna oraz otwartych okien podglądu, edytora, wyszukiwania i synchronizacji.
- Kart terminala i rozmów z asystentem. Należą do tego Maca; plik obszaru roboczego niesie *gdzie* się pracuje, a nie co jest uruchomione.

Import zawsze **dodaje** obszar roboczy; nigdy nie zastępuje tego, w którym jesteś, i nigdy sam nie
przełącza — plik, który ktoś przysłał, nie powinien przestawiać twojego okna. Foldery, których nie ma
na tym Macu, otwierają się na najbliższym istniejącym, wpisy schowka zachowują swoje ścieżki i są
wyszarzone, a ograniczenie folderu, którego folder nie istnieje, zostaje zachowane, ale pyta zamiast
odmawiać. Raport wymienia wszystko.

## Uwagi

- Przełączenie nigdy nie pyta o zapis i nigdy niczego nie zamyka. Trwające operacje na plikach są kontynuowane, podobnie jak wszystko w terminalu: karty obszaru, który opuszczasz, zostają odłożone z żywymi powłokami, a nie zamknięte. Rozmowy asystenta również podążają za obszarem roboczym.
- Cofanie podąża za obszarem roboczym tylko dopóki aplikacja działa: krok cofnięcia niesie ze sobą działanie, które je odwraca, a tego nie da się zapisać na dysku.
- Obszar roboczy zapamiętuje położenia folderów, a nie pliki w nich. Jeśli zapisany folder został przeniesiony lub usunięty, ta karta otworzy się w najbliższym folderze, który wciąż istnieje.
- Przy przejściu ze starszej wersji: obszary robocze zapisane wcześniej stają się plakietkami, a sesja, w której byłeś, staje się pierwszym. Nic nie ginie, a stary plik `workspaces.ini` zostaje zachowany jako `workspaces.ini.migrated`.
