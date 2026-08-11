---
title: Dekompilacja Javy i .NET
slug: decompilers
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Naciśnij **F3** na skompilowanym pliku i zobacz kod źródłowy zamiast bajtów. Robią to dwie wtyczki — jedna dla Javy (`.class`, `.jar`, `.apk`, `.dex`) i jedna dla .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — a zachowują się tak samo, więc ta strona obejmuje obie. Każdą można osobno wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**.

Archiwum pokazuje się jako drzewo swoich klas, pojedyncza klasa jako jeden plik. **Dekompiluj do źródeł** w menu Polecenia zapisuje wynik i umieszcza go w panelu, więc możesz w nim szukać, porównywać i kopiować jak w każdym innym folderze ze źródłami.

## Silnik instalujesz sam

Żaden dekompilator nie jest dołączony i nic nie jest za ciebie pobierane. To celowe z dwóch powodów: JD-Core, najbardziej znany dekompilator Javy, jest na GPLv3 i nie mógłby być dostarczany wewnątrz aplikacji na Apache-2.0 — a silniki się poprawiają, więc wymiana jednego nie powinna wymagać nowej wersji Peach Commandera.

**Folder silników…** w przeglądarce otwiera folder, do którego należą. Tamtejszy README wymienia każdy silnik i jego licencję.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (dla androidowych `.dex` i `.apk`) oraz `javap` dla surowego kodu bajtowego |
| .NET | ILSpy oraz `monodis` dla IL |

**Sprawdź silniki** uruchamia polecenie wersji każdego silnika i rozróżnia trzy rzeczy: zainstalowany i działający, niezainstalowany oraz *zainstalowany, ale niezdolny do uruchomienia* — narzędzie Javy bez JDK jest obecne i mimo to nie wystartuje, a ujawnia to dopiero faktyczne uruchomienie.

Silnik opisują dane, a nie kod, więc możesz dodać własny:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Gdy z plikiem poradzi sobie więcej niż jeden silnik, używany jest pierwszy dostępny, chyba że wybierzesz konkretny. Przy dwóch zainstalowanych **Porównaj** pokazuje oba wyniki obok siebie — przydatne, gdy jeden silnik poddaje się przy metodzie, z którą drugi sobie radzi.

## Szukanie w skompilowanym kodzie

**Przeszukaj wszystkie klasy** przegląda zdekompilowany tekst zamiast bajtów, więc w pliku JAR znajdziesz literał tekstowy albo nazwę metody.

Dekompilacja podczas *przeszukiwania zawartości* wielu plików to osobne ustawienie, domyślnie wyłączone: wytworzenie tekstu może oznaczać uruchomienie silnika raz na klasę, co na wolnej maszynie nie jest rozsądnym wydatkiem na wyszukiwanie. Główne okno wyszukiwania pyta osobno; tutaj również jest to odrzucane.

## Pamięć podręczna i ograniczenia

Wyniki trafiają do pamięci podręcznej, bo dekompilowanie tej samej klasy dwa razy to czyste czekanie. W ustawieniach jest, ile dni przechowywać wyniki, oraz **ograniczenie rozmiaru** pamięci podręcznej; **Wyczyść pamięć podręczną** opróżnia ją i podaje, ile zwolniono.

Dwa limity czasu chronią przed silnikiem, który nie kończy: jeden dla pojedynczej klasy lub typu, drugi dla całego archiwum. Oba przyjmują 0, co oznacza „użyj domyślnej wartości silnika”.
