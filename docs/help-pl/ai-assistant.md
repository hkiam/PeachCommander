---
title: Asystent AI
slug: ai-assistant
section: Wtyczki
order: 122
related: [plugins, settings, privacy-and-security, macros]
---

Asystent AI to opcjonalna, usuwalna wtyczka, która pomaga pracować z plikami zwykłym językiem. Potrafi streścić lub wyjaśnić dokument, zaproponować lepszą nazwę pliku, przetłumaczyć lub sprawdzić tekst, zamienić dane w tabelę, a nawet uporządkować folder — i potrafi wykonać za Ciebie operacje na plikach, pokazawszy najpierw plan. Przychodzi jako dwie wtyczki: **AI On-Device** działa na Apple Intelligence i daje akcje, które pokazują propozycję i ją stosują, a **AI Assistant** to czat i wymaga modelu w chmurze. Włącz jedną albo obie. **Przychodzą wyłączone.** Włącz je w **Konfiguracja ▸ Wtyczki…** i uruchom ponownie, albo zostaw wyłączone i nic się nie pojawi — żadnego menu AI ▸, żadnego czatu, żadnej kolumny. To celowe, dopóki funkcja jest w wersji beta: potrafi zmieniać nazwy plików, przenosić je i usuwać oraz uruchamiać za Ciebie polecenia powłoki, każde za planem, który zatwierdzasz, a to dużo zasięgu, by domyślnie powierzać go nowości. Bez klucza API wszystko dzieje się na Twoim Macu, więc chodzi o zasięg, a nie o dane opuszczające maszynę. Wtyczka **AI Column** pokazuje, co te akcje ustaliły — streszczenie, rodzaj, temat, datę — jako kolumny panelu; sama nie uruchamia żadnego modelu. Przychodzi wyłączona razem z nimi i pozostaje opcjonalna, i nie pokazuje nic, dopóki jej nie włączysz i nie dodasz którejś z jej kolumn. Z tej samej strony możesz też usunąć każdą z nich całkowicie.

**Na urządzeniu czy w chmurze.** Model lokalny jest prywatny i darmowy, i jest mały: przyjmuje kilka tysięcy słów naraz. Przeczytanie *całego* długiego pliku działa więc inaczej — asystent czyta go partiami i składa wyniki, co trwa tym dłużej, im plik jest dłuższy. Do ciężkiej pracy na wielu plikach albo do długich rozmów model w chmurze jest szybszy i utrzymuje więcej naraz. Akcje z menu kontekstowego zawsze działają na Twoim Macu; to czat jest tą połową, która chce punktu końcowego, a **Ustawienia ▸ AI** to miejsce, gdzie mu go podajesz.

## Otwieranie asystenta

Wybierz **Polecenia ▸ Asystent AI**, aby pokazać asystenta w panelu zadokowanym po prawej stronie okna. Wpisz żądanie i naciśnij Enter; asystent potrafi czytać pliki, wyszukiwać informacje i — za Twoim potwierdzeniem — wprowadzać zmiany.

![Czat asystenta AI zadokowany obok paneli plików](screenshots/ai-chat.png)
*(Rysunek: asystent AI, zadokowany po prawej, pracuje nad żądaniem.)*

## Akcje w menu kontekstowym (AI ▸)

Najszybszy sposób użycia asystenta to podmenu **AI ▸** w menu kontekstowym:

- **Na pliku** — Streść, Wyjaśnij, Zaklasyfikuj, Zaproponuj nazwę, Zaproponuj komentarz, Przetłumacz na angielski, Sprawdź tekst, Wykryj zadania i Utwórz tabelę.
- **Na tle panelu** — Uporządkuj ten folder, Szukaj według znaczenia i Znajdź prawdopodobne duplikaty.

**Streść**, **Wyjaśnij**, **Zaklasyfikuj**, **Zaproponuj nazwę**, **Zaproponuj komentarz**, **Utwórz tabelę** i **Uporządkuj ten folder** pochodzą z wtyczki **AI On-Device** i wykonują swoją pracę bez otwierania czatu — także na skanie czy zrzucie ekranu, bo słowa są najpierw odczytywane z obrazu: pokazują propozycję w arkuszu, Ty odznaczasz to, co ma zostać nietknięte, i nic na dysku się nie zmienia, dopóki nie zatwierdzisz. Pozostałe akcje należą do wtyczki **AI Assistant** i otwierają **własny, zatytułowany czat** (na przykład *Przetłumacz – raport.txt*), dzięki czemu różne zadania pozostają rozdzielone, zamiast piętrzyć się w jednej długiej rozmowie. Gdy sam wpiszesz coś w polu wprowadzania, takie żądanie kontynuuje bieżący czat.

**Kilka plików naraz.** Zaznacz wybór, a akcja wykona się na każdym zaznaczonym pliku, jeden po drugim. Akcje korzystające z arkusza pokazują w nim postęp, a **Anuluj** zatrzymuje się między plikami; te, które otwierają czat, umieszczają postęp na pasku stanu, gdzie **Zatrzymaj** robi to samo. Tak czy inaczej możesz obejrzeć pierwsze wyniki i przerwać.

