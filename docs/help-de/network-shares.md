---
title: Netzwerkfreigaben
slug: network-shares
section: Netzwerk & Fernzugriff
order: 104
related: [ftp-and-sftp]
---

Peach Commander kann sich mit Dateiservern in Ihrem lokalen Netzwerk oder Firmennetzwerk verbinden — SMB- (Windows/Samba) und AFP-Freigaben — und deren Inhalt in einem Panel anzeigen, genau wie einen Ordner auf Ihrem eigenen Mac. Sobald eine Freigabe verbunden ist, können Sie Dateien darauf durchsuchen, kopieren, verschieben, umbenennen und öffnen, genau wie lokal, einschließlich des Kopierens zwischen der Freigabe und Ihrem anderen Panel.

## Mit einem Server verbinden

1. Klicken Sie auf das Panel, das Sie verbinden möchten (die verbundene Freigabe wird im aktiven Panel geöffnet).
2. Drücken Sie Cmd+K oder wählen Sie **Netz > Netzwerkumgebung > Netzwerkfreigabe verbinden…**.
3. Geben Sie im Dialog **Mit Server verbinden** die Serveradresse ein. Sie können eingeben:
   - eine SMB-Adresse, zum Beispiel `smb://fileserver/projects`
   - eine AFP-Adresse, zum Beispiel `afp://fileserver/projects`
   - einen Pfad im Windows-Stil, zum Beispiel `\\fileserver\projects`
   - einen einfachen `server/share`-Namen
4. Klicken Sie auf Verbinden (oder drücken Sie die Eingabetaste). Wenn der Server einen Namen und ein Passwort benötigt, zeigt macOS seine Standard-Anmeldeaufforderung an — geben Sie dort Ihre Anmeldedaten ein.
5. Sobald die Freigabe bereit ist, öffnet das aktive Panel sie automatisch. Durchsuchen und bearbeiten Sie sie wie jeden anderen Ordner.

## Verbindung trennen

Eine verbundene Freigabe erscheint als eingebundenes Volume auf Ihrem Mac. Um die Verbindung zu trennen, werfen Sie es auf die übliche macOS-Weise aus — zum Beispiel über die Finder-Seitenleiste oder über die Laufwerksliste in Peach Commander.

## Tastaturkürzel

| Aktion | Tastaturkürzel |
| --- | --- |
| Netzwerkfreigabe verbinden… | Cmd+K |

## Hinweise

- Die Authentifizierung (Benutzername, Passwort und eine etwaige Auswahl „im Schlüsselbund merken") wird über das Standard-Anmeldeblatt von macOS abgewickelt, sodass gespeicherte Serverpasswörter genauso funktionieren wie im Finder.
- Wenn Sie eine Adresse eingeben, die nicht verstanden werden kann, bittet Peach Commander Sie, eine SMB/AFP-Adresse, einen Pfad im Windows-Stil oder einen `server/share`-Namen anzugeben, und es wird nichts eingebunden.
- Nach der Bestätigung kann das Verbinden einen Moment dauern, während macOS die Freigabe einbindet; das Panel wechselt zu ihr, sobald sie verfügbar ist.
- Dies stellt eine Verbindung zu freigegebenen Laufwerken in einem Netzwerk her. Um stattdessen einen FTP-, FTPS- oder SFTP-Server zu erreichen, lesen Sie das verwandte Thema unten.
