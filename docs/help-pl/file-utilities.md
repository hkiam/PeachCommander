---
title: Narzędzia plikowe
slug: file-utilities
section: Zaawansowane narzędzia
order: 94
related: [comparing-and-syncing]
---

Poza kopiowaniem i przenoszeniem Peach Commander zawiera zestaw codziennych narzędzi plikowych do weryfikacji nienaruszoności plików, odzyskiwania miejsca na dysku, dzielenia dużych plików na mniejsze części oraz konwertowania plików do i z formatów bezpiecznych dla tekstu. Do wszystkich dotrzesz z menu **Plik** i działają one na tym, co zaznaczyłeś w aktywnym panelu (lub na elemencie pod kursorem, gdy nic nie jest zaznaczone). Ten temat obejmuje sumy kontrolne, wyszukiwarkę duplikatów, dzielenie/łączenie, kodowanie/dekodowanie i obliczanie zajmowanego miejsca.

## Utwórz lub zweryfikuj sumy kontrolne

Sumy kontrolne pozwalają potwierdzić, że plik pobrał się lub skopiował bez uszkodzenia, albo dać odbiorcy sposób na sprawdzenie otrzymanej kopii.

1. Zaznacz pliki, które chcesz opatrzyć odciskiem.
2. Wybierz **Plik ▸ Utwórz sumy kontrolne…**, wybierz algorytm (CRC32, MD5, SHA-1, SHA-256 lub SHA-512) i zapisz plik sumy kontrolnej.
3. Aby sprawdzić pliki później, zaznacz plik sumy kontrolnej i wybierz **Plik ▸ Zweryfikuj sumy kontrolne…**. Peach Commander ponownie oblicza każdy skrót i zgłasza każdy plik, który nie pasuje.

Sumy kontrolne są liczone bezpośrednio po bieżącej lokalizacji, więc możesz je tworzyć lub weryfikować nawet dla plików wewnątrz archiwów lub na serwerze FTP.

## Znajdź duplikaty plików

Wyszukiwarka duplikatów lokalizuje identyczne pliki rozproszone po folderach, dzięki czemu możesz usunąć nadmiarowe kopie.

1. Zaznacz foldery (lub pliki), które chcesz przeskanować.
2. Wybierz **Plik ▸ Znajdź duplikaty…**. Peach Commander porównuje kandydatów i grupuje pliki, które są identyczne bajt w bajt.
3. Przejrzyj każdą grupę, oznacz kopie, których już nie potrzebujesz, i usuń je.

![Wyszukiwarka duplikatów wymieniająca grupy identycznych plików](screenshots/duplicate-finder.png)
*(Rysunek: wyszukiwarka duplikatów grupuje identyczne pliki, dzięki czemu możesz zachować jeden i usunąć resztę.)*

## Podziel i połącz pliki

Dzielenie rozbija jeden duży plik na ponumerowaną serię mniejszych części — przydatne przy ograniczeniach przechowywania lub transferu. Łączenie ponownie je składa.

1. Aby podzielić, zaznacz plik i wybierz **Plik ▸ Podziel plik…**, a następnie ustaw rozmiar części. Części są zapisywane do folderu drugiego panelu.
2. Aby ponownie złożyć, zaznacz pierwszą część i wybierz **Plik ▸ Połącz pliki…**. Oryginalny plik jest odbudowywany z ponumerowanych części.

## Koduj i dekoduj

Kodowanie zamienia plik binarny na zwykły tekst, aby przetrwał kanały, które przenoszą tylko tekst (na przykład starszy e-mail lub pola wklejania). Dekodowanie to odwraca.

1. Zaznacz plik i wybierz **Plik ▸ Koduj…**, a następnie wybierz format — MIME (Base64), UUE (uuencode) lub XXE.
2. Aby przywrócić oryginał, zaznacz zakodowany plik i wybierz **Plik ▸ Dekoduj…**. Format jest wykrywany automatycznie.

## Oblicz zajmowane miejsce

Aby zobaczyć, ile miejsca folder lub zaznaczenie faktycznie zajmuje na dysku, zaznacz elementy i naciśnij **Ctrl+L** (**Plik ▸ Oblicz zajmowane miejsce…**). Peach Commander sumuje każdy plik wewnątrz, w tym podfoldery, i pokazuje sumę.

## Skróty

| Akcja | Klawisz |
| --- | --- |
| Oblicz zajmowane miejsce | Ctrl+L |

## Uwagi

- Sumy kontrolne, dzielenie/łączenie i kodowanie/dekodowanie są ukierunkowane na bardziej zaawansowane zadania, ale każde jest pojedynczym oknem dialogowym z rozsądnymi wartościami domyślnymi.
- Gdy narzędzie tworzy nowe pliki (części podziału, zakodowany plik, listę sum kontrolnych), są one zapisywane do folderu pokazanego w drugim panelu — najpierw ustaw ten panel na zamierzone miejsce docelowe.
- Usuwanie duplikatów jest trwałe w zależności od Twoich ustawień usuwania; przejrzyj każdą grupę uważnie i zachowaj przynajmniej jedną kopię wszystkiego, czego jeszcze potrzebujesz.
