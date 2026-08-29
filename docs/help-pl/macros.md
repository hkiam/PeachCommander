---
title: Makra
slug: macros
section: Narzędzia zaawansowane
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro to nazwana sekwencja działań na plikach — utwórz folder, przenieś do niego zaznaczenie, oznacz to, co zostało — którą można uruchomić ponownie jednym kliknięciem. To nie jest język skryptowy: nie ma warunków ani pętli, i tak jest zamierzone. Makro jest listą, którą można przeczytać, a przeczytać trzeba móc, zanim się je zatwierdzi.

Wszystko, co robi makro, przechodzi przez tę samą maszynerię, z której korzysta asystent. Makro nie może więc zrobić nic, na co nie ma Twojej zgody, każdy jego krok pojawia się w dzienniku działań, a krok, który da się cofnąć, wciąż się da.

## Jedno okno: Konfiguracja ▸ Makra…

Wszystko, co dotyczy makr, kryje się za tym jednym wpisem: lista, dwa sposoby utworzenia makra i droga do pliku. W menu nie ma już nic do wybierania.

## Najszybsza droga: nagraj makro

Nie musisz pisać makra od zera i nie musisz potem ustalać, gdzie się zaczęło.

1. **Konfiguracja ▸ Makra… ▸ Nagraj makro…**. Okno usuwa się na bok, a pojawia się mały panel informujący, że trwa nagrywanie, i liczący kroki na bieżąco.
2. Wykonaj pracę raz — kopiuj, przenoś, zmieniaj nazwy, usuwaj, twórz foldery i pliki. Pracuj normalnie; nagrywanie nie przeszkadza.
3. **Zatrzymaj i zapisz…**.
4. Kroki wracają już zaznaczone. Odznacz to, co tylko przygotowywało grunt, nadaj makru nazwę i zostaw włączone **Dodaj też przycisk dla niego**.
5. Zaznaczcie **Podążaj za panelami zamiast za dokładnie tymi plikami**, jeśli makro ma następnym razem pracować na tym, co będzie wtedy zaznaczone. Wiersze zmieniają się przy zaznaczaniu, więc widzicie, co zapisujecie.

**Zapisz makro** — i przycisk jest na pasku. To cały cykl.

**Odrzuć nagranie** wyrzuca nagranie i nic nie zapisuje. Przed naciśnięciem Nagraj nic nie jest nagrywane, po zatrzymaniu również — po to właśnie są oba końce.

Nagranie przeżywa ponowne uruchomienie. Jeśli Peach Commander zakończy się w trakcie — bo wyjdziesz albo bo się zawiesi — wraca razem z nagraniem, mówi o tym, a ty kontynuujesz albo je odrzucasz.

Jeśli wolisz mieć to na klawiszu albo przycisku, polecenie nazywa się `cm_MacroRecord`: rozpoczyna nagrywanie i zatrzymuje trwające.

## Druga droga: z tego, co już się wydarzyło

**Z ostatnich działań…** w tym samym oknie buduje makro z ostatnich rzeczy, które się wydarzyły, zamiast nagrywać nowe — przydatne, gdy *właśnie* wykonałeś pracę i dopiero wtedy pomyślałeś o makrze.

![Arkusz „Makro z ostatnich działań” z tym, co właśnie zrobiono, jako krokami do zaznaczenia](screenshots/macro-recorder.png)
*To, co już się wydarzyło, zaproponowane jako kroki nowego makra.*

Lista zawiera jedno i drugie: to, co zrobiliście w panelach (F5, F6, F7, F8 i zmiana nazwy), oraz to, co zrobił asystent albo inne makro. Każdy wiersz mówi, które z dwojga — po sesji z jednym i drugim te same dwa pliki mogą pojawić się w każdym z nich. Tutaj wiersze są początkowo niezaznaczone: „wszystko, co zrobiłem przez ostatnie pół godziny” rzadko jest tym makrem, o które chodzi.

> **Ta droga potrzebuje historii.** To, co robisz ręcznie, odczytywane jest z globalnej historii; jeśli ją wyłączyłeś (Ustawienia ▸ Różne ▸ **Zapisuj globalną historię**), na tej liście nie ma nic twojego — i lista to mówi. **Nagraj makro…** od tego nie zależy.

> **Czego się nie oferuje.** Spakowania archiwum i wszystkiego innego, co aplikacja zapamiętuje tylko z nazwy, nie da się zamienić w krok — nie ma dla tego kształtu. Takie wiersze widnieją wyszarzone wraz z powodem, zamiast ich brakować, żeby lista pięciu oferująca trzy nie wyglądała, jakby dwóch nie zauważyła. A jeśli nie poprosicie inaczej, ścieżki są te, które naprawdę zadziałały: nagrane makro powtarza *tę* kopię, a nie „kopię tego rodzaju”. Otwórzcie je w edytorze i wstawcie `%S` albo `%T` tam, gdzie ma podążać za panelami.

