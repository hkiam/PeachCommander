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

Kliknij wiersz prawym przyciskiem myszy, aby zajrzeć do plików, które za nim stoją. **Porównaj** otwiera obie strony obok siebie, a **Pokaż plik z lewej** i **Pokaż plik z prawej** otwierają jedną stronę osobno w przeglądarce — to odpowiedź dla wiersza, który istnieje tylko po jednej stronie i w którym nie ma czego porównywać. Pozycje, których nie da się zastosować do klikniętego wiersza, są wyszarzone, zamiast nic nie robić. Plik w archiwum `.zip` lub na serwerze jest najpierw rozpakowywany albo pobierany do tylko do odczytu kopii tymczasowej, więc oryginał nigdy nie jest ruszany. To samo dotyczy **Porównaj**, więc folder można porównać z archiwum albo serwerem — a przyciski scalania i zapisu pozostają wyłączone dla takiej strony, bo otwarta jest tam kopia.

## Porównaj dwa pliki według zawartości

1. Zaznacz jeden plik w każdym panelu (lub dwa pliki w tym samym panelu).
2. Wybierz **Plik ▸ Porównaj według zawartości…**.
3. Oba pliki otwierają się obok siebie z podświetlonymi różnicami. Użyj elementów sterujących następny/poprzedni, aby przeskakiwać między zmienionymi blokami.
4. Jeśli włączysz tryb edycji, możesz dostosować dowolny plik bezpośrednio i zapisać zmiany.

![Okno porównania pokazujące dwa pliki tekstowe obok siebie z podświetlonymi różniącymi się wierszami](screenshots/diff-window.png)
*(Rysunek: porównywanie dwóch plików tekstowych; zmienione wiersze są podświetlone po obu stronach.)*

Gdy między plikami nie ma żadnych różnic, okno mówi o tym kolorowym paskiem u góry, zamiast pozostawiać wniosek tabeli, w której nic nie jest wyróżnione. Pasek pojawia się także, w kolorze ostrzeżenia, gdy jakiegoś pliku nie udało się w ogóle odczytać — wtedy każdy wniosek o różnicach byłby twierdzeniem o porównaniu, które nigdy się nie odbyło. Porównanie bajt po bajcie mówi to samo z tego samego powodu: dwa pliki, których nie da się otworzyć, to nie dwa identyczne pliki.

## Porównaj pliki bajt po bajcie

Gdy dwa pliki wyglądają tak samo, ale musisz udowodnić, że są naprawdę identyczne (lub znaleźć ten jeden różniący się bajt), użyj porównania binarnego. Pokazuje oba pliki w widoku szesnastkowym z zaznaczonymi niepasującymi bajtami, co jest idealne do weryfikacji pobranych plików, sprawdzania zakodowanych danych lub potwierdzania dokładnej kopii.

## Porównaj listy katalogów

Aby dostrzec różnice między dwoma otwartymi folderami na pierwszy rzut oka, wybierz **Zaznacz ▸ Porównaj katalogi** (Shift+F2). Peach Commander oznaczy pliki, które się różnią lub brakuje ich po drugiej stronie, dzięki czemu możesz na nich działać zwykłymi poleceniami kopiowania, przenoszenia i usuwania.

## Ograniczanie tego, co obejmuje synchronizacja

Pole maski zawiera jedną listę włączeń dotyczącą nazw plików. Dla tego, czego nie da się tak wyrazić, **Filtr…** obok otwiera arkusz z trzema kartami. To, co się tam ustawi, dotyczy *następnego* porównania, a przycisk mówi wtedy, ile kryteriów jest aktywnych — filtr, którego nie widać, to sposób, w jaki kopia zapasowa kończy się niepełna, podczas gdy okno melduje, że skończyło.

- **Pomiń** przyjmuje wzorce rozdzielone `;` lub `|`. Nazwa bez ukośnika pasuje na każdej głębokości (`*.tmp`), ukośnik na końcu oznacza folder wraz z zawartością (`node_modules/`), a wzorzec z ukośnikiem pasuje do ścieżki względnej (`src/*/generated`). Wielkość liter nie ma znaczenia.
- **Rozmiar** i **data** oceniają parę jako całość: jeśli jedna strona wypada spoza zakresu, pomijana jest cała para. To zamierzone. Zastosowane tylko do jednej strony, pominięcie sprawiłoby, że para wyglądałaby jednostronnie i zamieniłoby się w kopiowanie w złym kierunku.
- **W ciągu ostatnich N dni** liczy się od każdego porównania, a nie od zapisania ustawienia — zapisane zadanie nadal znaczy więc „ostatni miesiąc”.
- Karta **Wtyczki** pyta wtyczkę treści o stronę, z której plik zostałby skopiowany. Potrzebuje prawdziwego pliku, więc jest dostępna tylko wtedy, gdy obie strony są folderami na tym Macu.

