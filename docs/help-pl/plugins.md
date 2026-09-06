---
title: Wtyczki
slug: plugins
section: Wtyczki
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Wtyczki rozszerzają Peach Commander o dodatkowe narzędzia, formaty plików i miejsca do przeglądania. Kilkanaście wtyczek jest wbudowanych, więc możesz zacząć ich używać od razu, a poszczególne wtyczki możesz włączać lub wyłączać — albo instalować nowe — z jednego okna. Używaj wtyczek, gdy chcesz możliwości wykraczające poza codzienne kopiowanie i przeglądanie: wizualizować, co zapełnia dysk, łączyć się z serwerem WebDAV, sprawdzać stan repozytorium Git, obserwować aktywność systemu i więcej.

Wtyczki występują w kilku odmianach: niektóre dodają **panel lub pasek boczny** (widok), niektóre dodają **kolumny** do listy plików, niektóre dodają **miejsce, do którego wchodzisz**, jak dysk, a niektóre uczą aplikację nowego **formatu archiwum**. Każda jest włączana niezależnie.

## Co dodają wbudowane wtyczki

Kilka wtyczek ma własny szczegółowy temat pomocy — kliknij łącze, aby poznać całą historię:

- **[Mapa dysku](disk-map.md)** — wizualizuje, co zapełnia folder lub wolumin, jako mapę drzewa lub wykres słoneczny, uzgodnione z wolnym, możliwym do wyczyszczenia i ukrytym miejscem, z kolekcjonerem do sprzątania.
- **[Asystent AI](ai-assistant.md)** — opcjonalny, usuwalny asystent, który podsumowuje, zmienia nazwy, tłumaczy, tworzy tabele i porządkuje pliki w języku naturalnym, na urządzeniu lub przez model w chmurze.
- **[Git](git.md)** — pokazuje stan każdego pliku w drzewie roboczym oraz bieżącą gałąź jako kolumny panelu i dodaje menu **Git** dla statusu, dodawania do przechowalni, commita, pulla i pusha.
- **[System Monitor](system-monitor.md)** — podgląd procesora, pamięci, dysku, sieci (a tam, gdzie dostępne, GPU, baterii, czujników) w czasie rzeczywistym na pasku tytułu okna, z klikalnymi wykresami szczegółów.
- **[Task Manager](task-manager.md)** — montuje Twoje działające procesy jako przeglądalny dysk **TaskManager**; sortuj je, badaj jak pliki lub kończ klawiszem Usuń.
- **[Obrazy systemów plików](filesystem-images.md)** — otwiera obraz systemu plików (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) jak archiwum, także obrazy dysków z wieloma partycjami. Tylko do odczytu i wyłączona, dopóki jej nie włączysz.
- **[Uninstaller](uninstaller.md)** — usuwa aplikację **oraz** pliki pomocnicze, pamięci podręczne i preferencje, które po sobie zostawia, po pokazaniu Ci dokładnie, co zniknie.

Pozostałe wbudowane wtyczki są mniejsze i nie potrzebują własnej strony:

- **Amazon S3** — połącz się z Amazon S3 lub magazynem zgodnym z S3 (**Sieć ▸ Połącz z Amazon S3…**) i przeglądaj buckety jak foldery, z czytaniem, zapisem, zmianą nazwy i usuwaniem. Tajne klucze są przechowywane w Pęku kluczy macOS.
- **WebDAV** — połącz się z serwerem WebDAV (**Sieć ▸ Połącz z WebDAV…**) i przeglądaj, wysyłaj, pobieraj, zmieniaj nazwy oraz usuwaj na nim tak, jakby był folderem. Hasła są przechowywane w pęku kluczy macOS.
- **iCloud Drive** — dodaje pozycję *iCloud Drive* do paska dysków, która przechodzi prosto do Twojego lokalnego folderu iCloud Drive. Pojawia się tylko wtedy, gdy iCloud Drive jest skonfigurowany na Twoim Macu.
- **Notes** — trzymaj notatkę obok dowolnego pliku lub folderu. Mały znacznik **●** oznacza pozycje, które ją mają; edytuj notatki w zadokowanym pasku bocznym **Notes** lub w pełnym edytorze tekstu sformatowanego (**Polecenia ▸ Edytuj notatkę…**) i przeglądaj je wszystkie za pomocą **Przegląd notatek…**.
- **Log Viewer** — otwórz plik jako pokolorowany, sklasyfikowany według poziomów, śledzony na żywo dziennik (**Plik ▸ Pokaż jako dziennik…**), z filtrami dla poszczególnych poziomów, wyszukiwaniem i obsługą typowych formatów dzienników oraz własnych formatów wyrażeń regularnych. Obsługuje wielogigabajtowe dzienniki natychmiast.
- **Markdown and HTML** — naciśnij F3 na pliku `.md` lub `.html` i czytaj go sformatowanego, a nie jako źródło, z narysowanymi diagramami ` ```mermaid ` i matematyką `$…$` złożoną na Twoim Macu. Nic nie jest pobierane i żadna część dokumentu nigdzie nie jest wysyłana.
- **CSV Lister** — naciśnij F3 na pliku `.csv` albo `.tsv` i otworzy się jako prawdziwa tabela z sortowalnymi kolumnami zamiast surowego tekstu. Separator jest wykrywany automatycznie, więc eksporty rozdzielone średnikami też się układają, a wyszukiwanie w przeglądarce znajduje wartości komórka po komórce.
- **AI Column** — dodaje kolumnę *AI Language*, która wykrywa dominujący język każdego pliku tekstowego na urządzeniu (używając frameworka NaturalLanguage firmy Apple — nie modelu w chmurze).
- **Formaty archiwów** — uczą aplikację przeglądania i wypakowywania większej liczby typów archiwów (7z, rodzina tar, gzip/bzip2/xz/zstd oraz RAR tam, gdzie zainstalowane jest narzędzie pomocnicze), które następnie otwierają się jak foldery.

## Włączanie lub wyłączanie wtyczek

1. Wybierz Konfiguracja ▸ Wtyczki…, aby otworzyć okno wtyczek.
2. Każda zainstalowana wtyczka pojawia się na liście z nazwą, typem i polem „Włączona”.
3. Zaznacz lub odznacz pole, aby włączyć lub wyłączyć wtyczkę. Zmiany wchodzą w życie od razu — włączone wtyczki dodają swoje menu, kolumny i funkcje; wyłączone trzymają się z boku.

![Okno wtyczek wymieniające zainstalowane wtyczki z polami wyboru i przyciskami Zainstaluj i Usuń](screenshots/plugins-window.png)
*(Rysunek: okno wtyczek, w którym włączasz, wyłączasz, instalujesz lub usuwasz wtyczki.)*

## Instalowanie nowej wtyczki

Pobrana wtyczka przychodzi jako **pakiet wtyczki** — plik z rozszerzeniem `.pcplug`. Są cztery sposoby, by ją zainstalować, i wszystkie kończą się tym samym potwierdzeniem:

- **Kliknij go dwukrotnie** w Finderze. Peach Commander otworzy się i zapyta.
- **Naciśnij na nim Enter** w panelu. Peach Commander to menedżer plików — plik zwykle i tak już tam jest.
- **Przeciągnij go na okno wtyczek** (Konfiguracja ▸ Wtyczki…).
- Wybierz **Konfiguracja ▸ Wtyczki… ▸ Zainstaluj…** i wskaż pakiet, `.zip` zawierający wtyczkę albo rozpakowany pakunek wtyczki.

Zanim cokolwiek zostanie wczytane, okno dialogowe podaje nazwę, wersję, identyfikator i typ wtyczki oraz to, jakie typy plików przejmie — wtyczka roszcząca sobie prawo do `.iso` staje się czytnikiem aplikacji dla tych plików. Nic nie zostanie zainstalowane, dopóki nie klikniesz **Zainstaluj**.

Jeśli wtyczka o tym samym identyfikatorze jest już zainstalowana, okno to zaznacza i pokazuje obie wersje, dzięki czemu aktualizacja czyta się jak aktualizacja („1.0.0 → 1.1.0"), a krok wstecz zostaje wyraźnie nazwany.

## Zanim zainstalujesz wtyczkę

Wtyczka to program działający wewnątrz Peach Commandera, z takim samym dostępem do Twoich plików, jaki ma Peach Commander. Nie ma wokół niej piaskownicy. Instaluj wtyczki tylko ze źródeł, którym ufasz — tak samo jak w przypadku każdej innej aplikacji.

Wtyczki pobrane z internetu trafiają do kwarantanny macOS. Zainstalowanie wtyczki mówi systemowi macOS, by zezwolił na jej wczytanie — dlatego okno potwierdzenia o tym informuje i dlatego jest to decyzja, którą podejmujesz Ty, a nie coś, co dzieje się po cichu.

## Usuwanie wtyczki

1. W oknie wtyczek zaznacz wtyczkę na liście.
2. Kliknij **Usuń**. Funkcje wbudowane pozostają nietknięte; usuwana jest tylko zaznaczona wtyczka.

Wtyczki dostarczonej z aplikacją nie da się skasować — „Usuń" wyłącza ją zamiast tego.

## Uwagi

- Lista pokazuje obok nazwy i lokalizacji także wersję, typ i wersję interfejsu każdej wtyczki, więc możesz sprawdzić, co jest zainstalowane.
- Jeśli wtyczka wymaga nowszej wersji Peach Commandera niż Twoja, zostaje odrzucona z komunikatem, który to wyjaśnia, zamiast zawieść w niezrozumiały sposób. To samo w drugą stronę: wtyczka zbudowana dla starszego interfejsu działa dalej, dopóki ten interfejs jest obsługiwany.
- Niektóre wtyczki dodają swoje kolumny, pozycje menu czy miejsca w panelu tylko wtedy, gdy są włączone. Jeśli brakuje oczekiwanej funkcji, sprawdź tutaj, czy jej wtyczka jest włączona.
- Pisanie i publikowanie własnej wtyczki opisuje dokumentacja dla programistów, a nie ta strona.