**Podążaj za panelami** to sposób, by poprosić inaczej. Pliki pochodzące wszystkie z jednego folderu stają się zaznaczeniem; folder będący jednym z dwóch paneli staje się tym panelem, a folder wewnątrz zachowuje swoją końcówkę — z nagranego „przenieś te cztery faktury do Dokumenty/2026-08” robi się „przenieś to, co zaznaczone, do *2026-08* po drugiej stronie”, i jutro działa to w dwóch innych folderach. To, co nie leży pod żadnym z paneli, zostaje ścieżką, którą jest — nie ma w co tego złożyć. Opcja pojawia się tylko wtedy, gdy coś by zmieniła.

## Dołączone przykłady

Przy pierwszym otwarciu **Edytuj plik…** plik zostaje założony z ośmioma gotowymi przykładami. To zwykłe makra — zmieniaj je albo usuwaj te, których nie chcesz — a każde niesie komentarz mówiący, co robi i co w nim zmienić:

| Makro | Co robi |
| --- | --- |
| **Open today's folder** | Tworzy w aktywnym panelu dzisiejszy folder z datą i wchodzi do niego. Jutro przyda się znowu. |
| **File the selection into a dated folder** | Zaznacza wszystkie PDF-y, tworzy po drugiej stronie folder rok-miesiąc i przenosi je tam. |
| **Copy the selection to a dated backup folder** | Kopiuje to, co zaznaczyliście *wy*, do datowanego folderu po drugiej stronie. |
| **Move the pictures into an Images subfolder** | Jedna maska, jeden podfolder, w folderze, w którym i tak jesteście. |
| **Merge the CSV files into one and open it** | Pokazuje, jak krok używa tego, co wytworzył krok wcześniejszy. |
| **File the selection into a folder you name** | Przy uruchomieniu pyta was o folder. |
| **Mark the file under the cursor as reviewed** | Nadaje jej etykietę i datuje komentarz — jeden plik, nie zaznaczenie. |
| **Put the temporary files in the Trash** | Makro usuwające, i to właściwe, by raz zobaczyć pytanie o uprawnienia. |

Każde z nich staje się poleceniem, więc dowolne można umieścić na przycisku albo na klawiszu, nie pisząc niczego.

## Zarządzanie nimi

**Konfiguracja ▸ Makra…** to lista: jak nazywa się każde makro, jak nazywa się jego polecenie, ile ma kroków i o co zapyta bramka uprawnień — dzięki temu „to usuwa” widać, zanim położysz je na klawiszu. Stamtąd możesz uruchamiać, zmieniać nazwy, duplikować, zmieniać kolejność, usuwać, eksportować i importować. Najechanie na wiersz pokazuje jego kroki.

**Uruchom** to sposób na wypróbowanie makra, które właśnie nagrałeś, bez zamykania okna i szukania polecenia. Przechodzi przez ten sam plan i to samo potwierdzenie co każde inne uruchomienie — to okno nie ma własnych uprawnień.

**Eksportuj…** zapisuje zaznaczone makro do własnego pliku, a **Importuj…** dodaje makra z plików, które ktoś ci przysłał — po to właśnie jest jeden plik na makro. Import nigdy nie zastępuje: makro, którego identyfikator jest już zajęty, dostaje wolny (przychodzące `backup` obok twojego staje się `backup-2`), a ty dowiadujesz się, pod jakimi identyfikatorami wylądowały nowe, bo przycisk, który zrobisz, musi wskazać właściwe.

![Okno „Zarządzaj makrami” z nazwą polecenia, liczbą kroków i uprawnieniem każdego makra](screenshots/macro-manager.png)
*Jak nazywa się każde makro, jako co działa i o co poprosi o zgodę.*

Kolejność nie jest ozdobą: kolejność w pliku jest tą, w jakiej wypisują je Przeglądarka poleceń i wybór do paska przycisków.

**Przy usuwaniu proponuje się zabrać przyciski ze sobą**, i warto o tym wiedzieć, nawet jeśli nigdy nie otworzycie tego okna: makro usunięte ręcznie zostawia po sobie przycisk i klawisz, a żadne z nich już nic nie robi — aplikacja mówi teraz, że makra nie ma, zamiast milczeć, ale przycisk pozostaje waszą sprawą. Klawisz albo pozycję menu trzeba usunąć tam, gdzie zostały ustawione.

