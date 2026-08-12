---
title: Wbudowany terminal
slug: terminal
section: Plugins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander potrafi uruchomić prawdziwą powłokę we własnym oknie, w pasie u dołu zwanym dokiem. To twoja powłoka logowania — ta, którą wskazuje `$SHELL`, albo `/bin/zsh`, jeśli tamta się nie nadaje — więc twoja `PATH`, twoje aliasy i twoje funkcje są na miejscu, dokładnie jak w Terminalu.

To nie to samo co **Otwórz Terminal tutaj**, które uruchamia Terminal firmy Apple w bieżącym folderze i zostawia cię z dwoma oknami. Wbudowany zostaje tam, gdzie są twoje pliki, i wie o nich.

To wtyczka: jeśli jej nie chcesz, wyłącz ją lub usuń w **Konfiguracja ▸ Wtyczki…**, a dok zniknie razem z nią.

## Otwieranie i przechodzenie

Naciśnij **Ctrl** razem z klawiszem na lewo od „1”, aby przenieść klawiaturę między panelem plików a terminalem. Ten skrót jest przypisany do *pozycji* klawisza, nie do jego znaku, więc jest to ten sam fizyczny klawisz, jakkolwiek nazywa go twój układ: akcent słaby na klawiaturze US, `^` na niemieckiej, `@` na francuskiej.

Cała reszta jest w menu **Terminal**:

| Czynność | Co robi |
| --- | --- |
| Pokaż terminal | Zwija go i rozwija ponownie; karty i to, co w nich działa, zostają bez zmian |
| Przełącz między panelem a terminalem | Przenosi fokus klawiatury, nie zmieniając niczego więcej |
| Nowa karta terminala | Kolejna powłoka, w tym samym folderze |
| Zamknij kartę terminala | Zamyka ją — i pyta wcześniej, jeśli coś jeszcze w niej działa |
| Podziel terminal | Dwie powłoki obok siebie w tej samej karcie |
| Przejdź do folderu panelu | Wykonuje w terminalu `cd` tam, gdzie stoi aktywny panel |
| Wstaw zaznaczone nazwy plików | Wpisuje zaznaczone nazwy w wierszu zachęty, w cudzysłowach |
| Uruchamiaj wiersz poleceń w terminalu | Wysyła to, co wpisałeś w wierszu poleceń, do powłoki zamiast wykonywać to niewidocznie |

Dopóki terminal ma fokus, **klawisze funkcyjne trafiają do niego**, nie do panelu plików — F5 w edytorze tekstu wewnątrz terminala musi dotrzeć do edytora. Pasek klawiszy funkcyjnych to mówi, zamiast pokazywać klawisze, które niczego nie uruchomią.

## Most z powrotem do panelu

**Kliknij ścieżkę z Cmd** w wyjściu terminala, a panel tam przejdzie. Plik z `ls`, ścieżka w błędzie kompilatora, nazwa z `git status` — jedno kliknięcie i już na nią patrzysz.

Zadziała tylko wtedy, gdy słowo pod wskaźnikiem naprawdę odpowiada czemuś, co istnieje. Cmd-kliknięcie w zwykły tekst nie robi nic, zamiast nawigować gdzieś przypadkowo, a zwykłe kliknięcie nadal zaznacza tekst jak dotąd.

**Upuść pliki na terminal**, a ich ścieżki wylądują w wierszu zachęty, w cudzysłowach, gotowe do polecenia, które masz w połowie napisane.

## Niech panel podąża za powłoką

Domyślnie wyłączone: gdy wykonasz `cd` gdzieś w terminalu, panel zostaje na miejscu. Włącz **Niech aktywny panel podąża za terminalem** na stronie ustawień terminala, a będzie podążał.

Potrzebna jest do tego pomoc twojej powłoki, bo powłoka nie ogłasza, dokąd poszła. Strona ustawień pokazuje krótki fragment do `~/.zshrc` i przycisk do skopiowania go; sprawia on, że zsh zgłasza swój katalog roboczy (sekwencja sterująca OSC 7) przed każdym wierszem zachęty. Bez fragmentu ustawienie jest włączone i nic nie podąża — dlatego fragment stoi tuż obok.

## Wyszukiwanie i historia

**Cmd+F** przeszukuje to, co terminal wypisał.

Terminal domyślnie trzyma **5000 wierszy** historii — dość, by przewinąć się przez kompilację. Zmienia się to na stronie ustawień. Bardzo duże wartości są ograniczane, bo historia pięćdziesięciu milionów wierszy to problem z pamięcią, którego przyczyny nie da się zobaczyć z zewnątrz.

## Gdzie się mieści

Terminal otwiera się w doku u dołu, bo takiego kształtu potrzebuje: powłoka potrzebuje szerokości, a panel boczny przy domyślnych 300 punktach mieści około 44 kolumn, podczas gdy dół okna o szerokości 1200 punktów mieści ich 176.

Mimo to możesz go przenieść. Przeciągnij go do panelu bocznego, jeśli tak ci wygodniej, albo użyj ustawień rozmieszczenia opisanych w [Wtyczki](plugins.md); przeniesienie **przepina tę samą powłokę** zamiast uruchamiać nową, więc cokolwiek działa, działa dalej. Polecenia z menu **Terminal** idą za nim: przywołują go tam, gdzie jest, zamiast otwierać dok.

Karty wracają po ponownym uruchomieniu aplikacji, w folderach, w których były. To, co w nich *działało*, nie — restart kończy te procesy, jak w każdym terminalu. Wraca też to, czy był otwarty przy zamykaniu programu.

## Przy zamykaniu

Zamknięcie aplikacji zamyka powłoki. To, co jeszcze w nich działa, zostaje zakończone, tak jak zamknięcie okna Terminala kończy to, co jest w środku. Dlatego zamknięcie karty, w której coś działa, najpierw pyta.
