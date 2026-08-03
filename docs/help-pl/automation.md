---
title: Automatyzacja (AppleScript i Skróty)
slug: automation
section: Zaawansowane narzędzia
order: 98
related: [start-menu, settings]
---

Peach Commander można skryptować, więc możesz sterować nim z AppleScript i z aplikacji Skróty. Garść podstawowych czasowników pozwala skryptowi nawigować po panelach, wybierać pliki według maski, kopiować lub przenosić bieżący wybór oraz uruchamiać dowolne polecenie Peach Commandera po jego identyfikatorze — ponownie używając dokładnie tych samych akcji, których używają menu, dzięki czemu krok skryptowy zachowuje się jak ręczny. Jest to przydatne przy powtarzalnych zadaniach: porządkowaniu pobranych plików, przygotowywaniu wyniku kompilacji lub włączeniu kroku plikowego do większego Skrótu.

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

## Uwagi

- Identyfikator polecenia przekazywany do `run command` jest tym samym identyfikatorem `cm_*`, który pokazuje się w przeglądarce poleceń (zobacz [Menu Start i polecenia niestandardowe](start-menu.md)).
- Skryptowanie zawsze działa na **aktywnym** panelu; użyj najpierw `go to … in left` / `in right`, jeśli potrzebujesz konkretnej strony.
- Peach Commander to aplikacja z jednym oknem, więc skrypty kierują się na oba panele tego okna.
