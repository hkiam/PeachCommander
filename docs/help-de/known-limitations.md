---
title: Bekannte Einschränkungen
slug: known-limitations
section: Hilfe & Fehlerbehebung
order: 144
related: [troubleshooting]
---

Peach Commander kann viel, aber ein paar Funktionen haben in der aktuellen Version ehrliche Grenzen. Diese vorab zu kennen erspart Verwirrung, wenn sich etwas unerwartet verhält. Diese Seite listet die aktuellen Einschränkungen auf und, wo möglich, eine einfache Umgehung.

## Archive

- **Geteilte (mehrteilige) Archive können nicht geöffnet werden.** Standard-ZIP — einschließlich ZIP64, also mehr als 65.535 Einträge oder über 4 GB — sowie TAR und gzip-komprimiertes TAR öffnen sich direkt als Ordner. Ein über mehrere Dateien geteiltes Archiv (`.z01`, `.zip.001`) wird nicht unterstützt: fügen Sie die Teile zuerst zusammen oder entpacken Sie es mit dem Programm, das es erzeugt hat.
- **Verschlüsselte ZIP-Archive** (sowohl das ältere ZipCrypto als auch WinZip AES) werden zum Durchsuchen unterstützt, Sie werden jedoch nach dem Passwort gefragt.
- Andere Formate wie CPIO, ISO, CAB, LZH, XAR und PAX öffnen sich über ein Hilfswerkzeug statt über den nativen Leser.

## Netzwerk (SFTP / SCP)

- **Über SFTP lassen sich Rechte und Zeitstempel ändern, ein Eigentümer nicht.** Das Protokoll führt Eigentümer und Gruppe nur als Zahlen, und einen Benutzernamen kann man darüber nicht auflösen — ein Eigentümerwechsel wird daher abgelehnt statt geraten, ebenso wie macOS-Dateiflags, die es auf der Gegenseite nicht gibt. Über einfaches FTP lassen sich nur Rechte setzen, über den optionalen Befehl `SITE CHMOD`; ein Server, der ihn nicht anbietet, sagt das, statt Erfolg vorzutäuschen.
- Bei der ersten Verbindung zu einem SFTP-Server werden Sie gebeten, dessen Host-Schlüssel zu vertrauen. Peach Commander merkt sich diesen danach (Vertrauen bei der ersten Nutzung).

## Verzeichnisaktualisierung

- **Nur Ordner auf diesem Mac werden auf Änderungen von außen überwacht.** Ein Ordner auf diesem Mac aktualisiert sich selbst, sobald ein anderes Programm darin eine Datei anlegt, ändert oder löscht. Ein entfernter Ort (FTP oder SFTP) und das Innere eines Archivs werden nicht überwacht, weil diese Protokolle keine Möglichkeit bieten, benachrichtigt zu werden — drücken Sie dort F2 oder Ctrl+R zum erneuten Einlesen.

## Weitere aktuelle Einschränkungen

- **Einige sehr lange absolute Pfade** (tief verschachtelte Ordner, deren vollständiger Pfad ungewöhnlich lang ist) werden möglicherweise nicht zuverlässig verarbeitet. Näher am oberen Ende des Ordnerbaums zu arbeiten vermeidet dies.
- **Dieser Vorschau-Build ist nicht signiert.** macOS Gatekeeper warnt beim ersten Öffnen möglicherweise, dass die App von einem nicht verifizierten Entwickler stammt. Klicken Sie mit der rechten Maustaste auf die App und wählen Sie Öffnen, bestätigen Sie dann, um sie auszuführen. Automatische Updates sind in diesem Build noch nicht verfügbar.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Aktives Panel aktualisieren | F2 oder Ctrl+R |
| Von URL herunterladen | Cmd+Shift+U |

## Hinweise

Dies sind Einschränkungen der aktuellen Version, und es wird erwartet, dass sie sich in späteren Releases verbessern. Wenn Sie auf ein hier nicht beschriebenes Verhalten stoßen, sehen Sie im Thema zur Fehlerbehebung nach.