**Zaproponuj nazwę** kończy się przyciskiem, a nie zdaniem: proponowana nazwa pojawia się w pasku pod rozmową, a obok niej przycisk **Zmień nazwę**. Naciśnięcie go jest zatwierdzeniem — nie pytamy dwa razy. **Zaklasyfikuj** kończy się własną propozycją: **Uporządkuj w folderach…** proponuje cel dla każdego właśnie zaklasyfikowanego pliku — folder nazwany według jego rodzaju, a pod nim rok, jeśli dokument podaje datę — i niczego nie przenosi, dopóki nie zatwierdzisz listy. Każdy wiersz podaje znaleziony temat, więc zbyt szeroki rodzaj widać, zanim cokolwiek zostanie uporządkowane. Cofnięcie odzyskuje po jednym folderze docelowym.

### Własne sformułowania

To, o co każda akcja prosi model, jest plikiem tekstowym, który możesz edytować: `aichat/skills.json` dla akcji na plikach i `aichat/folder-skills.json` dla akcji na folderach, w Twoim folderze konfiguracyjnym. Oba są zapisywane z wbudowanymi sformułowaniami przy pierwszym uruchomieniu asystenta, żebyś zobaczył format. `{name}` i `{path}` oznaczają plik. Usuń plik, aby wrócić do wbudowanego sformułowania.

**Własne akcje.** Dodaj wpis z wybranym przez siebie `id`, a będzie można go uruchomić jak każde inne polecenie, podając `plugin.ai.skill.<id>` — w menu użytkownika, na pasku przycisków lub na skrócie klawiszowym. (Dla akcji na folderze `plugin.ai.folderskill.<id>`.) Podmenu **AI ▸** wymienia tylko akcje wbudowane: jest budowane z manifestu wtyczki bez jej ładowania, tak by wyłączona wtyczka nic do niego nie wnosiła — dlatego własne akcje umieszczasz sam, zamiast oczekiwać, że się tam pojawią. Podaj id, które nie istnieje, a asystent to powie, zamiast nie zrobić nic.

## Poproś go o znalezienie pliku

Nie musisz wiedzieć, gdzie plik leży. Opisz go, a asystent odszuka go w indeksie, który macOS już prowadzi dla Twojego dysku — nie ma więc nic do zbudowania ani czekania, aż nadrobi zaległości.

- *„Znajdź fakturę PDF z zeszłego miesiąca"* — rodzaj, słowo w nazwie i okno czasowe.
- *„Gdzie są wszystkie moje foldery node_modules?"* — foldery, po nazwie, gdziekolwiek w Twoim folderze domowym.
- *„Który plik wspomina o umowie akwizgrańskiej?"* — słowa **wewnątrz** plików, czego zwykłe wyszukiwanie Znajdź pliki nie potrafi, dopóki nie wskażesz mu folderu.

Możesz pokierować, gdzie ma szukać: domyślnie Twój folder domowy, cały komputer albo tylko folder pokazywany w panelu. Asystent mówi, którego użył, więc pustą odpowiedź da się przeczytać, zamiast przypominać wzruszenie ramionami.

Dwie granice warte poznania. macOS trzyma niektóre miejsca poza swoim indeksem — i poza zasięgiem każdej aplikacji bez Pełnego dostępu do dysku — więc „nic nie znaleziono" nie jest dowodem, że plik nie istnieje; zobacz [Rozwiązywanie problemów](troubleshooting). A świeżo utworzony plik może jeszcze nie być zindeksowany, i wtedy **Znajdź pliki** (Alt+F7), które samo przechodzi foldery, znajdzie go mimo to.

## Zarządzanie czatami

- Przełącznikiem czatów u góry panelu przechodzisz między rozmowami.
- Menu **Usuń ▾** oferuje **Usuń ten czat** i **Usuń wszystkie czaty**, więc gdy lista się wydłuży, wyczyścisz wszystko naraz. Puste czaty są sprzątane automatycznie przy zamknięciu panelu.

## Zmiany są najpierw potwierdzane

Przy wszystkim, co zmienia pliki — przenoszeniu, zmianie nazwy, zapisie, usuwaniu — asystent pokazuje **plan i czeka na Twoje potwierdzenie**, zanim zadziała. Możesz to zmienić w Ustawieniach, podnosząc samodzielność asystenta, albo obniżyć ją do tylko do odczytu, by nigdy niczego nie zmieniał. Kopiowanie lub przeniesienie jest zgłaszane jako wykonane, gdy jest wykonane: asystent czeka na zakończenie transferu, a Ty możesz go śledzić w Menedżerze transferów jak każdą inną operację.