*Kroków* się tu nie edytuje. **Edytuj plik…** przekazuje to edytorowi, z tego samego powodu, dla którego nie ma formularza: krok to nazwa narzędzia wraz z argumentami, a to jest właśnie JSON.

## Ręczna edycja makr

**Edytuj plik…** otwiera własny plik zaznaczonego makra — `macros/<id>.json` w twoim folderze konfiguracyjnym, utworzony za pierwszym razem z powyższymi przykładami. Bez zaznaczenia w panelu pokazywany jest sam folder, gdzie F3 czyta jedno, a F4 edytuje jedno. Makro to lista kroków, a każdy krok wskazuje narzędzie i jego argumenty:

```json
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
```

Zapis natychmiast przeładowuje makra — i mówi, jeśli coś jest nie tak: literówka w nazwie narzędzia, brakujący wymagany argument, dwa makra o tym samym id. Makro z błędem nie jest uruchamiane i nie trafia na żaden przycisk; dowiadujecie się, które to i co w nim nie gra, póki edytor jest jeszcze otwarty.

Jakie narzędzia istnieją i co przyjmują, pokazuje **Konfiguracja ▸ Przeglądarka poleceń…**, albo zapytajcie asystenta o `list_macros`.

### Symbole zastępcze

Pojedyncze litery są te same, których używa pasek przycisków i menu Start: kto zrobił już przycisk, nie musi się tu uczyć niczego nowego.

| Symbol | Znaczy |
| --- | --- |
| `%P` | Folder aktywnego panelu |
| `%T` | Folder drugiego panelu |
| `%N` | Plik pod kursorem |
| `%S` | Zaznaczone pliki — **lista**, czyli dokładnie to, co przyjmują `copy`, `move` i `move_to_trash` |
| `%{date:yyyy-MM}` | Data uruchomienia makra, w tym formacie |
| `%{1.destination}` | Jedna nazwana wartość z wyniku kroku 1 — tutaj plik, który zapisało `merge_files` |
| `%{1}` | Cały wynik kroku 1, gdy ten krok wprost wytworzył ścieżkę albo listę ścieżek |
| `%{ask:Folder name}` | Pyta was, gdy makro się uruchamia. `%{ask:Folder name=Archive}` wypełnia pole wartością *Archive* |

Nawiasy klamrowe służą dodatkom, bo litery są już zajęte: `%M` w całym pozostałym programie oznacza „nazwę pod kursorem w drugim panelu”, więc miesiąca nie można było tak zapisać.

Do wyników kroków używajcie postaci **nazwanej**. Większość narzędzi zgłasza kilka wartości zamiast jednej — `merge_files` zgłasza, dokąd zapisało, ile plików scaliło i ile wierszy z tego wyszło — dlatego `%{2.destination}` to zwykły zapis, a samo `%{2}` działa tylko dla narzędzia zwracającego jedną ścieżkę. Nazwa, której nie ma albo która nie jest ścieżką, zatrzymuje makro, zamiast być zgadywana.

`%` w nazwie pliku to `%`. Nic z tego, co wytworzy krok, ani żadna nazwa z panelu nie jest z kolei czytana jako symbol zastępczy — plik o nazwie `50%Netto.pdf` przechodzi więc przez makra bez zmian. Dosłowny `%` w szablonie, który piszecie *wy*, podwójcie: `%%`.

### Pytanie o wartość

`%{ask:…}` to sposób, w jaki makro przyjmuje coś, czego nie może wiedzieć z góry — najczęstsze makro w ogóle to „przenieś zaznaczenie do folderu, który nazwę”, a bez tego folder musiałby być wpisany na stałe.

Pytanie pada **zanim** pojawi się plan, a odpowiedzi są już w nim: wiersze mówią „Przenieś zaznaczenie do «Faktury»”, a nie „do tego, co zaraz wpiszecie”. Anulowanie pytania anuluje makro; nic nie zostało zaproponowane, a tym bardziej wykonane.

To samo pytanie zapisane dwa razy zadaje się raz i używa w obu miejscach, więc dwa kroki nazywające ten sam folder nie mogą się rozejść. To, co następuje po pierwszym `=`, jest tym, od czego pole zaczyna. Sformułowanie jest wasze: pokazuje się dokładnie tak, jak je napisaliście, w języku, w którym je napisaliście.

Odpowiedź jest wartością, nigdy szablonem: wpisanie `50%Netto` daje folder o nazwie `50%Netto`.

Makra, które pyta, nie może uruchomić zewnętrzny agent przez MCP — nie ma tam kogo zapytać, a milczące wzięcie wartości domyślnych byłoby odpowiedzią w waszym imieniu. Zostaje odrzucone i tak też mówi.


