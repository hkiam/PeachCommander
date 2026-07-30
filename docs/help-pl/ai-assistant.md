---
title: Asystent AI
slug: ai-assistant
section: Wtyczki
order: 122
related: [plugins, settings, privacy-and-security]
---

Asystent AI to opcjonalna, usuwalna wtyczka, która pomaga pracować z plikami w języku naturalnym. Potrafi podsumować lub wyjaśnić dokument, zaproponować lepszą nazwę pliku, przetłumaczyć lub sprawdzić tekst, zamienić dane w tabelę, a nawet uporządkować folder — i może wykonać za Ciebie operacje na plikach po uprzednim pokazaniu planu. Działa na urządzeniu z Apple Intelligence, gdy jest dostępne, lub możesz skierować go na model w chmurze. Ponieważ jest to wtyczka, możesz ją wyłączyć lub całkowicie usunąć w **Konfiguracja ▸ Wtyczki…**.

## Otwarcie asystenta

Wybierz **Polecenia ▸ Asystent AI**, aby wyświetlić asystenta w zadokowanym panelu po prawej stronie okna. Wpisz zapytanie i naciśnij Enter; asystent może czytać pliki, wyszukiwać informacje i — za Twoim potwierdzeniem — wprowadzać zmiany.

![Czat asystenta AI zadokowany obok paneli plików](screenshots/ai-chat.png)
*(Rysunek: asystent AI, zadokowany po prawej, pracuje nad zapytaniem.)*

## Akcje prawego przycisku (AI ▸)

Najszybszym sposobem korzystania z asystenta jest podmenu **AI ▸** w menu prawego przycisku:

- **Na pliku** — Podsumuj, Wyjaśnij, Zaproponuj nazwę, Przetłumacz na angielski, Sprawdź, Wykryj zadania i Utwórz tabelę.
- **Na tle panelu** — Uporządkuj ten folder i Znajdź prawdopodobne duplikaty.

Każda akcja **AI ▸** otwiera **własny zatytułowany czat** (na przykład *Podsumuj – raport.txt*), dzięki czemu różne zadania pozostają oddzielone, zamiast piętrzyć się w jednej długiej rozmowie. Gdy sam wpisujesz coś w polu wejściowym, to zapytanie kontynuuje bieżący czat.

## Zarządzanie czatami

- Użyj przełącznika czatów u góry panelu, aby przechodzić między rozmowami.
- Menu **Usuń ▾** oferuje **Usuń ten czat** i **Usuń wszystkie czaty**, dzięki czemu możesz wyczyścić wszystko naraz, gdy lista się wydłuży. Puste czaty są automatycznie usuwane po zamknięciu panelu.

## Zmiany są najpierw potwierdzane

W przypadku wszystkiego, co modyfikuje pliki — przenoszenia, zmiany nazwy, zapisu, usuwania — asystent pokazuje **plan i czeka na Twoje potwierdzenie** przed działaniem. Możesz to zmienić w Ustawieniach, zwiększając autonomię asystenta, lub obniżyć ją do tylko do odczytu, aby nigdy niczego nie zmieniał.

## Ustawienia

Otwórz **Konfiguracja ▸ Ustawienia ▸ AI**, aby skonfigurować asystenta na jednej stronie:

- **Preferowany model** — Automatyczny (chmura, jeśli skonfigurowana, w przeciwnym razie na urządzeniu), Na urządzeniu (Apple Intelligence) lub Chmura.
- **Punkt końcowy chmury, model i klucz API** — aby użyć modelu zgodnego z OpenAI zamiast tego na urządzeniu. Klucz jest przechowywany w pęku kluczy macOS, nigdy w plikach konfiguracji.
- **Autonomia asystenta** — tylko do odczytu, potwierdzaj zmiany (domyślnie) lub autonomiczny.
- **Niestandardowy monit systemowy** — opcjonalne instrukcje kształtujące odpowiedzi asystenta.
- **Serwer MCP** — opcjonalny, tylko lokalny serwer, który pozwala zewnętrznemu agentowi sterować aplikacją; domyślnie wyłączony i chroniony tokenem.

![Strona AI w Ustawieniach z opcjami autonomii i serwera MCP](screenshots/settings-ai.png)
*(Rysunek: wszystkie opcje asystenta znajdują się na jednej stronie AI w Ustawieniach.)*

## Prywatność

- Z Apple Intelligence asystent działa **na Twoim Macu**; nic nie opuszcza urządzenia.
- Model w chmurze jest używany **tylko wtedy, gdy go skonfigurujesz**, a jego klucz API jest przechowywany w pęku kluczy.
- Operacje zmieniające pliki są potwierdzane przed wykonaniem, chyba że celowo podniesiesz poziom autonomii.
