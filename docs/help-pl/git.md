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
naciśnij **Zatwierdź** — z **Popraw** zmiana zostanie wtopiona w poprzednie zatwierdzenie. **Pobierz** i
**Wyślij** są obok, tam gdzie zatwierdzanie i tak się odbywa; oba pokazują postęp i można je przerwać.

Zatwierdzany jest *indeks*, nie `git commit -a`: zatwierdzane jest to, co przygotowano.

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

- Wtyczka używa systemowego Gita w `/usr/bin/git`. Jeśli Gita nie ma, polecenia zgłaszają, że Git jest
  niedostępny. (Dostarczają go Xcode Command Line Tools.)
- Stan repozytorium jest czytany raz na folder i zapamiętywany, więc przewijanie dużego repozytorium pozostaje
  szybkie; pamięć odświeża się po każdym poleceniu zmieniającym drzewo i nadąża też za zatwierdzeniem zrobionym
  poza programem.
- Dowiązane drzewa robocze i podmoduły są obsługiwane: plik w podmodule pokazuje stan i gałąź *podmodułu*, a
  nie repozytorium nadrzędnego.
- Każda lista ma menu kontekstowe, **Return** wykonuje jej główne działanie, a **Cmd+R** przeładowuje okno.
