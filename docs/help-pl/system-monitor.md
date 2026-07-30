---
title: System Monitor
slug: system-monitor
section: Wtyczki
order: 124
related: [plugins, settings]
---

Wtyczka System Monitor umieszcza podgląd aktywności Twojego Maca w czasie rzeczywistym bezpośrednio na pasku tytułu okna: małe wskaźniki dla procesora, pamięci, dysku, sieci oraz — tam, gdzie sprzęt je udostępnia — GPU, baterii i czujników. Każdy wskaźnik aktualizuje się raz na sekundę; kliknij go, aby otworzyć okienko z wykresem historii i szczegółowym rozbiciem. Jest to wtyczka, więc możesz ją włączyć, skonfigurować lub usunąć w **Konfiguracja ▸ Wtyczki…**.

## Wskaźniki na pasku tytułu

Gdy wtyczka jest włączona, na pasku tytułu znajduje się rząd kompaktowych wskaźników. Każdy wskaźnik to kolorowa kropka, krótka etykieta i wartość na żywo (niektóre z wbudowanym wykresem iskrowym):

| Wskaźnik | Pokazuje |
| --- | --- |
| **CPU** | Obciążenie procesora, ze szczegółami dla każdego rdzenia |
| **RAM** | Pamięć użyta / całkowita (plus zablokowana, skompresowana, swap) |
| **HDD** | Miejsce na woluminie startowym oraz przepustowość odczytu/zapisu |
| **Net** | Prędkości i sumy pobierania / wysyłania |
| **GPU** · **Batt** · **Sens** | Wykorzystanie GPU · poziom i stan naładowania baterii · prędkości wentylatorów i temperatury |

Kliknij wskaźnik, aby otworzyć okienko z dużą bieżącą wartością, wykresem iskrowym **HISTORIA**, listą klucz/wartość **SZCZEGÓŁY** oraz — dla procesora — listą **OBCIĄŻENIE RDZENI** z paskami dla każdego rdzenia.

## Skonfiguruj

Wybierz **Polecenia ▸ System Monitor…** (lub otwórz **Konfiguracja ▸ Ustawienia ▸ System Monitor**), aby skonfigurować podgląd:

- **Pokaż monitor systemu na pasku tytułu** — główny wyłącznik wskaźników.
- **Profil** — ustawienia gotowe *Minimalny*, *Średni* lub *Maksymalny*, które wybierają sensowny zestaw modułów.
- **Tabela modułów** — włącz lub wyłącz każdy moduł (CPU, GPU, RAM, HDD, Net, Batt, Sens), wybierz jego kolor i przeciągnij wiersze, aby ustawić kolejność ich pojawiania się na pasku tytułu. Moduły, których Twój sprzęt nie może raportować, są pokazywane jako *(n/d)*.

![Ustawienia System Monitor z tabelą modułów, profilami i kolorami dla poszczególnych modułów](screenshots/system-monitor.png)
*(Rysunek: wybierz, które moduły się pojawiają, ich kolory i kolejność.)*

## Uwagi

- Wszystko jest mierzone, nigdy nie fałszowane: moduły, których danych sprzęt nie udostępnia (często GPU lub czujniki na niektórych Macach), pozostają niedostępne, zamiast pokazywać zmyślone liczby. Bateria jest niedostępna na komputerach stacjonarnych.
- Próbkowanie działa na timerze w tle tylko wtedy, gdy podgląd jest widoczny, i przechowuje około 30 minut historii dla wykresów.
- Twój wybór modułów, kolory i kolejność są zapisywane wraz z konfiguracją aplikacji.
