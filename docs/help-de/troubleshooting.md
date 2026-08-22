---
title: Fehlerbehebung
slug: troubleshooting
section: Hilfe & Fehlerbehebung
order: 140
related: [privacy-and-security, known-limitations]
---

Dieses Thema behandelt die Probleme, auf die Menschen am häufigsten stoßen: macOS blockiert den Zugriff auf bestimmte Ordner, ein Ordner scheint bei alten Inhalten festzuhängen, ein sicherer FTP-Server verweigert die Verbindung und das Packen nach RAR. Jeder Abschnitt erklärt, was geschieht und wie Sie es beheben.

## macOS fragt nach Berechtigung, oder Ordner sehen leer aus

Einige Orte — etwa Ihr `~/Library`-Ordner, die Ordner anderer Benutzer und Systembereiche — sind von macOS geschützt und bleiben verborgen, bis Sie den Zugriff gewähren. Peach Commander erkennt, wenn dies geschieht, und bietet an, Sie zur richtigen Einstellung zu führen.

Ein solcher Ordner wird nicht leer angezeigt, sondern verweigert, und das Panel sagt es: *macOS hält <Ordner> privat — siehe Befehle ▸ Festplattenvollzugriff…*. Das ist es wert, benannt zu werden, denn nichts daran sieht nach einem Rechteproblem aus — der Ordner ist sichtbar, er gehört Ihnen, und seine Rechte sagen, dass Sie ihn lesen dürfen. Im Weg steht allein macOS selbst, und daran ändern auch Administratorrechte nichts. Das Panel bleibt in dem Ordner, den es schon zeigte.

1. Wählen Sie bei der Nachfrage, die Systemeinstellungen zu öffnen, oder öffnen Sie sie selbst.
2. Gehen Sie zu Datenschutz & Sicherheit und dann zu Festplattenvollzugriff.
3. Schalten Sie den Schalter neben Peach Commander ein. Falls es nicht aufgeführt ist, verwenden Sie die Schaltfläche Hinzufügen, um es hinzuzufügen.
4. Beenden Sie Peach Commander und öffnen Sie es erneut, damit die neue Berechtigung wirksam wird.

Peach Commander läuft nicht in einer eingeschränkten Sandbox, sodass es nach Erteilung des Festplattenvollzugriffs Dateien genauso durchsuchen und verwalten kann wie der Finder.

## Ein Ordner zeigt keine jüngsten Änderungen

Panels aktualisieren sich normalerweise von selbst, wenn sich Dateien auf der Festplatte ändern. Wenn ein Ordner von einem anderen Programm geändert wurde, auf einem Netzwerkvolume liegt oder schlicht veraltet aussieht, aktualisieren Sie ihn manuell.

1. Klicken Sie auf das Panel, das Sie aktualisieren möchten.
2. Drücken Sie F2 (oder Ctrl+R), um diesen Ordner erneut einzulesen.

Netzwerk- und eingebundene Volumes melden Änderungen nicht immer an macOS, sodass eine manuelle Aktualisierung dort die verlässliche Lösung ist.

## Ein FTPS-Server verbindet sich nicht

Wenn eine sichere FTP-Verbindung fehlschlägt, prüfen Sie diese Einstellungen in den Verbindungsdetails:

- Stimmen Sie den Sicherheitsmodus des Servers ab: explizites FTPS (AUTH TLS) und implizites FTPS (Port 990) sind nicht austauschbar.
- Wenn die Verbindung nach der Anmeldung stockt, wechseln Sie zwischen passivem und aktivem Übertragungsmodus — die meisten Server hinter einer Firewall benötigen passiv.
- Wenn der Server ein selbstsigniertes Zertifikat verwendet, müssen Sie es ausdrücklich zulassen; andernfalls wird die Verbindung abgelehnt.
- Bestätigen Sie Host, Port, Benutzername und Passwort sowie, ob in Ihrem Netzwerk ein SOCKS5-Proxy erforderlich ist.

## Das Packen nach RAR bewirkt nichts

Peach Commander kann ZIP-, 7z-, TAR-, TAR.GZ-, BZ2- und XZ-Archive selbst erstellen. RAR ist anders: Da RAR ein proprietäres Format ist, erfordert das Erstellen von RAR-Archiven ein separates RAR-Kommandozeilenwerkzeug, das auf Ihrem Mac installiert ist. Ohne dieses ist RAR nicht verfügbar, wenn Sie Dateien packen (Option+F5). Um vorhandene RAR-Archive zu lesen, können Sie sie weiterhin wie einen Ordner öffnen. Wenn Sie nicht speziell RAR benötigen, wählen Sie stattdessen ZIP oder 7z — beide unterstützen starke AES-256-Verschlüsselung und aufgeteilte Volumes.

## Tastenkürzel

| Aktion | Kürzel |
| --- | --- |
| Aktiven Ordner aktualisieren | F2 oder Ctrl+R |
| Mit einem FTP/FTPS-Server verbinden | Ctrl+F |
| Ein Netzwerkfreigabe einbinden | Cmd+K |
| Die ausgewählten Dateien packen | Option+F5 |

## Hinweise

- Passwörter und andere Anmeldedaten werden nur im macOS-Schlüsselbund gespeichert, niemals in einfachen Konfigurationsdateien.
- Das Einbinden einer Netzwerkfreigabe (Cmd+K oder Netz ▸ Netzwerkfreigabe einbinden…) verwendet dieselbe Verbindung, die macOS selbst nutzt, sodass sie auch im Finder erscheint.
- Wenn ein Problem nach einer Aktualisierung und einem Neustart bestehen bleibt, kann es sich um eine bekannte Einschränkung statt um einen Fehler handeln — siehe Bekannte Einschränkungen.
