---
title: Historia globalna
slug: history
section: Organizacja widoku
order: 47
related: [favorites, navigating]
---

Historia globalna to jedno okno, które pamięta twoją własną pracę: odwiedzone foldery, otwarte pliki, wykonane operacje i uruchomione polecenia. Naciśnij Ctrl+Cmd+H z dowolnego miejsca, zacznij pisać i w sekundę wracasz do wczorajszego folderu — bez myszy.

## Otwieranie historii

1. Naciśnij Ctrl+Cmd+H lub wybierz **Przejdź > Historia…**. Nie ma znaczenia, który panel jest aktywny.
2. Wpisz kilka liter. Dopasowanie nie musi być dokładne ani ciągłe: `proj rep` znajduje `~/Projects/annual-report.txt`.
3. Przechodź po wynikach strzałkami w górę i w dół, pisząc dalej.
4. Enter działa na podświetlonym wpisie, Esc zamyka okno.

Wpisy są uszeregowane według tego, jak niedawno *i* jak często ich używałeś, więc miejsca, w których pracujesz najwięcej, są już na górze. Przypięte wpisy zawsze prowadzą.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Ilustracja: Historia globalna — pole wyszukiwania ma fokus, a lista jest uszeregowana według tego, jak niedawno i jak często używałeś każdego wpisu.)*

## Filtrowanie według rodzaju

Przyciski pod polem wyszukiwania ograniczają listę do wszystkich wpisów, folderów, plików, operacji lub ulubionych. Option+1 do Option+5 przełączają je z klawiatury.

## Działanie na wpisie

| Działanie | Skrót |
| --- | --- |
| Otwórz podświetlony wpis | Return |
| Pokaż w panelu, z kursorem na nim | Option+Return |
| Otwórz jeden z dziewięciu najtrafniejszych wpisów | Cmd+1 … Cmd+9 |
| Przełącz panel, w którym się otwiera | Tab |
| Przypnij lub odepnij wpis | Cmd+P |
| Usuń wpis z historii | Cmd+Delete |
| Skopiuj ścieżkę wpisu | Option+Cmd+C |
| Pokaż wpis w Finderze | Cmd+Shift+R |
| Zamknij historię | Esc |

Enter robi to, co pasuje do wpisu: folder otwiera się w panelu docelowym, plik otwiera się tak jak z panelu, a wiersz poleceń trafia do linii poleceń, żebyś mógł go przejrzeć i uruchomić. Panel docelowy jest podany na dole okna, a Tab go przełącza.

## Powtórzenie operacji

Kopiowanie lub przenoszenie pojawia się pod **Operacje**, a Enter uruchamia je ponownie — te same elementy do tego samego folderu, przez zwykłą kolejkę przesyłania i jej pytania o nadpisanie. Elementy, których już nie ma, są pomijane, a jeśli nie zostanie żaden, dowiesz się o tym.

Usunięcia i zmiany nazw są na liście, ale nigdy nie są powtarzane: Enter pokazuje zamiast tego, gdzie się zdarzyły. Powtórzenie usunięcia nie powinno być jedno naciśnięcie od listy, którą tylko przeglądasz.

## Trzymanie tego w ryzach

Ustawienia ▸ Inne decydują, czy historia jest prowadzona, ile wpisów przechowuje i po ilu dniach je zapomina. Przypięte wpisy są z tego wyłączone, a 0 dni zachowuje wszystko; lista leży w `history.ini` w twoim folderze konfiguracyjnym i przetrwa ponowne uruchomienie.

## Uwagi

- Otwarcie czegoś z historii liczy się jako użycie — dlatego to, do czego wracasz, stale się wybija.
- Foldery wewnątrz archiwum, na serwerze lub w dysku wtyczki nie są pamiętane: taka ścieżka nic nie znaczy bez montowania, które ją utworzyło, a własna historia panelu trzyma je, dopóki jest otwarte.
- To nie jest własna historia folderów panelu na Alt+Dół, która wymienia tylko to, gdzie był ten jeden panel, w kolejności.
