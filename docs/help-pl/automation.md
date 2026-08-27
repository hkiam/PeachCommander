---
title: Automatyzacja (AppleScript i Skróty)
slug: automation
section: Zaawansowane narzędzia
order: 98
related: [start-menu, settings, macros]
---

Automatyzacja działa tu w obie strony.

**Na zewnątrz:** Peach Commander da się skryptować, więc możesz nim sterować z AppleScript i z aplikacji Skróty. Kilka podstawowych czasowników pozwala skryptowi nawigować po panelach, zaznaczać pliki maską, kopiować lub przenosić bieżące zaznaczenie oraz uruchamiać dowolne polecenie Peach Commandera po jego id — wykorzystując dokładnie te same działania co menu, więc krok ze skryptu zachowuje się jak ręczny. O tym jest reszta tej strony.

**Do wewnątrz:** Peach Commander może też *uruchomić* Twój skrypt — AppleScript albo JavaScript — i umieścić go w menu, na przycisku lub na klawiszu. Potrzebna jest do tego wtyczka **Scripting**, dostarczana wyłączona; zobacz [Uruchamianie własnych skryptów](#uruchamianie-wlasnych-skryptow) poniżej.

Aby powtarzać *sekwencję* działań na plikach, a nie jedno, zobacz [Makra](macros.md).

## Zobacz słownik

1. Otwórz **Edytor skryptów** (w `/Applications/Utilities` — w Finderze „Narzędzia”).
2. Wybierz **Okno ▸ Biblioteka**, a następnie kliknij dwukrotnie **Peach Commander** (dodaj go przyciskiem **+**, jeśli nie jest wymieniony).
3. Słownik się otworzy, wymieniając polecenia i właściwości poniżej.

Przy pierwszym sterowaniu Peach Commanderem przez skrypt macOS poprosi o zezwolenie (**Ustawienia systemowe ▸ Prywatność i bezpieczeństwo ▸ Automatyzacja**). Zatwierdź to raz, a późniejsze skrypty działają bez pytania.

## Co możesz odczytać

| Właściwość | Znaczenie |
| --- | --- |
| `active folder` | Ścieżka POSIX folderu aktywnego panelu. |
| `inactive folder` | Ścieżka POSIX folderu drugiego panelu. |
| `selection paths` | Zaznaczone elementy w aktywnym panelu (lub element pod kursorem). |

## Czasowniki

| Polecenie | Co robi |
| --- | --- |
| `go to "<ścieżka>" [in left\|right]` | Otwórz folder w panelu (domyślnie: aktywny panel). |
| `select "<maska>"` | Zaznacz elementy w aktywnym panelu według maski z symbolami wieloznacznymi, np. `*.pdf`. |
| `copy items to "<folder>"` | Skopiuj wybór aktywnego panelu do folderu. |
| `move items to "<folder>"` | Przenieś wybór aktywnego panelu do folderu. |
| `run command "<id>"` | Uruchom dowolne polecenie po jego identyfikatorze, np. `cm_PackFiles`. |

Kopiowanie i przenoszenie używają tej samej kolejki transferu w tle co F5/F6, więc postęp i ewentualne pytania o nadpisanie pojawiają się dokładnie tak, jak przy operacji ręcznej.

## Przykład

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Używanie z aplikacji Skróty

W aplikacji **Skróty** dodaj akcję **Uruchom AppleScript** i wklej skrypt taki jak powyżej. Pozwala to włączyć krok Peach Commandera do większego Skrótu — na przykład wyzwalanego zmianą folderu lub klawiszem skrótu.

## Uruchamianie własnych skryptów

Druga strona: Twój skrypt, uruchamiany przez Peach Commandera.

To wtyczka, i jest dostarczana **wyłączona**, bo uruchomienie wybranego programu potrafi wszystko, co potrafi reszta aplikacji, oraz kilka rzeczy, których nie obejmuje nic z niej. Dwa przełączniki, oba wyłączone, dopóki ich nie ustawisz:

1. **Konfiguracja ▸ Wtyczki…** — włącz **Scripting**.
2. **Ustawienia ▸ AI** — włącz **Zezwalaj na uruchamianie skryptów**. Jest na tej stronie, bo to ten sam rodzaj uprawnienia co powłoka asystenta, a te dwa idą w parze.

Następnie umieść skrypt w `scripts/` w folderze konfiguracji — **Polecenia ▸ Otwórz folder skryptów** zaprowadzi Cię tam i za pierwszym razem zostawi przykład. Plik `.applescript`, `.scpt` lub `.jxa` w tym folderze *jest* skryptem; nie ma czego rejestrować.

### Co dostaje skrypt

Stan paneli przychodzi w środowisku, więc zwykły przypadek nie wymaga zdarzeń Apple ani żadnego pytania o uprawnienia:

| Zmienna | Znaczy |
| --- | --- |
| `PC_ACTIVE_DIR` | Folder aktywnego panelu |
| `PC_TARGET_DIR` | Folder drugiego panelu |
| `PC_CURSOR_NAME` | Plik pod kursorem |
| `PC_SELECTION_COUNT` | Ile elementów jest zaznaczonych |
| `PC_SELECTION_FILE` | Plik tekstowy z jedną zaznaczoną ścieżką na wiersz (brak go, gdy nic nie jest zaznaczone) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Wszystko poza tym idzie przez samą aplikację, z użyciem czasowników powyżej — obie połowy się więc składają.

### Umieszczanie skryptu na przycisku lub klawiszu

Każdy skrypt staje się poleceniem o nazwie `plugin.script.run.<nazwa>`, gdzie `<nazwa>` to nazwa pliku bez rozszerzenia (spacje i kropki zamieniają się w łączniki). To id działa wszędzie, gdzie działa id `cm_*`: na pasku przycisków, w `usercmd.ini`, w pliku `.mnu` i w **Konfiguracja ▸ Edytuj skróty…**.

### Jak uruchamiany jest skrypt i limit czasu

Domyślnie skrypt działa jako osobny proces, co pozwala nadać mu limit czasu i zatrzymać go po jego przekroczeniu — trzydzieści sekund, o ile nie ustalisz inaczej. Skrypt może wybrać działanie *wewnątrz* aplikacji, co pozwala mu zwrócić wartość strukturalną i zachowuje go skompilowanym między uruchomieniami, ale wtedy nie ma limitu czasu: skrypt w pętli zatrzymuje aplikację. Wybór zapisz w `scripts.json` obok swoich skryptów:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Wpisu wymaga tylko to, co odbiega od wartości domyślnych; plik bez wpisu otrzymuje własną nazwę jako tytuł, działa jako osobny proces i zostaje zatrzymany po trzydziestu sekundach.

### Dla asystenta

Przy włączonej wtyczce i ustawieniu asystent zyskuje `run_applescript`, `run_jxa` i `check_script`. Każde z nich pokazuje Ci dokładny skrypt i czeka na Twoją zgodę, zanim cokolwiek się uruchomi, i żadne nigdy nie jest oferowane zewnętrznemu agentowi przez MCP.

## Uwagi

- Identyfikator polecenia przekazywany do `run command` jest tym samym identyfikatorem `cm_*`, który pokazuje się w przeglądarce poleceń (zobacz [Menu Start i polecenia niestandardowe](start-menu.md)).
- Skryptowanie zawsze działa na **aktywnym** panelu; użyj najpierw `go to … in left` / `in right`, jeśli potrzebujesz konkretnej strony.
- Peach Commander to aplikacja z jednym oknem, więc skrypty kierują się na oba panele tego okna.
