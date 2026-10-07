---
title: Git
slug: git
section: Wtyczki
order: 123
related: [plugins, view-modes-and-sorting]
---

Wtyczka Git pokazuje stan repozytorium Git wprost w panelu plików — bez osobnej aplikacji i bez terminala.
Dodaje dwie kolumny, podmenu **Git**, zadokowany panel do przygotowywania i zatwierdzania zmian oraz okna
historii, blame, gałęzi, konfliktów i zmiany bazy. Korzysta z `git`, który jest już zainstalowany na Macu. To
wtyczka, więc można ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Co dodaje

- **Dwie kolumny listy plików** — *Stan Git* i *Gałąź*. Każdy plik pokazuje ikonę i krótkie słowo stanu
  (Zmieniony, Dodany, Usunięty, Nieśledzony, Przemianowany, Skopiowany, Konflikt, Ignorowany, Zmieniony typ),
  z *(przygotowany)*, gdy zmiana jest już w indeksie; kolumna *Gałąź* pokazuje gałąź, na której stoi
  repozytorium tego pliku. Kolumny włącza się w **Konfiguracja ▸ Kolumny…** (zob.
  [Tryby widoku i sortowanie](view-modes-and-sorting.md)).
- **Menu Git** — w **Polecenia ▸ Git** oraz w menu kontekstowym pliku.

![Okno Stan Git z bieżącą gałęzią i zmienionymi plikami repozytorium](screenshots/git-status.png)
*(Rysunek: Stan Git podaje gałąź i każdą zmianę w drzewie roboczym.)*

## Panel: przygotuj, zatwierdź, zsynchronizuj

**Polecenia ▸ Git ▸ Panel** dokuje widok, który dzieli drzewo robocze na *przygotowane*, *zmienione* i
*nieśledzone*. Zaznacz pliki i użyj **Przygotuj**, **Cofnij przygotowanie** lub **Odrzuć…**, wpisz komunikat i
naciśnij **Zatwierdź** — z **Popraw** zmiana zostanie wtopiona w poprzednie zatwierdzenie. **Fetch**, **Pobierz** i
**Wyślij** są obok, tam gdzie zatwierdzanie i tak się odbywa; wszystkie trzy pokazują postęp i można je przerwać.

Zatwierdzany jest *indeks*, nie `git commit -a`: zatwierdzane jest to, co przygotowano.

## Historia w panelu

Pod przyciskami panel pokazuje historię wszystkich gałęzi, gałęzi zdalnych i tagów jako rysowany graf, z kopią roboczą w pierwszym wierszu. Obszar poniżej podąża za zaznaczeniem:

![Panel Git z grafem gałęzi, zaznaczonym commitem scalenia i jego zmienionym plikiem z wbudowanym diffem](screenshots/git-panel.png)

- **Zmiany lokalne** pokazuje pliki przygotowane, zmienione i nieśledzone oraz opisane wyżej pole commita.
- Commit pokazuje **Commit** — autora, committera, datę, hash, rodziców, refy, podpis i pełny opis — albo **Zmiany**.
- **Zmiany** wyświetla zmienione pliki jako drzewo i diff wybranego pliku z numerami wierszy; dwukrotne kliknięcie otwiera okno porównania.
- Menu kontekstowe kopiuje hash lub temat, cofa, robi cherry-pick, otwiera commit w sieci i ogranicza listę do **Tylko bieżąca gałąź**.
- Z tego samego menu commit można przełączyć, nadać mu nową gałąź lub tag, scalić z bieżącą gałęzią, przenieść na niego bieżącą gałąź lub ją do niego zresetować albo rozpocząć od niego interaktywny rebase.
- Pole wyszukiwania nad listą przeszukuje całą historię — opis, imię i e-mail autora albo hash i jego pierwsze znaki — i pokazuje wyniki bez grafu.

## Więcej w panelu i w menu Git

Kopia robocza, historia i menu **Polecenia ▸ Git** oferują więcej niż zatwierdzanie:

