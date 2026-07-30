---
title: Udziały sieciowe
slug: network-shares
section: Sieć i dostęp zdalny
order: 104
related: [ftp-and-sftp]
---

Peach Commander może łączyć się z serwerami plików w Twojej sieci lokalnej lub firmowej — udziałami SMB (Windows/Samba) i AFP — i wyświetlać ich zawartość w panelu tak jak folder na Twoim własnym Macu. Po połączeniu udziału możesz w nim przeglądać, kopiować, przenosić, zmieniać nazwy i otwierać pliki dokładnie tak jak lokalnie, w tym kopiować między udziałem a drugim panelem.

## Połącz się z serwerem

1. Kliknij panel, z którym chcesz się połączyć (połączony udział otwiera się w aktywnym panelu).
2. Naciśnij Cmd+K lub wybierz **Sieć > Otoczenie sieciowe > Połącz udział sieciowy…**.
3. W oknie dialogowym **Połącz z serwerem** wpisz adres serwera. Możesz podać:
   - adres SMB, na przykład `smb://fileserver/projects`
   - adres AFP, na przykład `afp://fileserver/projects`
   - ścieżkę w stylu Windows, na przykład `\\fileserver\projects`
   - prostą nazwę `serwer/udział`
4. Kliknij Połącz (lub naciśnij Enter). Jeśli serwer wymaga nazwy i hasła, macOS pokazuje swoje zwykłe okno logowania — wprowadź tam swoje dane.
5. Gdy udział jest gotowy, aktywny panel otwiera go automatycznie. Przeglądaj i pracuj z nim jak z każdym innym folderem.

## Rozłącz

Połączony udział pojawia się jako zamontowany wolumin na Twoim Macu. Aby go rozłączyć, wysuń go w zwykły sposób macOS — na przykład z paska bocznego Findera lub z listy urządzeń w Peach Commanderze.

## Skróty

| Akcja | Skrót |
| --- | --- |
| Połącz udział sieciowy… | Cmd+K |

## Uwagi

- Uwierzytelnianie (nazwa użytkownika, hasło i ewentualna opcja „zapamiętaj w moim pęku kluczy”) jest obsługiwane przez zwykłe okno logowania macOS, więc zapisane hasła serwerów działają jak w Finderze.
- Jeśli podasz adres, którego nie da się przeanalizować, Peach Commander prosi o adres SMB/AFP, ścieżkę w stylu Windows lub nazwę `serwer/udział`, a nic nie zostaje zamontowane.
- Po potwierdzeniu połączenie może chwilę potrwać, podczas gdy macOS montuje udział; panel przełącza się na niego, gdy tylko stanie się dostępny.
- To łączy z urządzeniami udostępnionymi w sieci. Aby zamiast tego dotrzeć do serwera FTP, FTPS lub SFTP, zobacz powiązany temat poniżej.