Pominięty folder nie jest usuwany także w trybie lustra — lustro usuwa tylko to, co rzeczywiście porównało. Wiersz stanu mówi, ile pozycji wstrzymał filtr, obok tego, co zrobi przebieg. Filtr jest zapisywany i wczytywany razem z ustawieniem synchronizacji, do którego należy.

## Utrzymywać dwa foldery jednakowe, w obie strony

Dwa pierwotne tryby nie potrafią odróżnić jednej rzeczy: plik, który jest tylko po jednej stronie,
jest albo **tu nowy**, albo **tam usunięty**, a wygląda to tak samo. Tryb symetryczny go więc kopiuje
— usuń coś na laptopie, zsynchronizuj, i wraca z kopii zapasowej — a tryb lustra usuwa, ale tylko w
jedną stronę.

**W obie strony (z pamięcią)** pamięta, jak oba foldery wyglądały, gdy ostatnio się zgadzały. Z tym
zapisem usunięcie po jednej stronie może zostać przeniesione na drugą.

- **Pierwszy** przebieg pary nie ma zapisu: zachowuje się jak dawniej i nic nie usuwa. Zapisuje dane.
  Od drugiego przebiegu tryb działa.
- Przeniesione usunięcie pokazuje się we własnym kolorze z `⇒🗑` i **nie** jest zaznaczone: to jedyny
  wiersz pochodzący z pamięci programu. Klik na strzałkę proponuje pozostałe odpowiedzi: skopiować
  plik z powrotem albo zostawić obie strony.
- Zmienione po jednej stronie i usunięte po drugiej to **konflikt**, nigdy usunięcie. Tak samo plik
  zmieniony po obu stronach.
- Nic nie jest usuwane na podstawie nieobecności, której porównanie nie mogło potwierdzić —
  nieczytelny folder albo taki, który zatrzymał filtr, niczego nie dowodzi o swojej zawartości.
- Tylko dwa foldery na tym Macu. Nie serwer i nie archiwum: usunięcie w archiwum zapisuje je od
  nowa, usunięcie na serwerze jest trwałe, a ten tryb nie jest tym, na którym warto to sprawdzać.

**Usunięcia nie da się cofnąć.** Na tym Macu plik idzie do Kosza i można go przywrócić w Finderze; to
cała siatka. **Pamięć…** w oknie wypisuje każdą parę, którą program pamięta, wyróżnia tę otwartą i pozwala zapomnieć dowolną — po czym następne porównanie tych folderów zachowuje się znów jak pierwsze. Nic nie jest zapominane samo: folder na odłączonym dysku nie zniknął, tylko nie jest podłączony.

Zapis leży przy ustawieniach: przeniesienie jednego z folderów pozbawia parę historii — a
przebieg bez historii nic nie usuwa.

## Co zrobił przebieg i co z tego da się cofnąć

Każda synchronizacja jest zapisywana. **Przebiegi…** w oknie wypisują je od najnowszych — kiedy, które dwa foldery, który tryb i ile plików zostało skopiowanych, usuniętych lub zatrzymanych — a dla wybranego przebiegu pokazują, co stało się z każdym plikiem.

To właśnie ta lista czyni Kosz użytecznym. Plik, który ten Mac usunął, trafił do Kosza, a przebieg zapisał *gdzie*, co znaczy więcej, niż brzmi: Kosz przy kolizji zmienia nazwę, więc druga `notes.txt` ląduje jako `notes.txt 11-17-15-028.txt`, a szukanie po nazwie trafia na niewłaściwą. **Pokaż w Koszu** kieruje Findera prosto na element.

**Przywróć…** przenosi pliki usunięte przez przebieg z Kosza na ścieżki, z których zostały usunięte. Każdy jest najpierw sprawdzany, a to, co się nie zgadza, zostaje odrzucone wraz z powodem, zamiast być wymuszone:

