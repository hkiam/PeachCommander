---
title: Einstellungen
slug: settings
section: Anpassen
order: 116
related: [appearance, keyboard-shortcuts]
---

Im Einstellungsfenster passen Sie Peach Commander an Ihre Arbeitsweise an: welche Leisten erscheinen, wie Dateien angezeigt werden, wie sich Kopier- und Löschvorgänge verhalten, welches Archivformat beim Packen verwendet wird, das Verhalten der Tabs, die FTP-Standardwerte, die Anzeigesprache und mehr. Die Einstellungen sind in Seiten gruppiert, damit Sie eine Option schnell finden, und jede Änderung wird automatisch in Ihrem persönlichen Konfigurationsordner gespeichert.

## Einstellungen öffnen

1. Wählen Sie **Peach Commander > Einstellungen…** oder drücken Sie Cmd+, (Komma).
2. Sie können dasselbe Fenster auch über **Konfiguration > Optionen…** öffnen.
3. Wählen Sie eine Seite aus der Liste auf der linken Seite; die Optionen dieser Seite erscheinen rechts.
4. Passen Sie die Steuerelemente an. Änderungen werden sofort wirksam, sofern ein Hinweis auf der Seite nichts anderes angibt.
5. Um direkt zu einer Option zu kommen, tippen Sie in das Suchfeld oben im Fenster. Passende Einstellungen aus *allen* Seiten werden mit der Seite aufgeführt, auf der sie jeweils liegen, und die Auswahl öffnet diese Seite mit hervorgehobener Einstellung. ↑/↓ bewegen sich durch die Ergebnisse, Return öffnet das hervorgehobene, und Esc verlässt die Suche und stellt die Seite wieder her, von der Sie kamen.

![Das Einstellungsfenster mit der Seite Layout und Kontrollkästchen für die Oberflächenleisten](screenshots/settings-layout.png)
*(Abbildung: Auf der Seite Layout legen Sie fest, welche Leisten rund um die Panels angezeigt werden.)*

## Die Seiten

Das Fenster enthält diese Seiten, in dieser Reihenfolge:

- **Layout** — Laufwerksleiste, Tab-Leiste, Pfadleiste und Statusleiste ein- oder ausblenden.
- **Anzeige** — wie Dateien und Ordner aufgelistet werden, einschließlich des Datumsformats.
- **Symbole** — Erscheinungsbild der Symbole in den Dateilisten.
- **Bedienung** — allgemeines Verhalten, etwa was geschieht, wenn Sie in einem Panel tippen (Schnellsuche versus Befehlszeile).
- **Farben** — benutzerdefinierte Panel-Farben, oder dem aktuellen Thema folgen lassen.
- **Bestätigung** — welche Aktionen zuerst eine Bestätigung verlangen, etwa das Löschen.
- **Bearbeiten/Ansehen** — ob beim Sichern im Editor eine `.bak`-Sicherungskopie aufbewahrt wird, die Programme zum Bearbeiten und Ansehen von Dateien sowie die Zuordnungen pro Dateityp.
- **Kopieren/Löschen** — Dateimetadaten bewahren, schnelles Klonen verwenden, nur neuere Dateien kopieren, nach dem Kopieren überprüfen, Löschungen in den Papierkorb legen und ein optionales Geschwindigkeitslimit festlegen.
- **Zip/Packer** — das Standard-Archivformat und die Kompressionsstufe, die beim Packen verwendet werden.
- **Plugins** — installierte Plugins ein- oder ausschalten.
- **Tabs** — wie sich Ordner-Tabs öffnen und verhalten.
- **FTP** — Netzwerk-Standardwerte wie das Keep-Alive-Intervall.
- **Tastatur** — Tastenkürzel überprüfen und ändern.
- **Sprache** — Systemstandard, English oder Deutsch wählen.
- **KI** — den KI-Assistenten konfigurieren: bevorzugtes Modell, Cloud-Endpunkt und Schlüssel, Autonomie sowie der optionale MCP-Server (siehe [KI-Assistent](ai-assistant.md)).
- **Sonstiges** — Ihren Konfigurationsordner im Finder öffnen.

Aktivierte Plugins können nach den integrierten Seiten eigene Seiten hinzufügen — zum Beispiel **Disk Map** und **System Monitor** —, sodass ihre Optionen im selben Fenster liegen (siehe [Plugins](plugins.md)).

![Das Einstellungsfenster mit den Optionen der Seite Anzeige dazu, wie Dateien aufgelistet werden](screenshots/settings-display.png)
*(Abbildung: Auf der Seite Anzeige legen Sie fest, wie Dateien und Ordner aufgelistet werden.)*

![Das Einstellungsfenster mit der Seite Bedienung](screenshots/settings-operation.png)
*(Abbildung: Die Seite Bedienung steuert das Verhalten von Schnellsuche und Maus.)*

## Wo Ihre Einstellungen gespeichert werden

Ihre Konfiguration wird in einfachen Textdateien in Ihrem persönlichen Application-Support-Ordner unter `~/Library/Application Support/PeachCommander` aufbewahrt. Um ihn zu öffnen, gehen Sie zur Seite **Sonstiges** und klicken Sie auf **Konfigurationsordner öffnen**. Gespeicherte FTP-Passwörter werden nicht in diesen Dateien abgelegt; sie werden sicher im macOS-Schlüsselbund aufbewahrt.

Einstellungen werden geschrieben, während Sie sie ändern. Sie können jederzeit auch ein Speichern erzwingen mit **Konfiguration > Einstellungen sichern** und die aktuelle Fensterposition und das Panel-Layout mit **Konfiguration > Position sichern** ablegen.

## Einstellungen aus Total Commander übernehmen

Wenn Sie von Total Commander unter Windows umsteigen, können Sie Ihre gespeicherten FTP-Sites importieren. Wählen Sie **Konfiguration > wincmd.ini importieren…** und wählen Sie Ihre Total-Commander-FTP-Konfigurationsdatei aus. Ihre Verbindungen werden in Peach Commander in derselben Reihenfolge hinzugefügt, in der sie dort erschienen.

## Tastenkürzel

| Aktion | Kürzel |
| --- | --- |
| Einstellungen öffnen | Cmd+, |

## Hinweise

- Die Seite **Sprache** bietet Systemstandard, English und Deutsch. Eine Sprachänderung wird erst nach einem Neustart von Peach Commander wirksam.
- Auf der Seite **Farben** festgelegte Farben überschreiben das Thema; verwenden Sie dort **Auf Standard zurücksetzen**, um zu den Farben des Themas zurückzukehren.
- Peach Commander speichert seine Einstellungen nur in seinem eigenen Konfigurationsordner, sodass Ihre Änderungen niemals andere Apps betreffen und sich leicht sichern lassen, indem Sie diesen Ordner kopieren.
