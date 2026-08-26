---
title: KI-Assistent
slug: ai-assistant
section: Plugins
order: 122
related: [plugins, settings, privacy-and-security]
---

Der KI-Assistent ist ein optionales, entfernbares Plugin, das Ihnen dabei hilft, in natürlicher Sprache mit Ihren Dateien zu arbeiten. Er kann ein Dokument zusammenfassen oder erläutern, einen besseren Dateinamen vorschlagen, Text übersetzen oder Korrektur lesen, Daten in eine Tabelle umwandeln und sogar einen Ordner organisieren – und er kann Dateiaktionen für Sie ausführen, nachdem er Ihnen zuvor einen Plan gezeigt hat. Er besteht aus zwei Plugins: **AI On-Device** läuft mit Apple Intelligence und liefert die Aktionen, die einen Vorschlag zeigen und ihn anwenden, während **AI Assistant** der Chat ist und ein Cloud-Modell benötigt. Aktivieren Sie eines von beiden oder beide. **Er kommt abgeschaltet.** Schalten Sie ihn in **Konfiguration ▸ Plugins…** ein und starten Sie neu — oder lassen Sie ihn aus, dann erscheint nichts von ihm: kein KI-Menü, kein Chat, keine Spalte. Das ist Absicht, solange er Beta ist: er kann Dateien umbenennen, verschieben und löschen und Shell-Befehle für Sie ausführen, jeweils hinter einem Plan, dem Sie zustimmen — und das ist viel Reichweite, um sie einer neuen Funktion von vornherein zu geben. Ohne API-Schlüssel arbeitet er vollständig auf Ihrem Mac; es geht hier also um die Reichweite und nicht darum, dass etwas das Gerät verlässt. Das Plugin **KI-Spalte**, das eine Panel-Spalte aus demselben Modell füllt, kommt mit ihm abgeschaltet. Beide können Sie auf derselben Seite auch ganz entfernen.

**Auf dem Gerät oder in der Cloud.** Das Modell auf dem Gerät ist privat und kostenlos — und es ist klein: es nimmt einige tausend Wörter auf einmal auf. Eine *ganze* lange Datei wird deshalb anders gelesen: der Assistent liest sie in Abschnitten und fasst die Ergebnisse zusammen, was mit der Dateilänge länger dauert. Für viel Arbeit über viele Dateien oder für lange Gespräche ist ein Cloud-Modell schneller und behält mehr im Blick; die Wahl treffen Sie in **Einstellungen ▸ KI**, und der Assistent stellt sofort um.


## Den Assistenten öffnen

Wählen Sie **Befehle ▸ KI-Assistent**, um den Assistenten in einem angedockten Panel rechts im Fenster anzuzeigen. Geben Sie eine Anfrage ein und drücken Sie die Eingabetaste; der Assistent kann Dateien lesen, Dinge nachschlagen und – mit Ihrer Bestätigung – Änderungen vornehmen.

![Der Chat des KI-Assistenten, angedockt neben den Datei-Panels](screenshots/ai-chat.png)
*(Abbildung: Der KI-Assistent, rechts angedockt, arbeitet an einer Anfrage.)*

## Aktionen im Rechtsklick-Menü (KI ▸)

Am schnellsten nutzen Sie den Assistenten über das Untermenü **KI ▸** im Rechtsklick-Menü:

- **Auf einer Datei** – Zusammenfassen, Erläutern, Einordnen, Namen vorschlagen, Kommentar vorschlagen, Ins Englische übersetzen, Korrektur lesen, Aufgaben erkennen und Tabelle erstellen.
- **Auf dem Panel-Hintergrund** – Diesen Ordner organisieren, Nach Bedeutung suchen und Mögliche Duplikate finden.

**Zusammenfassen**, **Erklären**, **Einordnen**, **Namen vorschlagen**, **Kommentar vorschlagen**, **Tabelle erstellen** und **Diesen Ordner organisieren** stammen aus dem Plugin **AI On-Device** und erledigen ihre Arbeit ganz ohne Chat — auch bei einem Scan oder Bildschirmfoto, weil die Wörter zuvor vom Bild gelesen werden: Sie zeigen ihren Vorschlag in einem Blatt, Sie entfernen das Häkchen bei allem, was so bleiben soll, und auf der Festplatte ändert sich nichts, bevor Sie zustimmen. Die übrigen Aktionen gehören zum Plugin **AI Assistant** und öffnen ihren eigenen benannten Chat, sodass verschiedene Aufgaben getrennt bleiben. Wenn Sie selbst in das Eingabefeld tippen, setzt diese Anfrage den aktuellen Chat fort.