- Na tej ścieżce znowu coś jest. Zostaje nietknięte — przywrócenie nigdy nie może nadpisywać.
- Elementu nie ma już w Koszu albo został usunięty trwale, zamiast tam trafić.
- Strona była archiwum lub serwerem. Archiwum zapisuje się od nowa w całości, a serwer nie ma Kosza,
  więc nic nie zostało zachowane.
- Folder, do którego przebieg zapisywał, zniknął albo nie jest już tym samym folderem — na przykład
  ponownie użyty punkt montowania. Wtedy odrzucany jest cały przebieg, zamiast wykonać jego część.
- Zostało już przywrócone. Zapis to pamięta, więc druga próba nic nie robi.
- Albo sam zapis jest taki, na którym ta wersja nie potrafi działać — napisany przez nowszą wersję
  programu lub wskazujący ścieżkę poza oboma folderami. Rzadkie, i odrzucane zamiast zgadywane.

**Kopii nie da się cofnąć.** Usunięcie jej oznaczałoby skasowanie pliku, który mogłeś od tego czasu edytować, a to odwrotna wymiana niż przywrócenie usunięcia, więc program tego nie oferuje — przebieg mówi, które pliki skopiował, a usunąć możesz je sam. Plik, który został *nadpisany*, to jedyna prawdziwa luka, i jest już niewielka: na tym Macu zastąpiona wersja trafia do Kosza jak plik usunięty, więc **Pokaż w Koszu** ją znajdzie. Do archiwum, na serwer ani na wolumin bez Kosza tak się nie da, i potwierdzenie mówi o tym przed przebiegiem.

Przechowywanych jest ostatnich 200 przebiegów albo 64 MB z nich, zależnie od tego, co nastąpi pierwsze; powyżej tego najstarsze odpadają po kolei, w miarę jak przybywają nowe, a **Zapomnij** i **Zapomnij wszystkie** sprzątają je od razu. Bardzo duży przebieg — ponad 20 000 plików — zachowuje każdy problem i wszystko, co włożył do Kosza, ale nie kopie, które przeszły, i mówi o tym, zamiast zostawiać to twojej uwadze. Jego usunięcia wciąż da się przywrócić: pominięte zostały kopie, a kopii i tak nie dałoby się cofnąć.

Zapomnienie niczego nie zmienia w folderach; znika zapis tego, co zrobiono, a wraz z nim oferta przywrócenia czegokolwiek. W odróżnieniu od pamięci dwukierunkowej to jest wyrzucane automatycznie — utrata pamięci *pary* zmieniłaby to, co zrobi następny przebieg, podczas gdy utrata zapisu przebiegu odbiera tylko ofertę.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Porównaj listy katalogów (oznacz różniące się pliki) | Shift+F2 |
| Porównaj według zawartości | Plik ▸ Porównaj według zawartości… |
| Synchronizuj katalogi | Polecenia ▸ Synchronizuj katalogi… |
| Pokaż jedną stronę wiersza synchronizacji | Prawy przycisk na wierszu ▸ Pokaż plik z lewej / z prawej |

## Uwagi

- **Według zawartości a według daty/rozmiaru.** Szybkie porównanie dopasowuje pliki według rozmiaru i daty modyfikacji, co jest szybkie, ale można je oszukać, gdy znaczniki czasu różnią się dla identycznych plików. Włącz **według zawartości** dla wiarygodnego wyniku kosztem odczytu każdego pliku.
- **Podfoldery i filtry.** Okno synchronizacji może schodzić do podfolderów i można je ograniczyć maską filtra, więc możesz synchronizować tylko interesujące Cię typy plików.
- **Zachowujesz kontrolę.** Synchronizacja nigdy nie działa sama — przeglądasz proponowane kierunki w siatce wyników i możesz zmienić dowolny z nich, zanim cokolwiek zostanie skopiowane. **Esc** przerywa trwające porównanie i zamyka okno, gdy nic nie działa.
- **Ustawienia wstępne.** Często używane konfiguracje synchronizacji można zapisać i użyć ponownie, dzięki czemu nie musisz za każdym razem wpisywać tych samych opcji. Ustawienie wstępne zapamiętuje także to, co pokazuje siatka wyników — filtr kierunku i **Ukryj identyczne** — a okno otwiera się na ostatnio używanym ustawieniu. Ustawienie **Domyślnie** jest dostępne od pierwszego otwarcia okna; zapisz na nim własne, aby je dostosować.
