---
title: Kopiowanie plików
slug: copying-files
section: Pliki i foldery
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander jest zbudowany wokół dwóch paneli obok siebie: jeden zawiera pliki, nad którymi pracujesz, drugi jest miejscem docelowym. Kopiowanie bierze to, co jest zaznaczone w aktywnym panelu, i umieszcza duplikat w folderze pokazanym w drugim panelu, pozostawiając oryginały na miejscu. To najszybszy sposób na powielanie plików i folderów między dwiema lokalizacjami bez przeciągania.

## Kopiowanie zaznaczenia do drugiego panelu

1. W jednym panelu otwórz folder zawierający elementy, które chcesz skopiować.
2. W drugim panelu otwórz folder, do którego mają trafić kopie.
3. Zaznacz pliki i foldery do skopiowania. Jeśli nic nie jest zaznaczone, użyty zostaje element pod kursorem.
4. Naciśnij F5. Otworzy się okno dialogowe kopiowania z już wypełnioną ścieżką docelową.

![Okno dialogowe kopiowania ze ścieżką docelową i opcjami](screenshots/copy-dialog.png)
*(Rysunek: Okno dialogowe kopiowania. Ścieżka docelowa wskazuje drugi panel; użyj opcji, aby dostroić kopiowanie.)*

5. W razie potrzeby dostosuj miejsce docelowe, a następnie potwierdź, aby rozpocząć kopiowanie.

## Opcje kopiowania

Przed potwierdzeniem możesz zmienić sposób działania kopiowania:

- **Tylko nowsze pliki** — pomija każdy element, którego kopia już istnieje i jest w tym samym wieku lub nowsza, więc aktualizowane są tylko zmienione pliki.
- **Uruchom w tle** — przekazuje kopiowanie do menedżera transferów w tle zamiast wyświetlać okno postępu.
- **Dodaj do kolejki na później** — dodaje kopiowanie do kolejki w tle, jeszcze go nie uruchamiając.
- **Maska zmiany nazwy** — wpisz wzorzec wieloznaczny w polu docelowym (na przykład `*.bak`), aby zmieniać nazwy elementów podczas kopiowania.

Dwa ustawienia dotyczą każdego kopiowania i znajdują się w **Konfiguracja ▸ Kopiuj/Usuń**: zachowywanie dat, uprawnień i innych atrybutów (domyślnie włączone) oraz ograniczenie prędkości, dzięki któremu duże kopiowanie nie wysyci dysku ani połączenia sieciowego. Zadania w kolejce — zobacz Transfery w tle.

## Postęp

Okno postępu pokazuje dwa paski — kopiowany plik i całe zadanie — wraz z liczbą plików i bajtów, prędkością transferu i pozostałym czasem. Możesz wstrzymywać i wznawiać w dowolnej chwili. Menu prędkości obok przycisków od razu ogranicza to kopiowanie (1, 5 lub 20 MB/s albo pełna prędkość) bez zmiany limitu w Konfiguracji; **Domyślnie** przywraca ten limit. Aby pracować dalej podczas kopiowania, uruchom je za pomocą **Uruchom w tle**.

![Okno dialogowe postępu transferu z paskiem postępu, licznikami plików i bajtów oraz przyciskami Wstrzymaj i Anuluj](screenshots/progress-dialog.png)
*(Rysunek: Okno dialogowe postępu wyświetlane podczas kopiowania lub przenoszenia.)*

## Obsługa plików, które już istnieją

Jeśli kopiowanie miałoby zastąpić istniejący plik, Peach Commander zatrzymuje się i pyta, co zrobić. Podgląd obu plików pomaga podjąć decyzję.

![Okno dialogowe konfliktu nadpisania porównujące dwa pliki](screenshots/overwrite-dialog.png)
*(Rysunek: Okno dialogowe nadpisania porównuje istniejący plik z tym, który jest kopiowany.)*

Twoje możliwości obejmują:

- **Nadpisz** istniejący plik lub **Nadpisz wszystkie**, aby zastosować to do każdego pozostałego konfliktu.
- **Pomiń** ten plik lub **Pomiń wszystkie** pozostałe konflikty.
- **Zmień nazwę** przychodzącej kopii automatycznie, aby zachować oba pliki.
- **Dołącz** przychodzące dane na końcu istniejącego pliku.
- Nadpisz tylko wtedy, gdy źródło jest **nowsze** lub **większe** niż istniejący plik.

## Skróty

| Akcja | Klawisz |
|---|---|
| Kopiuj zaznaczenie do drugiego panelu | F5 |
| Kopiuj w tym samym folderze (utwórz duplikat ze zmienioną nazwą) | Shift+F5 |
| Otwórz menedżera transferów w tle | Cmd+Shift+B |

## Uwagi

- Kopiowanie między dwiema lokalizacjami na tym samym dysku używa szybkiego klonowania, gdy dysk to obsługuje, więc duże pliki kopiują się niemal natychmiast i zajmują niewiele dodatkowego miejsca.
- Foldery są kopiowane wraz z całą swoją zawartością.
- Aby przenosić pliki zamiast je kopiować, użyj F6. Aby obserwować zadania w kolejce lub nimi zarządzać, otwórz menedżera transferów w tle za pomocą Cmd+Shift+B.
