---
title: Łączenie z FTP i SFTP
slug: ftp-and-sftp
section: Sieć i dostęp zdalny
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander może przeglądać serwery zdalne tak, jakby były zwykłymi folderami. Po połączeniu jeden panel pokazuje pliki zdalne, a Ty kopiujesz, przenosisz, zmieniasz nazwy i usuwasz je tymi samymi klawiszami, których używasz lokalnie. Mówi zwykłym FTP, bezpiecznym FTPS i SFTP/SCP przez SSH, więc możesz dotrzeć do wszystkiego, od klasycznego hostingu WWW po utwardzony serwer SSH. Zapisane połączenia żyją w menedżerze połączeń, a hasła są bezpiecznie przechowywane w pęku kluczy macOS, a nie w samym połączeniu.

## Połącz się z serwerem

1. Otwórz menu **Sieć** i wybierz **Połączenie FTP…** (Ctrl+F), aby otworzyć menedżera połączeń.
2. Wybierz zapisane połączenie z listy i kliknij **Połącz**, lub kliknij **Nowe**, aby utworzyć jedno. Użyj folderów na liście, aby grupować połączenia.
3. Dla szybkiego jednorazowego połączenia wybierz **Sieć > Nowe połączenie FTP…** (Ctrl+N) i wpisz adres bezpośrednio.
4. Wprowadź hasło, gdy zostaniesz o to poproszony; zaznacz opcję jego zapisania, a trafi do Twojego pęku kluczy na następny raz.
5. Gdy skończysz, wybierz **Sieć > Rozłącz FTP** (Ctrl+Shift+F).

![Menedżer połączeń FTP pokazujący listę zapisanych sesji z przyciskami Nowe, Edytuj i Usuń](screenshots/ftp-connection-manager.png)
*(Rysunek: menedżer połączeń przechowuje Twoje zapisane serwery; użyj Nowe, Edytuj i Usuń, aby nimi zarządzać.)*

Podczas konfigurowania połączenia możesz wybrać protokół (FTP, FTPS z jawnym AUTH TLS, niejawny FTPS na porcie 990 lub SFTP/SCP), tryb pasywny lub aktywny, zdalny i lokalny folder początkowy, kodowanie tekstu oraz opcjonalny interwał keep-alive, aby powstrzymać bezczynne serwery przed rozłączeniem. W przypadku SFTP możesz uwierzytelnić się swoim agentem SSH, hasłem lub plikiem klucza prywatnego, a do transferów możesz wybrać SCP. Nieznane klucze hosta SSH są uznawane za zaufane przy pierwszym użyciu; jeśli klucz znanego serwera kiedykolwiek się zmieni, połączenie jest odrzucane, aby chronić Cię przed manipulacją.

## Konsola FTP

Aby zobaczyć dokładnie, co mówi serwer, otwórz konsolę FTP z menu **Sieć**. Pokazuje ona dziennik na żywo kanału kontrolnego (Twoje hasło jest zamaskowane) i pozwala wpisywać serwerowi surowe polecenia FTP.

![Konsola FTP pokazująca dziennik kanału kontrolnego i pole na surowe polecenia](screenshots/ftp-console.png)
*(Rysunek: konsola FTP rejestruje każdą wymianę i przyjmuje surowe polecenia, co jest przydatne przy rozwiązywaniu problemów.)*

## Skróty

| Akcja | Skrót |
| --- | --- |
| Otwórz menedżera połączeń | Ctrl+F |
| Nowe połączenie | Ctrl+N |
| Rozłącz | Ctrl+Shift+F |
| Zmień tryb transferu | Ctrl+Shift+M |

## Uwagi

- Przerwane pobieranie jest kontynuowane tam, gdzie się zatrzymało: jeśli plik jest już częściowo na miejscu, a serwer zgadza się na restart, przesyłana jest tylko brakująca końcówka. Serwer, który odmówi, po prostu zaczyna plik od nowa. Wysyłanie nie jest jeszcze wznawiane.
- W przypadku serwerów FTPS z certyfikatem z podpisem własnym włącz opcję akceptacji niezaufanego certyfikatu w ustawieniach tego połączenia.
- Serwer proxy SOCKS5 można ustawić dla każdego połączenia w przypadku zwykłego FTP. Kierowanie zaszyfrowanego połączenia FTPS przez serwer proxy nie jest obsługiwane.
- Istniejące połączenia FTP z Total Commandera można zaimportować.
- SCP jest używany tylko do transferu plików; wyświetlanie, zmiana nazwy i usuwanie zawsze przechodzą przez SFTP.