- Zaznaczony przygotowany lub zmieniony plik pokazuje pod listą swój diff; zaznaczone wiersze lub cały fragment można z jego menu kontekstowego przygotować, cofnąć z przygotowania lub odrzucić.
- Pole commitu przyjmuje kilka wierszy — temat, pusty wiersz, treść —, zatwierdza przez **Cmd+Return** i liczy znaki tematu; przycisk menu obok przechowuje twoje ostatnie wiadomości commitów.
- **Pokaż w lewym panelu** i **Pokaż w prawym panelu** przenoszą panel plików na plik z listy lub ze zmian commita, a panel Git zostaje bez zmian; pliki przechowywane przez Git LFS są oznaczone **LFS**.
- Schowki pojawiają się w historii jako małe kwadraty nad commitem, na którym je utworzono, z **Zastosuj schowek**, **Zastosuj i usuń schowek** i **Usuń schowek…** w menu kontekstowym.
- **Reflog…** wyświetla każde przesunięcie HEAD; commit utracony przez reset lub usuniętą gałąź wraca przez **Nowa gałąź tutaj…**.
- **Ustawienia repozytorium…** dodaje, zmienia nazwy, przekierowuje i usuwa zdalne repozytoria, dodaje, aktualizuje i usuwa podmoduły, zarządza worktree i nadaje tylko temu repozytorium nazwę i e-mail dla commitów.
- **Utwórz tu repozytorium…** i **Klonuj repozytorium…** działają w folderze aktywnego panelu, a zegar obok tytułu panelu prowadzi z powrotem do ostatniego repozytorium.

## Gdy git się zatrzymuje, i ustawienia

- **Push** przy pierwszym wypchnięciu gałęzi ustawia gałąź nadrzędną. Jeśli zdalne repozytorium ma commity, których tej gałęzi brakuje, proponuje **Pobierz, potem wypchnij** albo **Wymuś wypchnięcie** — zawsze z lease, który odmawia, jeśli ktoś wypchnął od twojego ostatniego fetch; **Wymuś wypchnięcie (z lease)…** jest też w menu kontekstowym przycisku **Push**.
- Gdy **Pull** stwierdzi, że gałąź i jej gałąź nadrzędna się rozeszły, pyta, czy scalić, czy zrobić rebase, zamiast zatrzymać się na komunikacie gita.
- Scalanie, cherry-pick, revert, rebase lub seria łatek zatrzymane na konflikcie pokazują nad historią pasek z **Kontynuuj** i **Przerwij…**; commit scalający jest cofany lub przenoszony względem pierwszego rodzica.
- Zaznacz dwa commity, aby je porównać, albo kilka, aby przenieść je naraz przez cherry-pick. **Porównaj z kopią roboczą** i **Zapisz jako łatkę…** są w menu historii, **Zastosuj łatki…** w menu Git.
- Pole wyszukiwania przyjmuje też filtry — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — same lub razem ze słowami.
- **Bisect: oznacz jako zły** i **Bisect: oznacz jako dobry** w menu historii zaczynają bisect; pasek oferuje potem **Dobry**, **Zły**, **Pomiń** i **Zakończ bisect**, aż git wskaże pierwszy zły commit.
- Odłożenie wybranych plików lub wszystkich zmian do stasha pyta o wiadomość i o to, czy dołączyć nieśledzone pliki lub zachować indeks. Pliki w Git LFS można zablokować i odblokować, a ich typ pliku śledzić.
- Na liście gałęzi gałąź można przemianować (**Zmień nazwę…**), nadać jej gałąź nadrzędną (**Ustaw gałąź nadrzędną…**) lub usunąć na jej serwerze (**Usuń w zdalnym…**).
- **Ustawienia ▸ Git** określają program git, twoją globalną nazwę i e-mail, sposób działania **Pull**, fetch w tle, co pokazuje historia i jak wyglądają jej daty, podpisywanie, sign-off i hooki commitów oraz białe znaki i wiersze kontekstu w diffach. Autorzy mają w historii kolorowe inicjały.

## Historia, blame i sieć

- **Historia…** wypisuje zatwierdzenia z grafem torów, referencje wskazujące na każde z nich (`● main`,
  `↗ origin/main`, `⚑ v1.0`) oraz pliki, których dotknęło każde zatwierdzenie. Return albo dwuklik otwiera
  wersję tego pliku wobec jej poprzedniczki w oknie porównania. **Cofnij zatwierdzenie** i **Cherry-pick** też
  tam są i oba odmawiają z góry, jeśli drzewo robocze nie jest czyste.
