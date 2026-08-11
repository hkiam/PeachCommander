---
title: Bekannte Einschränkungen
slug: known-limitations
section: Hilfe & Fehlerbehebung
order: 144
related: [troubleshooting]
---

Peach Commander kann viel, aber ein paar Funktionen haben in der aktuellen Version ehrliche Grenzen. Diese vorab zu kennen erspart Verwirrung, wenn sich etwas unerwartet verhält. Diese Seite listet die aktuellen Einschränkungen auf und, wo möglich, eine einfache Umgehung.

## Archive

- **Geteilte (mehrteilige) ZIP-Archive lassen sich öffnen, aber alle Teile müssen vorhanden sein.** Standard-ZIP — einschließlich ZIP64, also mehr als 65.535 Einträge oder über 4 GB — sowie TAR und gzip-komprimiertes TAR öffnen sich direkt als Ordner. Ein über mehrere Dateien geteiltes Archiv öffnet sich ebenfalls: Drücken Sie Enter auf der `.zip`-Datei eines Satzes aus `.z01`, `.z02`, … oder auf der `.001`-Datei eines Satzes `name.zip.001`. Alle Teile müssen im selben Ordner liegen; fehlt einer, wird der Satz abgelehnt, statt halb gelesen geöffnet zu werden. Geteilte TAR-Archive sind nicht abgedeckt.
- **Verschlüsselte ZIP-Archive** (sowohl das ältere ZipCrypto als auch WinZip AES) werden zum Durchsuchen unterstützt, Sie werden jedoch nach dem Passwort gefragt.
- Andere Formate wie CPIO, ISO, CAB, LZH, XAR und PAX öffnen sich über ein Hilfswerkzeug statt über den nativen Leser.

## Netzwerk (SFTP / SCP)

- **Über SFTP lassen sich Rechte und Zeitstempel ändern, ein Eigentümer nicht.** Das Protokoll führt Eigentümer und Gruppe nur als Zahlen, und einen Benutzernamen kann man darüber nicht auflösen — ein Eigentümerwechsel wird daher abgelehnt statt geraten, ebenso wie macOS-Dateiflags, die es auf der Gegenseite nicht gibt. Über einfaches FTP lassen sich nur Rechte setzen, über den optionalen Befehl `SITE CHMOD`; ein Server, der ihn nicht anbietet, sagt das, statt Erfolg vorzutäuschen.
- Bei der ersten Verbindung zu einem SFTP-Server werden Sie gebeten, dessen Host-Schlüssel zu vertrauen. Peach Commander merkt sich diesen danach (Vertrauen bei der ersten Nutzung).

## Verzeichnisaktualisierung

- **Entfernte Orte werden nicht überwacht; ein geöffnetes Archiv jetzt schon.** Ein Ordner auf diesem Mac aktualisiert sich selbst, sobald ein anderes Programm darin eine Datei anlegt, ändert oder löscht — und ebenso ein Archiv, in das Sie hineinsehen: die `.zip` ist eine lokale Datei, wird sie überschrieben, liest das Panel sie neu. Ein entfernter Ort (FTP oder SFTP) wird nicht überwacht, weil diese Protokolle keine Möglichkeit bieten, benachrichtigt zu werden — drücken Sie F2 oder Ctrl+R.

## Weitere aktuelle Einschränkungen

- **Sehr lange Pfade funktionieren, außer beim Papierkorb.** macOS weist jeden Pfad über 1024 Byte als Aufrufargument zurück, und so tief verschachtelte Ordner kommen vor. Ansehen, Öffnen, Kopieren, Verschieben, Umbenennen, Anlegen und endgültiges Löschen erreichen sie alle. Die einzige Ausnahme ist **In den Papierkorb legen**: macOS bietet keinen Weg, eine Datei wegzuwerfen, die es nicht benennen kann — dort meldet Entf einen Fehler, Umschalt+Entf (endgültig löschen) funktioniert.
- **Dieser Vorschau-Build ist nicht signiert.** Gatekeeper blockiert den ersten Start, und wie Sie ihn erlauben, hängt von Ihrer macOS-Version ab. Unter **macOS 15 Sequoia und neuer**: einmal doppelklicken, die Warnung schließen, dann in **Systemeinstellungen ▸ Datenschutz & Sicherheit** auf **Dennoch öffnen** klicken — Apple hat die Abkürzung über die rechte Maustaste für nicht signierte Software in macOS 15 entfernt, ein Rechtsklick hilft dort also nicht mehr. Unter **macOS 13–14**: mit der rechten Maustaste auf die App klicken, Öffnen wählen und bestätigen. Automatische Updates sind in diesem Build noch nicht verfügbar.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Aktives Panel aktualisieren | F2 oder Ctrl+R |
| Von URL herunterladen | Cmd+Shift+U |

## Hinweise

Dies sind Einschränkungen der aktuellen Version, und es wird erwartet, dass sie sich in späteren Releases verbessern. Wenn Sie auf ein hier nicht beschriebenes Verhalten stoßen, sehen Sie im Thema zur Fehlerbehebung nach.
