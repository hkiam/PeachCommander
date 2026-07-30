---
title: Atrybuty i uprawnienia
slug: attributes-and-permissions
section: Zaawansowane narzędzia
order: 96
related: [file-utilities]
---

Peach Commander pozwala sprawdzać i zmieniać niskopoziomowe metadane plików i folderów, które Finder w większości utrzymuje poza zasięgiem: uprawnienia POSIX odczytu/zapisu/wykonania, właściciela i grupę, daty modyfikacji i utworzenia, flagi macOS takie jak ukryty i zablokowany oraz atrybuty rozszerzone. Możesz też edytować listę kontroli dostępu (ACL) pliku dla szczegółowych reguł na użytkownika lub grupę, tworzyć dowiązania i aliasy wskazujące na inne elementy oraz dołączać własne komentarze. Te narzędzia są przeznaczone dla zaawansowanych użytkowników, którzy potrzebują precyzyjnej kontroli nad tym, jak elementy się zachowują i kto może ich dotykać.

## Zmień atrybuty

1. Zaznacz jeden lub więcej elementów w aktywnym panelu.
2. Wybierz **Plik > Zmień atrybuty…**.
3. Ustaw, czego potrzebujesz: przełącz pola odczytu/zapisu/wykonania dla właściciela, grupy i wszystkich (lub wpisz wartość ósemkową bezpośrednio), zmień właściciela lub grupę, przełącz flagi ukryty lub zablokowany oraz ustaw datę modyfikacji lub utworzenia. Użyj **Użyj bieżącego** dla bieżącego czasu lub skopiuj datę z innego pliku.
4. Aby zastosować tę samą zmianę w całej zawartości folderu, włącz opcję rekurencyjną i wybierz, czy dotyczy plików, folderów, czy obu.
5. Kliknij OK, aby uruchomić zmianę. Zmiany rekurencyjne działają jako zadanie w tle z paskiem postępu.

![Okno dialogowe Zmień atrybuty pokazujące siatkę uprawnień, flagi i pola dat](screenshots/attributes-dialog.png)
*(Rysunek: okno dialogowe Zmień atrybuty. Mieszane wartości w wieloplikowym zaznaczeniu pokazują się jako myślnik, dopóki ich nie ustawisz.)*

## Edytuj ACL

W przypadku reguł wykraczających poza podstawowy model właściciel/grupa/wszyscy edytuj listę kontroli dostępu elementu.

1. Otwórz **Plik > Zmień atrybuty…** i otwórz stamtąd edytor ACL.
2. Każdy wiersz to jedna reguła: użytkownik lub grupa, której dotyczy, czy zezwala, czy odmawia, oraz jakie uprawnienia (odczyt, zapis, usuwanie itd.) przyznaje.
3. Dodawaj, usuwaj lub edytuj wiersze, a następnie zapisz, aby zapisać listę z powrotem do elementu.

## Twórz dowiązania, aliasy i komentarze

- **Plik > Utwórz dowiązanie symboliczne…** tworzy dowiązanie symboliczne (symlink) wskazujące na element pod kursorem według ścieżki.
- **Plik > Utwórz dowiązanie twarde…** tworzy dowiązanie twarde do tych samych danych pliku. Dowiązania twarde działają tylko dla plików na tym samym woluminie.
- **Plik > Utwórz alias…** tworzy alias macOS, za którym Finder również może podążać.
- **Plik > Edytuj komentarz…** (Ctrl+Z) otwiera edytor tekstu dla komentarza na plik. Komentarze można wyświetlać we własnej kolumnie i w podpowiedziach stanu.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Edytuj komentarz | Ctrl+Z |

## Uwagi

- Zmiana właściciela lub grupy zazwyczaj wymaga uprawnień, których nie masz jako zwykły użytkownik; gdy to nastąpi, zmiana jest zgłaszana jako nieudana, a nie stosowana, a reszta Twoich zmian nadal przechodzi.
- Komentarze są przechowywane w pliku `descript.ion` obok Twoich elementów i mogą być również przechowywane jako komentarze Findera, w zależności od Twoich ustawień. Oba są odczytywane przy wyświetlaniu komentarza.
- Dowiązanie symboliczne i alias oba wskazują na cel, ale dowiązanie symboliczne przechowuje zwykłą ścieżkę, podczas gdy alias przechowuje odniesienie macOS, które nadal działa, jeśli cel zostanie przeniesiony lub zmieni nazwę. Dowiązanie twarde to druga nazwa tych samych danych pliku, a nie wskaźnik.