`%S` to jedyne miejsce, w którym makro różni się od przycisku: na przycisku zaznaczenie staje się listą słów dla wiersza poleceń, tutaj staje się listą pełnych ścieżek, których oczekują narzędzia plikowe.

Krok, którego `%S` lub `%{1}` wychodzi **pusty, zatrzymuje makro**, zamiast działać na niczym. `move` bez plików nie jest mniejszym `move` — to żądanie, które już nic nie mówi, a zgłoszenie sukcesu byłoby kłamstwem.

## Uruchamianie makra

Każde makro staje się poleceniem o nazwie `mc_<id>` i dzięki temu samo pojawia się w:

- **Konfiguracja ▸ Przeglądarka poleceń…**
- **Konfiguracja ▸ Edytuj skróty… — przypisz je do klawisza**
- Wyborze poleceń w edytorze paska przycisków
- Twoim pliku menu `.mnu` i `usercmd.ini`, jeśli ich używasz
- Asystencie, który może je uruchomić po nazwie

Przed uruchomieniem makra, które coś zmienia, pokazuje ono swoje kroki jako listę i czeka. Możesz wykreślić krok, którego nie chcesz; to, co zostanie, zostanie wykonane. Makro, które tylko czyta, działa bez pytania. **Skreślenie kroku zabiera ze sobą kroki, które od niego zależą** — makro to sekwencja, a krok, który napełnia folder, nie może działać bez kroku, który go zakłada: te wiersze same się wyłączają i szarzeją. Przywróć krok, a wrócą — poza tymi, które skreśliłeś sam; te zostają skreślone.

![Okno potwierdzenia makra, każdy krok to pole wyboru wymieniające pliki](screenshots/macro-confirm.png)
*Kroki, rozwiązane względem waszych paneli — każdy można skreślić.*

Wszystko, co da się rozpoznać jako błędne przed startem — narzędzie, którego nie ma, brakujący argument, krok, który uruchomiłby inne makro — zatrzymuje makro przed pierwszym krokiem, a nie po trzecim. Jeśli krok zawiedzie już w trakcie, makro **zatrzymuje się tam** zamiast iść dalej: krok drugi zwykle zakłada, że krok pierwszy się zdarzył, a przenoszenie plików do nieutworzonego folderu nie jest częściowym sukcesem. Raport nazywa krok, mówi, co poszło źle, i ile kroków już wykonano; każdy z nich jest w dzienniku działań, z drogą powrotną tam, gdzie taka istnieje.
## Co makru wolno

Makro ocenia się po tym, co najbardziej wymagające w nim jest. Makro, którego kroki tylko czytają, jest traktowane jak czytanie; takie, które kończy się trwałym usunięciem, jest zabezpieczone jak trwałe usunięcie — przed uruchomieniem czegokolwiek, nie cztery kroki później.

Krok, który uruchamia *polecenie*, ocenia się po tym, co to polecenie robi, a nie po tym, że jest poleceniem — makro uruchamiające `cm_DeleteReal` jest więc makrem usuwającym i tak wam się je pokazuje. Makro nie może uruchomić innego makra, w żadnym z dwóch zapisów.

Nieprzyznawanie niczego ponad to jest domyślne. Jeśli makro zawiera krok, na który Twoje uprawnienia nie pozwalają — polecenie powłoki, skrypt — całe makro jest odrzucane z podaniem przyczyny i nic się nie dzieje.

## Cofanie

Każdy krok jest zapisywany osobno, więc **cofnij** po makrze wycofuje jego *ostatni* krok, a nie całe makro. Cofania całego makra nie ma, bo kilka narzędzi nie ma żadnej odwrotności, a przycisk, który by je oferował, kłamałby w ich sprawie.

## Gdzie się to zapisuje

- Twoje makra są w `macros/` w folderze konfiguracyjnym, po jednym jako `<id>.json` — zwykłe pliki, które możesz diffować, trzymać z dotfiles i komuś wysłać. `macros.json` ze starszej wersji jest przy pierwszym uruchomieniu przenoszony i zmieniany na `macros.json.migrated`; potem już nikt go nie czyta.
- Przyciski dodane przez makro to normalne wpisy paska przycisków w `default.bar`, więc usunięcie jednego wygląda tak samo jak przy każdym innym przycisku.

## Dalsze kroki

- [Automatyzacja (AppleScript i Skróty)](automation.md) — Sterowanie Peach Commanderem ze skryptu i uruchamianie własnych skryptów jako kroku makra.
- [Pasek przycisków](toolbar.md) — Gdzie trafia przycisk dodany przez makro.
- [Klawiatura i skróty](keyboard-shortcuts.md) — Przypisanie makra do klawisza.
