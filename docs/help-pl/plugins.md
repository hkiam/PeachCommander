---
title: Wtyczki
slug: plugins
section: Wtyczki
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, archives, ftp-and-sftp]
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
- **[Uninstaller](uninstaller.md)** — usuwa aplikację **oraz** pliki pomocnicze, pamięci podręczne i preferencje, które po sobie zostawia, po pokazaniu Ci dokładnie, co zniknie.

Pozostałe wbudowane wtyczki są mniejsze i nie potrzebują własnej strony:

- **WebDAV** — połącz się z serwerem WebDAV (**Sieć ▸ Połącz z WebDAV…**) i przeglądaj, wysyłaj, pobieraj, zmieniaj nazwy oraz usuwaj na nim tak, jakby był folderem. Hasła są przechowywane w pęku kluczy macOS.
- **iCloud Drive** — dodaje pozycję *iCloud Drive* do paska dysków, która przechodzi prosto do Twojego lokalnego folderu iCloud Drive. Pojawia się tylko wtedy, gdy iCloud Drive jest skonfigurowany na Twoim Macu.
- **Notes** — trzymaj notatkę obok dowolnego pliku lub folderu. Mały znacznik **●** oznacza pozycje, które ją mają; edytuj notatki w zadokowanym pasku bocznym **Notes** lub w pełnym edytorze tekstu sformatowanego (**Polecenia ▸ Edytuj notatkę…**) i przeglądaj je wszystkie za pomocą **Przegląd notatek…**.
- **Log Viewer** — otwórz plik jako pokolorowany, sklasyfikowany według poziomów, śledzony na żywo dziennik (**Plik ▸ Pokaż jako dziennik…**), z filtrami dla poszczególnych poziomów, wyszukiwaniem i obsługą typowych formatów dzienników oraz własnych formatów wyrażeń regularnych. Obsługuje wielogigabajtowe dzienniki natychmiast.
- **CSV Lister** — naciśnij F3 na pliku `.csv` albo `.tsv` i otworzy się jako prawdziwa tabela z sortowalnymi kolumnami zamiast surowego tekstu. Separator jest wykrywany automatycznie, więc eksporty rozdzielone średnikami też się układają, a wyszukiwanie w przeglądarce znajduje wartości komórka po komórce.
- **AI Column** — dodaje kolumnę *AI Language*, która wykrywa dominujący język każdego pliku tekstowego na urządzeniu (używając frameworka NaturalLanguage firmy Apple — nie modelu w chmurze).
- **Formaty archiwów** — uczą aplikację przeglądania i wypakowywania większej liczby typów archiwów (7z, rodzina tar, gzip/bzip2/xz/zstd oraz RAR tam, gdzie zainstalowane jest narzędzie pomocnicze), które następnie otwierają się jak foldery.

## Włączanie lub wyłączanie wtyczek

1. Wybierz Konfiguracja ▸ Wtyczki…, aby otworzyć okno wtyczek.
2. Każda zainstalowana wtyczka pojawia się na liście z nazwą, typem i polem „Włączona”.
3. Zaznacz lub odznacz pole, aby włączyć lub wyłączyć wtyczkę. Zmiany wchodzą w życie od razu — włączone wtyczki dodają swoje menu, kolumny i funkcje; wyłączone trzymają się z boku.

![Okno wtyczek wymieniające zainstalowane wtyczki z polami wyboru i przyciskami Zainstaluj i Usuń](screenshots/plugins-window.png)
*(Rysunek: okno wtyczek, w którym włączasz, wyłączasz, instalujesz lub usuwasz wtyczki.)*

## Zainstaluj nową wtyczkę

1. Wybierz Konfiguracja ▸ Wtyczki….
2. Kliknij **Zainstaluj z folderu…**.
3. Wybierz pakiet wtyczki lub `.zip`, który go zawiera, i potwierdź. Wtyczka zostaje dodana do listy i włączona.

## Usuń wtyczkę

1. W oknie wtyczek oznacz wtyczkę na liście.
2. Kliknij **Usuń**. Funkcje wbudowane nie są naruszone; usuwana jest tylko wybrana wtyczka.

## Uwagi

- Lista wtyczek pokazuje typ i wersję interfejsu każdej wtyczki obok nazwy i lokalizacji, więc możesz potwierdzić, co jest zainstalowane.
- Jeśli żadna wtyczka nie jest zainstalowana, okno pokazuje krótką zachętę kierującą Cię do **Zainstaluj z folderu…**.
- Niektóre wtyczki dodają własne kolumny, pozycje menu lub miejsca panelu tylko wtedy, gdy są włączone. Jeśli oczekiwana funkcja jest nieobecna, sprawdź, czy wtyczka jest tutaj włączona.
