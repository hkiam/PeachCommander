---
title: Java und .NET dekompilieren
slug: decompilers
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Drücken Sie **F3** auf einer kompilierten Datei und sehen Sie Quelltext statt Bytes. Zwei Plugins tun das — eines für Java (`.class`, `.jar`, `.apk`, `.dex`) und eines für .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — und sie verhalten sich gleich, deshalb behandelt diese Seite beide. Jedes lässt sich einzeln unter **Konfiguration ▸ Plugins…** abschalten oder entfernen.

Ein Archiv erscheint als Baum seiner Klassen, eine einzelne Klasse als eine Datei. **In Quelltext dekompilieren** im Menü Befehle schreibt das Ergebnis heraus und legt es in ein Panel, sodass Sie darin suchen, vergleichen und kopieren können wie in jedem anderen Quelltextordner.

## Die Engine installieren Sie

Kein Dekompilierer liegt bei, und nichts wird für Sie heruntergeladen. Das ist in zweierlei Hinsicht Absicht: JD-Core, der bekannteste Java-Dekompilierer, steht unter GPLv3 und könnte nicht in einer Apache-2.0-App mitgeliefert werden — und Engines werden besser, ein Austausch sollte also keine neue Version von Peach Commander erfordern.

**Engine-Ordner…** im Betrachter öffnet den Ordner, in den sie gehören. Die README dort nennt jede Engine und ihre Lizenz.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (für Android-`.dex` und `.apk`) und `javap` für reinen Bytecode |
| .NET | ILSpy und `monodis` für IL |

**Engines prüfen** führt den Versionsbefehl jeder Engine aus und unterscheidet drei Dinge: installiert und lauffähig, nicht installiert, und *installiert, aber nicht lauffähig* — ein Java-Werkzeug ohne JDK ist vorhanden und startet trotzdem nicht, und das zeigt sich erst, wenn man es wirklich ausführt.

Eine Engine wird durch Daten beschrieben, nicht durch Code, Sie können also selbst eine hinzufügen:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Können mehrere Engines eine Datei verarbeiten, wird die erste verfügbare genommen, sofern Sie keine auswählen. Sind zwei installiert, zeigt **Vergleichen** beide Ergebnisse nebeneinander — nützlich, wenn eine Engine bei einer Methode aufgibt, die die andere schafft.

## In kompiliertem Code suchen

**Alle Klassen durchsuchen** sieht den dekompilierten Text durch statt der Bytes, Sie finden also ein Stringliteral oder einen Methodennamen in einer JAR.

Das Dekompilieren während einer *Inhaltssuche* über viele Dateien ist ein eigener Schalter und standardmäßig aus: den Text zu erzeugen kann bedeuten, die Engine einmal pro Klasse laufen zu lassen, was auf einer langsamen Maschine nichts ist, das man an eine Suche verschwenden sollte. Der Hauptsuchdialog fragt getrennt; hier wird es ebenfalls abgelehnt.

## Zwischenspeicher und Grenzen

Ergebnisse werden zwischengespeichert, denn dieselbe Klasse zweimal zu dekompilieren ist reines Warten. In den Einstellungen stehen, wie viele Tage Ergebnisse bleiben, und eine **Größengrenze** für den Zwischenspeicher; **Zwischenspeicher jetzt leeren** räumt ihn und meldet, wie viel frei wurde.

Zwei Zeitlimits schützen vor einer Engine, die nicht fertig wird: eines für eine einzelne Klasse oder einen Typ, eines für ein ganzes Archiv. Beide nehmen 0 an, was „die Voreinstellung der Engine verwenden“ bedeutet.
