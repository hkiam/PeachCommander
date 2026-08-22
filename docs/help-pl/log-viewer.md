---
title: Przeglądarka logów
slug: log-viewer
section: Wtyczki
order: 128
related: [plugins, viewing-files, searching]
---

Ustaw kursor na pliku logu i wybierz **Pokaż jako log…**, aby otworzyć go w oknie zbudowanym dla logów, a nie dla tekstu: jeden wiersz na wiersz, poziom każdego rozpoznany i pokolorowany, filtr oraz śledzenie, które nadąża, gdy plik wciąż jest zapisywany.

To wtyczka: możesz ją wyłączyć lub usunąć w **Konfiguracja ▸ Wtyczki…**. Bez niej F3 pokazuje log tak jak każdy inny plik tekstowy.

## Dlaczego otwiera się natychmiast

Plik jest mapowany w pamięci, a w tle budowany jest jedynie indeks tego, gdzie zaczyna się każdy wiersz. Nic nie jest wczytywane jako tekst, zanim nie znajdzie się na ekranie, i dekodowane są tylko wiersze rzeczywiście widoczne. Log o wielkości kilku gigabajtów otwiera się tak szybko jak mały, a przejście na koniec nie czyta środka.

## Poziomy i kolor

Każdy wiersz jest klasyfikowany — **Błąd**, **Ostrzeżenie**, **Info**, **Debug**, **Trace** albo **Nieznany**, gdy format nic nie zdradza — i odpowiednio kolorowany. Domyślne kolory podążają za jasnym lub ciemnym wyglądem; ustaw własne w ustawieniach wtyczki, a będą używane twoje.

Kolumna **Poziom** pozwala jednym spojrzeniem zobaczyć, gdzie są błędy, a pole filtra zawęża listę do tego, czego szukasz. Włącz **Regex**, aby filtrować wyrażeniem regularnym zamiast zwykłym tekstem.

## Śledzenie pliku, który wciąż rośnie

Włącz **Na żywo (autoprzewijanie)**, a okno będzie podążać za końcem pliku w miarę napływania wierszy: indeks jest rozszerzany o dopisane bajty, a nie budowany od nowa, więc pozostaje tani niezależnie od długości pliku. Przewiń w górę, a czytasz historię; śledzenie działa dalej pod spodem.

## Poruszanie się

| | |
| --- | --- |
| **Znajdź…** | Przeszukuje komunikaty; **Znajdź (oznacz i przejdź)…** zaznacza każde trafienie, byś mógł między nimi przechodzić |
| **Idź do wiersza…** | Przechodzi do fizycznego numeru wiersza |
| **Idź do daty/godziny…** | Przechodzi do pierwszego wiersza od podanego znacznika czasu, np. `2024-01-15 10:23:45` |

Kopiowanie wie, czym jest wiersz logu: **Kopiuj wiersz** bierze wiersz pod kursorem, **Kopiuj wpis (wszystkie wiersze)** bierze cały wpis, gdy rozciąga się na kilka wierszy — na przykład ślad stosu — a **Kopiuj zaznaczone wiersze** bierze dokładnie to, co zaznaczono.

## Formaty

**log4j**, **log4net** i **CSV** są wbudowane, a format rozpoznawany automatycznie; okno pokazuje, na czym się zatrzymało. Jeśli twoje logi nie są żadnym z nich, dodaj własny w ustawieniach pod **Formaty logów**: wyrażenie regularne z grupami nazwanymi dla istotnych części.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Wiersz, do którego wyrażenie nie pasuje, i tak się pojawi — zostanie po prostu zaklasyfikowany jako Nieznany zamiast odrzucony, bo log, którego nie można przeczytać, jest gorszy niż log bez kolorów.

## Wyświetlanie

**Pokaż numery wierszy** i **Zawijaj długie wiersze** znajdziesz w ustawieniach. Obszar szczegółów pod listą zawsze pokazuje pełny tekst zaznaczonego wpisu, zawinięty, cokolwiek robi lista.