**Możesz zgodzić się na część planu.** Gdy plan obejmuje kilka plików — zmianę nazw całego folderu, opróżnienie Pobranych — każdy pojawia się jako zaznaczony wiersz nad przyciskami. Odznacz te, które mają zostać nietknięte, i naciśnij **Potwierdź i wykonaj**: reszta idzie dalej, a to, co odznaczyłeś, nie zostaje ruszone. Odznaczenie wszystkiego jest tym samym co anulowanie, i asystent to mówi, zamiast zgłaszać, że nic nie zrobił. Plan będący pojedynczą akcją nie ma listy, bo Potwierdź i Anuluj już mówią mu tak i nie.

## Co asystent zrobił i jak to cofnąć

**Akcje ▾** w czacie mają dwie pozycje:

- **Pokaż, co asystent zrobił…** wymienia każdą zmianę, najnowszą jako pierwszą, z tym, o co go poproszono i jak się skończyło — łącznie z próbami, które ustawienie samodzielności odrzuciło. Zewnętrzny agent połączony przez MCP jest na tej samej liście.
- **Cofnij ostatnią zmianę** wycofuje najnowszą zmianę, która ma odwrotność: zmiana nazwy zostaje odwrócona, przeniesienie przeniesione z powrotem. Tam, gdzie nic nie da się wycofać, lista mówi dlaczego — nadpisany plik nie został nigdzie zachowany, a elementy w Koszu przywraca się z Findera.

Możesz też po prostu poprosić: *„cofnij to"* i *„co zmieniłeś?"* sięgają do tych samych dwóch funkcji.

Ta lista jest też źródłem makra: **Makra… ▸ Z ostatnich działań…** proponuje to, co asystent właśnie zrobił, jako kroki makra, które możecie uruchomić ponownie — z przycisku albo z klawisza. Zobacz [Makra](macros.md). To, co robi asystent, wyłapuje również **Nagraj makro…**, obok tego, co robisz ręcznie.

## Kolumny panelu

To, co akcje ustaliły, jest dostępne jako kolumny. Dodaj je w edytorze zestawów kolumn: **Podsumowanie AI** pokazuje pierwszy wiersz streszczenia, a **Rodzaj AI**, **Temat AI** i **Data AI** pokazują, co **Zaklasyfikuj** zrobiło z pliku — pod tymi nazwami po polsku, przetłumaczonymi w każdym języku. Każda pozostaje pusta, dopóki jakaś akcja nie przeczyta danego pliku — te kolumny pokazują pracę już wykonaną i nigdy same nie uruchamiają modelu. **Język** w tej samej wtyczce rozpoznaje, w jakim języku napisany jest plik tekstowy, całkiem bez modelu.

Te same trzy są też symbolami zmiany nazw. `[=ai_column.ai_topic]-[Y]-[M].[E]` w oknie zbiorczej zmiany nazw (Ctrl+M) nadaje folderowi pełnemu plików `dokument1.pdf` nazwy według tego, czym są: nic do tego nie zbudowano, bo maska zmiany nazw od zawsze rozwiązuje `[=provider.field]` przez system kolumn. Najpierw zaklasyfikuj, potem zmień nazwy. Nagłówek podąża za Twoim językiem; `ai_column.ai_topic` wewnątrz maski nie — maska działa więc dalej, gdy zmienisz język.

## Ustawienia

Otwórz **Konfiguracja ▸ Ustawienia ▸ AI**, aby skonfigurować asystenta na jednej stronie:

- **Model czatu** — na czym działa czat **AI Assistant**. Odkąd akcje lokalne stały się osobną wtyczką, odpowiedzi są dwie, nie trzy: *Punkt końcowy w chmurze poniżej, jeśli jakiś podałeś*, albo *Nic — zostaw pracę wtyczce AI On-Device*. Strona jest pogrupowana tak samo: najpierw ustawienia czatu, pod nimi to, co wolno obu połowom.
- **Punkt końcowy w chmurze, model i klucz API** — aby użyć modelu zgodnego z OpenAI zamiast lokalnego. Klucz jest przechowywany w pęku kluczy macOS, nigdy w plikach konfiguracyjnych.
- **Samodzielność asystenta** — tylko do odczytu, potwierdzaj zmiany (domyślnie) lub samodzielny.
- **Własny prompt systemowy** — opcjonalne wskazówki kształtujące sposób, w jaki asystent odpowiada.
- **Serwer MCP** — opcjonalny, wyłącznie lokalny serwer pozwalający zewnętrznemu agentowi sterować aplikacją; domyślnie wyłączony i możliwy do zabezpieczenia tokenem.

![Strona AI w Ustawieniach z samodzielnością i opcjami serwera MCP](screenshots/settings-ai.png)
*(Rysunek: wszystkie opcje asystenta są na jednej stronie AI w Ustawieniach.)*

## Prywatność

- Z Apple Intelligence asystent działa **na Twoim Macu**; nic nie opuszcza urządzenia.
- Model w chmurze jest używany **tylko wtedy, gdy jakiś skonfigurujesz**, a jego klucz API zostaje w pęku kluczy.
- Akcje zmieniające pliki są potwierdzane przed wykonaniem, chyba że świadomie podniesiesz poziom samodzielności.
