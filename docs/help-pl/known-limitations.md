---
title: Znane ograniczenia
slug: known-limitations
section: Pomoc i rozwiązywanie problemów
order: 144
related: [troubleshooting]
---

Peach Commander robi wiele, ale kilka funkcji ma w bieżącej wersji szczere ograniczenia. Poznanie ich z wyprzedzeniem oszczędza zamieszania, gdy coś zachowuje się nieoczekiwanie. Ta strona wymienia bieżące ograniczenia oraz, gdzie to możliwe, proste obejście.

## Archiwa

- **Bardzo dużych plików ZIP (ZIP64) nie można otworzyć wbudowanym czytnikiem.** Standardowe archiwa ZIP, TAR i TAR skompresowane gzipem otwierają się bezpośrednio jako foldery. Archiwa ZIP64 — używane, gdy archiwum zawiera więcej niż około 65 000 elementów lub przekracza 4 GB — wykraczają poza to, co obsługuje natywny czytnik, więc mogą nie otworzyć się lub wyświetlić niekompletnie.
- **Zaszyfrowane archiwa ZIP** (zarówno starsze ZipCrypto, jak i WinZip AES) są obsługiwane do przeglądania, ale zostaniesz poproszony o hasło.
- Inne formaty, takie jak CPIO, ISO, CAB, LZH, XAR i PAX, otwierają się przez narzędzie pomocnicze, a nie natywny czytnik.

## Sieć (SFTP / SCP)

- **Zmiana atrybutów plików przez SFTP nie ma efektu w tej wersji.** Możesz przeglądać, pobierać i wysyłać przez SFTP/SCP, ale żądania zmiany uprawnień, własności lub znaczników czasu na serwerze zdalnym są po cichu ignorowane. Wprowadź te zmiany na samym serwerze lub przez inny protokół.
- Przy pierwszym połączeniu z serwerem SFTP zostaniesz poproszony o zaufanie jego kluczowi hosta. Peach Commander zapamiętuje go później (zaufanie przy pierwszym użyciu).

## Pobieranie z adresu URL

- Polecenie **Pobierz z adresu URL** (menu Sieć) używa obecnie skrótu Cmd+Shift+D, który jest tym samym skrótem co Przejdź > Biurko. Gdy oba są dostępne, menu mogą kolidować — dla pewności uruchom pobieranie bezpośrednio z menu Sieć.

## Odświeżanie folderów

- **Panel zauważa zmiany zewnętrzne z krótkim opóźnieniem, nie natychmiast.** Peach Commander sprawdza bieżący folder pod kątem zmian mniej więcej co 2 sekundy, więc plik dodany lub usunięty przez inną aplikację może chwilę się pojawiać. Jeśli nie chcesz czekać, odśwież aktywny panel ręcznie klawiszem F2 lub Ctrl+R.

## Inne bieżące ograniczenia

- **Niektóre bardzo długie ścieżki bezwzględne** (głęboko zagnieżdżone foldery, których pełna ścieżka jest niezwykle długa) mogą nie być obsługiwane niezawodnie. Praca bliżej szczytu drzewa folderów pozwala tego uniknąć.
- **Ta wersja podglądowa nie jest podpisana.** Gatekeeper w macOS może ostrzec, że aplikacja pochodzi od niezidentyfikowanego dewelopera przy pierwszym otwarciu. Kliknij aplikację prawym przyciskiem i wybierz Otwórz, a następnie potwierdź, aby ją uruchomić. Automatyczne aktualizacje nie są jeszcze dostępne w tej wersji.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Odśwież aktywny panel | F2 lub Ctrl+R |
| Pobierz z adresu URL | Cmd+Shift+D |

## Uwagi

To są ograniczenia bieżącej wersji i oczekuje się, że poprawią się w późniejszych wydaniach. Jeśli napotkasz zachowanie nieopisane tutaj, zobacz temat rozwiązywania problemów.