**Mehrere Dateien auf einmal.** Markieren Sie eine Auswahl, dann läuft die Aktion über jede markierte Datei, eine nach der anderen. Die Aktionen mit Blatt zeigen ihren Fortschritt dort, und **Abbrechen** hält zwischen zwei Dateien an; die Aktionen mit Chat zeigen ihn in der Statuszeile, wo **Stopp** dasselbe tut. So oder so können Sie die ersten Ergebnisse ansehen und abbrechen.

**Namen vorschlagen** endet in einer Schaltfläche statt in einem Satz: der vorgeschlagene Name steht in einer Leiste unter dem Gespräch, mit **Umbenennen** daneben. Das Drücken ist die Zustimmung — Sie werden nicht zweimal gefragt.

### Eigene Formulierungen

Was jede Aktion das Modell fragt, ist eine Textdatei, die Sie ändern können: `aichat/skills.json` für die Datei-Aktionen und `aichat/folder-skills.json` für die Ordner-Aktionen, in Ihrem Konfigurationsordner. Beide werden beim ersten Start mit den eingebauten Formulierungen angelegt, damit das Format sichtbar ist. `{name}` und `{path}` stehen für die Datei. Löschen Sie eine Datei, gilt wieder die eingebaute Formulierung.

**Eigene Aktionen.** Legen Sie einen Eintrag mit einer `id` Ihrer Wahl an — er lässt sich dann wie jeder andere Befehl aufrufen, indem Sie `plugin.ai.skill.<id>` benennen: im Benutzermenü, in der Buttonbar oder auf einem Tastenkürzel. (Für eine Ordner-Aktion `plugin.ai.folderskill.<id>`.) Das Untermenü **KI ▸** selbst zeigt die eingebauten Aktionen: es wird aus dem Manifest des Plugins gebaut, ohne das Plugin zu laden — damit ein deaktiviertes Plugin nichts beiträgt. Deshalb platzieren Sie eigene Aktionen selbst, statt dass sie dort erscheinen. Benennen Sie eine id, die es nicht gibt, sagt der Assistent das, statt nichts zu tun.

## Eine Datei finden lassen

Sie müssen nicht wissen, wo eine Datei liegt. Beschreiben Sie sie, und der Assistent sieht in dem Index nach, den macOS von Ihrer Platte ohnehin führt — es ist also nichts aufzubauen und auf nichts zu warten.

- *„Finde die PDF-Rechnung von letztem Monat"* — eine Art, ein Wort im Namen und ein Zeitfenster.
- *„Wo sind alle meine node_modules-Ordner?"* — Ordner, nach Namen, überall in Ihrem Benutzerordner.
- *„Welche Datei erwähnt den Aachener Vertrag?"* — Wörter **in** Dateien, was die gewöhnliche Dateisuche nur kann, wenn Sie ihr vorher einen Ordner nennen.

Sie können steuern, wo gesucht wird: standardmäßig im Benutzerordner, auf dem ganzen Rechner oder nur in dem Ordner, den ein Panel zeigt. Der Assistent sagt, welches davon er genommen hat — damit ist auch eine leere Antwort lesbar und nicht bloß ein Schulterzucken.

Zwei Grenzen, die man kennen sollte. macOS hält manche Orte aus seinem Index heraus — und ohne Festplattenvollzugriff aus der Reichweite jeder App —, „nichts gefunden" ist also kein Beweis, dass es die Datei nicht gibt; siehe [Fehlerbehebung](troubleshooting). Und eine gerade erst erzeugte Datei ist möglicherweise noch nicht indiziert; dann findet sie **Dateien suchen** (Alt+F7), das die Ordner selbst durchläuft.

## Ihre Chats verwalten

- Verwenden Sie den Chat-Umschalter oben im Panel, um zwischen Konversationen zu wechseln.
- Das Menü **Löschen ▾** bietet **Diesen Chat löschen** und **Alle Chats löschen**, sodass Sie alles auf einmal leeren können, wenn die Liste lang wird. Leere Chats werden automatisch bereinigt, wenn Sie das Panel schließen.

## Änderungen werden zuerst bestätigt

