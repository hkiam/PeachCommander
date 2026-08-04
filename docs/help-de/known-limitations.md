---
title: Bekannte Einschränkungen
slug: known-limitations
section: Hilfe & Fehlerbehebung
order: 144
related: [troubleshooting]
---

Peach Commander kann viel, aber ein paar Funktionen haben in der aktuellen Version ehrliche Grenzen. Diese vorab zu kennen erspart Verwirrung, wenn sich etwas unerwartet verhält. Diese Seite listet die aktuellen Einschränkungen auf und, wo möglich, eine einfache Umgehung.

## Archive

- **Sehr große ZIP-Dateien (ZIP64) können vom integrierten Leser nicht geöffnet werden.** Standard-ZIP-, TAR- und mit gzip komprimierte TAR-Archive öffnen sich direkt wie Ordner. ZIP64-Archive — verwendet, wenn ein Archiv mehr als etwa 65.000 Elemente enthält oder 4 GB überschreitet — liegen außerhalb dessen, was der native Leser verarbeitet, sodass sie sich möglicherweise nicht öffnen lassen oder unvollständig aufgelistet werden.
- **Verschlüsselte ZIP-Archive** (sowohl das ältere ZipCrypto als auch WinZip AES) werden zum Durchsuchen unterstützt, Sie werden jedoch nach dem Passwort gefragt.
- Andere Formate wie CPIO, ISO, CAB, LZH, XAR und PAX öffnen sich über ein Hilfswerkzeug statt über den nativen Leser.

## Netzwerk (SFTP / SCP)

- **Das Ändern von Dateiattributen über SFTP hat in dieser Version keine Wirkung.** Sie können über SFTP/SCP durchsuchen, herunterladen und hochladen, aber Anfragen zum Ändern von Berechtigungen, Eigentümerschaft oder Zeitstempeln auf einem entfernten Server werden stillschweigend ignoriert. Nehmen Sie diese Änderungen auf dem Server selbst oder über ein anderes Protokoll vor.
- Bei der ersten Verbindung zu einem SFTP-Server werden Sie gebeten, dessen Host-Schlüssel zu vertrauen. Peach Commander merkt sich diesen danach (Vertrauen bei der ersten Nutzung).

## Herunterladen von einer URL

- Der Befehl **Von URL herunterladen** (Menü Netz) verwendet derzeit den Kurzbefehl Cmd+Shift+D, was derselbe Kurzbefehl wie Gehe zu > Schreibtisch ist. Wenn beide verfügbar sind, können die Menüs in Konflikt geraten — starten Sie den Download zur Sicherheit direkt über das Menü Netz.

## Verzeichnisaktualisierung

- **Nur Ordner auf diesem Mac werden auf Änderungen von außen überwacht.** Ein Ordner auf diesem Mac aktualisiert sich selbst, sobald ein anderes Programm darin eine Datei anlegt, ändert oder löscht. Ein entfernter Ort (FTP oder SFTP) und das Innere eines Archivs werden nicht überwacht, weil diese Protokolle keine Möglichkeit bieten, benachrichtigt zu werden — drücken Sie dort F2 oder Ctrl+R zum erneuten Einlesen.

## Weitere aktuelle Einschränkungen

- **Einige sehr lange absolute Pfade** (tief verschachtelte Ordner, deren vollständiger Pfad ungewöhnlich lang ist) werden möglicherweise nicht zuverlässig verarbeitet. Näher am oberen Ende des Ordnerbaums zu arbeiten vermeidet dies.
- **Dieser Vorschau-Build ist nicht signiert.** macOS Gatekeeper warnt beim ersten Öffnen möglicherweise, dass die App von einem nicht verifizierten Entwickler stammt. Klicken Sie mit der rechten Maustaste auf die App und wählen Sie Öffnen, bestätigen Sie dann, um sie auszuführen. Automatische Updates sind in diesem Build noch nicht verfügbar.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Aktives Panel aktualisieren | F2 oder Ctrl+R |
| Von URL herunterladen | Cmd+Shift+D |

## Hinweise

Dies sind Einschränkungen der aktuellen Version, und es wird erwartet, dass sie sich in späteren Releases verbessern. Wenn Sie auf ein hier nicht beschriebenes Verhalten stoßen, sehen Sie im Thema zur Fehlerbehebung nach.