- **Historia pliku…** to to samo okno dla jednego pliku.
- **Blame (lista)…** pokazuje każdy wiersz z jego zatwierdzeniem, autorem i datą. **Blame w edytorze** wpisuje
  tę samą informację na marginesie edytora, obok numerów wierszy: wskaźnik na wierszu pokazuje komunikat
  zatwierdzenia, kliknięcie otwiera je wobec poprzedniczki.
- **Otwórz w sieci** otwiera plik, zatwierdzenie lub gałąź w GitHubie, GitLabie, Bitbuckecie albo Azure
  DevOps, budując adres z URL zdalnego repozytorium — bez konta i bez tokenu. Przy serwerze, którego układu
  odnośników nie zna, proponuje stronę repozytorium, zamiast zgadywać.

## Gałęzie, schowki i etykiety

**Gałęzie, schowki i etykiety…** wypisuje wszystkie trzy. Przełącz, utwórz, scal lub usuń gałąź; wyślij,
zdejmij lub porzuć schowek; utwórz, usuń albo wyślij etykietę lub przełącz się na nią — etykieta nie jest
gałęzią, więc z góry mówi, że HEAD zostanie odłączony. Pobranie, Pobierz i Wyślij są w tym samym oknie i można
je przerwać w trakcie.

Wysłanie etykiety jest celowo osobnym działaniem: `git push` nie zabiera etykiet.

## Konflikty

**Rozwiąż konflikt…** wypisuje obszary konfliktu w pliku pod kursorem i dla każdego podejmuje decyzję: *nasze*,
*ich*, *oba* albo zostaw otwarty. Potem **Zapisz plik** albo **Zapisz i przygotuj**. Odmawia przygotowania,
dopóki któryś obszar jest otwarty — Git bez oporu zatwierdzi znaczniki `<<<<<<<` — i nie tyka pliku, którego
znaczników nie potrafi odczytać, zamiast ich zgadywać. Gdy obszar wymaga ręcznego przeplecenia obu stron,
**Otwórz w edytorze** jest jeden przycisk dalej.

## Zmiana bazy

**Zmień bazę…** wypisuje zatwierdzenia wyprzedzające gałąź nadrzędną — te, których nikt inny jeszcze nie ma —
i pozwala je zgnieść, dołączyć jako poprawkę, porzucić, przestawić albo przeredagować, zanim gałąź zostanie
przepisana. Gdy zmiana bazy zatrzyma się na konflikcie, to samo okno staje się **Kontynuuj** / **Pomiń
zatwierdzenie** / **Przerwij**, żeby niedokończonej zmiany bazy nie trzeba było kończyć w terminalu.

## Ignorowanie plików i dane dostępu

- **Ignoruj ten plik…**, **Ignoruj ten typ pliku…** i **Ignoruj ten folder…** wpisują właściwy wzorzec do
  `.gitignore` — zakotwiczony tam, gdzie trzeba, żeby ignorowanie *tego* folderu `build` nie ignorowało
  każdego folderu o nazwie `build`.
- **Dane dostępu…** informują, jak to repozytorium się uwierzytelnia: SSH czy HTTPS, czy skonfigurowano pomoc
  poświadczeń, czy działa agent SSH trzymający klucz. Gdzie to pomaga, proponują dokładnie jedno działanie —
  pozwolić Gitowi trzymać dane dostępu w pęku kluczy macOS. Wtyczka nigdy nie pyta o hasło klucza, nie
  pokazuje go i nie zapisuje.

## Uwagi

- Wtyczka używa systemowego Gita w `/usr/bin/git` lub programu wybranego w **Ustawienia ▸ Git**. Jeśli Gita nie ma, polecenia zgłaszają, że Git jest niedostępny. (Dostarczają go Xcode Command Line Tools.)
- Stan repozytorium jest czytany raz na folder i zapamiętywany, więc przewijanie dużego repozytorium pozostaje
  szybkie; pamięć odświeża się po każdym poleceniu zmieniającym drzewo i nadąża też za zatwierdzeniem zrobionym
  poza programem.
- Dowiązane drzewa robocze i podmoduły są obsługiwane: plik w podmodule pokazuje stan i gałąź *podmodułu*, a
  nie repozytorium nadrzędnego.
- Każda lista ma menu kontekstowe, **Return** wykonuje jej główne działanie, a **Cmd+R** przeładowuje okno.
- Git LFS, `gpg` do podpisanych commitów i pomocnicy poświadczeń są znajdowani w folderach Homebrew i MacPorts, także gdy aplikację otwarto z Findera.