Bei allem, was Dateien verändert – Verschieben, Umbenennen, Schreiben, Löschen –, zeigt der Assistent einen **Plan und wartet auf Ihre Bestätigung**, bevor er handelt. Sie können dies in den Einstellungen ändern, indem Sie die Autonomie des Assistenten erhöhen, oder sie auf schreibgeschützt senken, sodass er niemals etwas ändert.

**Sie können einem Plan auch nur teilweise zustimmen.** Betrifft ein Plan mehrere Dateien — einen ganzen Ordner umbenennen, die Downloads aufräumen —, erscheint jede davon als angehakte Zeile über den Schaltflächen. Haken Sie ab, was unangetastet bleiben soll, und drücken Sie **Bestätigen & ausführen**: der Rest läuft, das Abgehakte wird nicht berührt. Alles abzuhaken ist dasselbe wie Abbrechen, und der Assistent sagt das auch, statt zu melden, er habe nichts getan. Ein Plan mit nur einer Aktion hat keine Liste — dazu sagen Bestätigen und Abbrechen schon ja und nein.

## Was der Assistent getan hat, und wie Sie es zurücknehmen

**Aktionen ▾** im Chat hat zwei Einträge:

- **Zeigen, was der Assistent getan hat…** listet jede Änderung, die neueste zuerst, mit dem, was verlangt wurde, und dem Ergebnis — einschließlich Versuche, die die Autonomie-Einstellung abgelehnt hat. Ein extern über MCP verbundener Agent steht in derselben Liste.
- **Letzte Änderung rückgängig** nimmt die neueste Änderung zurück, für die es eine Umkehrung gibt: ein Umbenennen wird zurückbenannt, ein Verschieben zurückverschoben. Wo nichts zurückgenommen werden kann, sagt die Liste warum — eine überschriebene Datei wurde nirgends aufbewahrt, und Papierkorb-Einträge holt man im Finder zurück.

Sie können auch einfach fragen: *„mach das rückgängig"* und *„was hast du geändert?"* erreichen dieselben zwei Funktionen.

## Spalten im Dateifenster

Die Zusammenfassungen des Assistenten gibt es als Spalte. Fügen Sie **AI Summary** über den Spalten-Editor hinzu: sie zeigt die erste Zeile der Zusammenfassung für jede Datei, die der Assistent schon zusammengefasst hat, und bleibt für die übrigen leer — die Spalte zeigt bereits geleistete Arbeit und startet selbst niemals das Modell. **Language** im selben Plugin erkennt ohne Modell, in welcher Sprache eine Textdatei geschrieben ist.

## Einstellungen

Öffnen Sie **Konfiguration ▸ Einstellungen ▸ KI**, um den Assistenten auf einer einzigen Seite zu konfigurieren:

- **Bevorzugtes Modell** – welches Modell der Chat **AI Assistant** verwendet. Seit die geräteinternen Aktionen ein eigenes Plugin sind, betrifft dies nur den Chat: *Cloud* und *Automatisch* nutzen beide den Endpunkt unten, und *Auf dem Gerät* sagt dem Chat, dass er nicht gebraucht wird.
- **Cloud-Endpunkt, Modell und API-Schlüssel** – um ein OpenAI-kompatibles Modell anstelle des lokalen zu verwenden. Der Schlüssel wird im macOS-Schlüsselbund gespeichert, niemals in Ihren Konfigurationsdateien.
- **Autonomie des Assistenten** – schreibgeschützt, Änderungen bestätigen (Standard) oder autonom.
- **Eigener System-Prompt** – optionale Anweisungen, die beeinflussen, wie der Assistent antwortet.
- **MCP-Server** – ein optionaler, nur lokal verfügbarer Server, der einem externen Agenten die Steuerung der App ermöglicht; standardmäßig deaktiviert und durch ein Token schützbar.

![Die KI-Seite in den Einstellungen mit den Optionen für Autonomie und MCP-Server](screenshots/settings-ai.png)
*(Abbildung: Alle Assistentenoptionen befinden sich auf einer einzigen KI-Seite in den Einstellungen.)*

## Datenschutz

- Mit Apple Intelligence läuft der Assistent **auf Ihrem Mac**; nichts verlässt das Gerät.
- Ein Cloud-Modell wird **nur verwendet, wenn Sie eines konfigurieren**, und sein API-Schlüssel wird im Schlüsselbund aufbewahrt.
- Dateiverändernde Aktionen werden vor ihrer Ausführung bestätigt, sofern Sie die Autonomiestufe nicht bewusst erhöhen.
