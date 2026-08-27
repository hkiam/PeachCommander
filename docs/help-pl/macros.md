---
title: Makra
slug: macros
section: Narzędzia zaawansowane
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro to nazwana sekwencja działań na plikach — utwórz folder, przenieś do niego zaznaczenie, oznacz to, co zostało — którą można uruchomić ponownie jednym kliknięciem. To nie jest język skryptowy: nie ma warunków ani pętli, i tak jest zamierzone. Makro jest listą, którą można przeczytać, a przeczytać trzeba móc, zanim się je zatwierdzi.

Wszystko, co robi makro, przechodzi przez tę samą maszynerię, z której korzysta asystent. Makro nie może więc zrobić nic, na co nie ma Twojej zgody, każdy jego krok pojawia się w dzienniku działań, a krok, który da się cofnąć, wciąż się da.

## Najszybsza droga: z tego, co właśnie zrobiłeś

Nie musisz pisać makra od zera.

1. Zrób to raz — przez asystenta albo uruchamiając istniejące makro.
2. Wybierz **Konfiguracja ▸ Makro z ostatnich działań…**.
3. Zaznacz kroki, które makro ma powtarzać, nadaj mu nazwę i zostaw włączone **Dodaj też przycisk dla niego**.

**Zapisz makro** — i przycisk jest na pasku. To cały cykl.

> **Czego się nie zapisuje.** Lista powstaje z działań, które przeszły przez asystenta lub inne makro. Ręczne kopiowanie, przenoszenie i zmiana nazw w panelach — F5, F6, F7 — nie są zapisywane, więc tą drogą nie da się z nich zrobić makra. Do tego użyj edytora poniżej.

## Ręczna edycja makr

**Konfiguracja ▸ Edytuj makra…** otwiera `macros.json` w folderze konfiguracji i przy pierwszym razie zostawia w nim skomentowany przykład. Makro to lista kroków, a każdy krok wskazuje narzędzie i jego argumenty:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Zapis natychmiast przeładowuje makra. Jakie narzędzia istnieją i co przyjmują, powie asystent przez `list_macros` — albo przykład, z którym plik został utworzony.

### Symbole zastępcze

Pojedyncze litery są te same, których używa pasek przycisków i menu Start: kto zrobił już przycisk, nie musi się tu uczyć niczego nowego.

| Symbol | Znaczy |
| --- | --- |
| `%P` | Folder aktywnego panelu |
| `%T` | Folder drugiego panelu |
| `%N` | Plik pod kursorem |
| `%S` | Zaznaczone pliki — **lista**, czyli dokładnie to, co przyjmują `copy`, `move` i `move_to_trash` |
| `%{date:yyyy-MM}` | Data uruchomienia makra, w tym formacie |
| `%{1}` | Wynik kroku 1, o ile ten krok zwrócił ścieżkę lub listę ścieżek |

Nawiasy klamrowe służą dodatkom, bo litery są już zajęte: `%M` w całym pozostałym programie oznacza „nazwę pod kursorem w drugim panelu”, więc miesiąca nie można było tak zapisać.

`%S` to jedyne miejsce, w którym makro różni się od przycisku: na przycisku zaznaczenie staje się listą słów dla wiersza poleceń, tutaj staje się listą pełnych ścieżek, których oczekują narzędzia plikowe.

Krok, którego `%S` lub `%{1}` wychodzi **pusty, zatrzymuje makro**, zamiast działać na niczym. `move` bez plików nie jest mniejszym `move` — to żądanie, które już nic nie mówi, a zgłoszenie sukcesu byłoby kłamstwem.

## Uruchamianie makra

Każde makro staje się poleceniem o nazwie `mc_<id>` i dzięki temu samo pojawia się w:

- **Konfiguracja ▸ Przeglądarka poleceń…**
- **Konfiguracja ▸ Edytuj skróty… — przypisz je do klawisza**
- Wyborze poleceń w edytorze paska przycisków
- Twoim pliku menu `.mnu` i `usercmd.ini`, jeśli ich używasz
- Asystencie, który może je uruchomić po nazwie

Przed uruchomieniem makra, które coś zmienia, pokazuje ono swoje kroki jako listę i czeka. Możesz wykreślić krok, którego nie chcesz; to, co zostanie, zostanie wykonane. Makro, które tylko czyta, działa bez pytania.

Jeśli krok zawiedzie, makro **zatrzymuje się w tym miejscu**, zamiast iść dalej — krok drugi zwykle zakłada, że krok pierwszy się wykonał, a przenoszenie plików do nieutworzonego folderu nie jest częściowym sukcesem. Raport wskazuje krok i mówi, co poszło źle; kroki, które się wykonały, są w dzienniku działań.

## Co makru wolno

Makro ocenia się po tym, co najbardziej wymagające w nim jest. Makro, którego kroki tylko czytają, jest traktowane jak czytanie; takie, które kończy się trwałym usunięciem, jest zabezpieczone jak trwałe usunięcie — przed uruchomieniem czegokolwiek, nie cztery kroki później.

Nieprzyznawanie niczego ponad to jest domyślne. Jeśli makro zawiera krok, na który Twoje uprawnienia nie pozwalają — polecenie powłoki, skrypt — całe makro jest odrzucane z podaniem przyczyny i nic się nie dzieje.

## Cofanie

Każdy krok jest zapisywany osobno, więc **cofnij** po makrze wycofuje jego *ostatni* krok, a nie całe makro. Cofania całego makra nie ma, bo kilka narzędzi nie ma żadnej odwrotności, a przycisk, który by je oferował, kłamałby w ich sprawie.

## Gdzie się to zapisuje

- Twoje makra są w `macros.json` w folderze konfiguracji — to zwykły plik, który można porównywać i trzymać razem z dotfiles.
- Przyciski dodane przez makro to normalne wpisy paska przycisków w `default.bar`, więc usunięcie jednego wygląda tak samo jak przy każdym innym przycisku.

## Dalsze kroki

- [Automatyzacja (AppleScript i Skróty)](automation.md) — Sterowanie Peach Commanderem ze skryptu i uruchamianie własnych skryptów jako kroku makra.
- [Pasek przycisków](toolbar.md) — Gdzie trafia przycisk dodany przez makro.
- [Klawiatura i skróty](keyboard-shortcuts.md) — Przypisanie makra do klawisza.
