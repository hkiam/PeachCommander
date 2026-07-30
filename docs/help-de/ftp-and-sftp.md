---
title: Verbindung mit FTP & SFTP
slug: ftp-and-sftp
section: Netzwerk & Fernzugriff
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander kann entfernte Server durchsuchen, als wären sie gewöhnliche Ordner. Sobald die Verbindung besteht, zeigt ein Panel die entfernten Dateien, und Sie kopieren, verschieben, benennen um und löschen sie mit denselben Tasten, die Sie lokal verwenden. Es beherrscht einfaches FTP, sicheres FTPS und SFTP/SCP über SSH, sodass Sie alles von einem klassischen Webhost bis zu einem gehärteten SSH-Server erreichen können. Gesicherte Verbindungen leben im Verbindungsmanager, und Passwörter werden sicher in Ihrem macOS-Schlüsselbund aufbewahrt statt in der Verbindung selbst.

## Mit einem Server verbinden

1. Öffnen Sie das Menü **Netz** und wählen Sie **FTP-Verbindung…** (Ctrl+F), um den Verbindungsmanager zu öffnen.
2. Wählen Sie eine gesicherte Verbindung aus der Liste und klicken Sie auf **Verbinden**, oder klicken Sie auf **Neu**, um eine zu erstellen. Verwenden Sie Ordner in der Liste, um Verbindungen zu gruppieren.
3. Für eine schnelle einmalige Verbindung wählen Sie **Netz ▸ Neue FTP-Verbindung…** (Ctrl+N) und tippen Sie die Adresse direkt ein.
4. Geben Sie Ihr Passwort ein, wenn Sie dazu aufgefordert werden; aktivieren Sie die Option, es zu sichern, und es gelangt für das nächste Mal in Ihren Schlüsselbund.
5. Wenn Sie fertig sind, wählen Sie **Netz ▸ FTP trennen** (Ctrl+Shift+F).

![Der FTP-Verbindungsmanager mit der Liste gesicherter Sitzungen und den Schaltflächen Neu, Bearbeiten und Löschen](screenshots/ftp-connection-manager.png)
*(Abbildung: Der Verbindungsmanager enthält Ihre gesicherten Server; verwenden Sie Neu, Bearbeiten und Löschen, um sie zu verwalten.)*

Wenn Sie eine Verbindung einrichten, können Sie das Protokoll wählen (FTP, FTPS mit explizitem AUTH TLS, implizites FTPS auf Port 990 oder SFTP/SCP), den passiven oder aktiven Modus, den entfernten und lokalen Startordner, die Textkodierung und ein optionales Keep-Alive-Intervall, um zu verhindern, dass Sie von untätigen Servern getrennt werden. Für SFTP können Sie sich mit Ihrem SSH-Agenten, einem Passwort oder einer privaten Schlüsseldatei authentifizieren, und Sie können SCP für Übertragungen wählen. Unbekannten SSH-Hostschlüsseln wird bei der ersten Verwendung vertraut; wenn sich der Schlüssel eines bekannten Servers jemals ändert, wird die Verbindung verweigert, um Sie vor Manipulation zu schützen.

## Die FTP-Konsole

Um genau zu sehen, was der Server sagt, öffnen Sie die FTP-Konsole aus dem Menü **Netz**. Sie zeigt ein Live-Protokoll des Steuerkanals (Ihr Passwort ist maskiert) und lässt Sie rohe FTP-Befehle an den Server tippen.

![Die FTP-Konsole mit dem Protokoll des Steuerkanals und einem Feld für rohe Befehle](screenshots/ftp-console.png)
*(Abbildung: Die FTP-Konsole protokolliert jeden Austausch und akzeptiert rohe Befehle, was bei der Fehlersuche praktisch ist.)*

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Verbindungsmanager öffnen | Ctrl+F |
| Neue Verbindung | Ctrl+N |
| Trennen | Ctrl+Shift+F |
| Übertragungsmodus ändern | Ctrl+Shift+M |

## Hinweise

- Unterbrochene Downloads und Uploads können dort fortgesetzt werden, wo sie aufgehört haben, statt von vorne zu beginnen.
- Aktivieren Sie für FTPS-Server mit einem selbstsignierten Zertifikat in den Einstellungen dieser Verbindung die Option, ein nicht vertrauenswürdiges Zertifikat zu akzeptieren.
- Ein SOCKS5-Proxy kann pro Verbindung für einfaches FTP festgelegt werden. Das Leiten einer verschlüsselten FTPS-Verbindung durch einen Proxy wird nicht unterstützt.
- Bestehende FTP-Verbindungen aus Total Commander können importiert werden.
- SCP wird nur zum Übertragen von Dateien verwendet; Auflisten, Umbenennen und Löschen laufen immer über SFTP.
