---
title: Prywatność i bezpieczeństwo
slug: privacy-and-security
section: macOS i prywatność
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander jest zbudowany tak, aby nie wchodzić w drogę i trzymać Twoje dane na Twoim Macu. Hasła są przekazywane do pęku kluczy macOS, informacje o awariach nigdy nie opuszczają Twojego komputera bez Twojej zgody, a aplikacja nie zbiera żadnej analityki użycia. Ten temat wyjaśnia, gdzie żyją Twoje wrażliwe informacje i jak przyznać jedyne uprawnienie systemowe, którego menedżer plików potrzebuje do wykonywania swojej pracy.

## Gdzie przechowywane są hasła

Każde hasło lub frazę klucza, którą zapiszesz — dla połączenia FTP lub SFTP, albo do otwarcia archiwum chronionego hasłem — jest zapisywane w **pęku kluczy** macOS, tym samym bezpiecznym magazynie, którego system używa dla Twoich logowań do Wi-Fi i witryn. Hasła nigdy nie są zapisywane w ustawieniach ani plikach połączeń Peach Commandera w postaci jawnej.

1. Gdy zapisujesz hasło połączenia lub archiwum, wybierz opcję jego zapamiętania.
2. Hasło jest przechowywane w Twoim pęku kluczy logowania, chronionym przez Twoje konto.
3. Aby przejrzeć lub usunąć zapisane hasło później, otwórz aplikację **Dostęp do pęku kluczy** (w Programy ▸ Narzędzia) i wyszukaj nazwę połączenia.

## Przyznaj Pełny dostęp do dysku

macOS utrzymuje niektóre lokalizacje jako prywatne — dane Mail, Wiadomości i innych aplikacji wewnątrz Twojego folderu Biblioteka — dopóki wyraźnie nie zezwolisz na dostęp. Ponieważ menedżer plików ma dosięgać każdego pliku, Peach Commander prosi o **Pełny dostęp do dysku**. Aplikacja nadal działa z ograniczonym dostępem, dopóki go nie przyznasz; po prostu nie zobaczysz tych chronionych folderów.

1. Wybierz **Polecenia ▸ Pełny dostęp do dysku…**, lub kliknij **Otwórz Ustawienia systemowe**, gdy aplikacja zaoferuje poprowadzenie Cię przy uruchomieniu.
2. W **Ustawienia systemowe ▸ Prywatność i bezpieczeństwo ▸ Pełny dostęp do dysku** włącz przełącznik obok Peach Commandera.
3. Uruchom ponownie aplikację, jeśli zostaniesz poproszony.

## Raporty o awariach pozostają lokalne

Jeśli aplikacja nieoczekiwanie się zamknie, macOS zapisuje raport o awarii w Twoim własnym folderze diagnostyki. Przy następnym uruchomieniu Peach Commander go zauważa i oferuje pomoc w złożeniu raportu o błędzie — ale tylko za Twoją zgodą.

- Możesz **Pokaż w Finderze**, aby zobaczyć raport, lub **Skopiuj raport do schowka**, aby samodzielnie wkleić go do raportu o błędzie.
- Nic nigdy nie jest przesyłane automatycznie i nie ma zaangażowanej żadnej usługi raportowania awarii innej firmy.

## Uwagi

- **Brak telemetrii.** Peach Commander nie śledzi Twojej aktywności ani nie wysyła analityki użycia nigdzie.
- **Ograniczony dostęp jest bezpieczny.** Jeśli pominiesz Pełny dostęp do dysku, aplikacja nadal przegląda i zarządza plikami, które normalnie widzisz; ukryte są tylko lokalizacje chronione przez system.
- **Ty kontrolujesz zapisane hasła.** Ponieważ dane uwierzytelniające żyją w pęku kluczy, zarządzasz nimi i unieważniasz je standardowymi narzędziami macOS, a nie wewnątrz aplikacji.
