---
title: Vergleichen & Synchronisieren
slug: comparing-and-syncing
section: Power-Tools
order: 90
related: [multi-rename]
---

Wenn Sie zwei Kopien desselben Ordners führen – einen Arbeitsordner und ein Backup, einen Laptop und eine Netzwerkfreigabe, ein Projekt und dessen Archiv –, hilft Ihnen Peach Commander dabei, genau zu sehen, was sich geändert hat, und die beiden Seiten wieder in Einklang zu bringen. Sie können zwei Verzeichnisse synchronisieren, einzelne Dateien Zeile für Zeile vergleichen und Dateien Byte für Byte untersuchen, wenn Sie Gewissheit bis zum letzten Zeichen benötigen.

## Zwei Verzeichnisse synchronisieren

1. Öffnen Sie den zu synchronisierenden Ordner im linken Panel und den Vergleichsordner im rechten Panel.
2. Wählen Sie **Befehle ▸ Verzeichnisse synchronisieren…**. Die beiden Ordnerpfade werden aus Ihren Panels übernommen.
3. Legen Sie fest, wie gründlich der Vergleich sein soll: Unterordner einbeziehen, **nach Inhalt** vergleichen (nicht nur nach Datum und Größe) oder das Änderungsdatum ignorieren.
4. Fügen Sie eine Filtermaske hinzu (zum Beispiel `*.jpg;*.png`), wenn Sie nur bestimmte Dateien synchronisieren möchten.
5. Prüfen Sie das Ergebnisraster. Jede Zeile zeigt eine Datei links, einen Richtungspfeil in der Mitte und die passende Datei rechts. Die Pfeile geben an, was passieren wird: **→** kopiert von links nach rechts, **←** kopiert von rechts nach links, und **=** bedeutet, dass beide identisch sind.
6. Passen Sie einzelne Zeilen an, wenn Sie mit einer vorgeschlagenen Richtung nicht einverstanden sind, und klicken Sie dann auf die Schaltfläche zum Synchronisieren, um die Änderungen durchzuführen.

![Das Fenster „Verzeichnisse synchronisieren" mit zwei Ordnerpfaden und einem Ergebnisraster von Dateien mit Links-, Gleichheits- und Rechtspfeilen](screenshots/sync-dialog.png)
*(Abbildung: Das Fenster „Verzeichnisse synchronisieren" vergleicht beide Seiten und schlägt für jede Datei eine Kopierrichtung vor.)*

## Zwei Dateien nach Inhalt vergleichen

1. Wählen Sie in jedem Panel eine Datei aus (oder zwei Dateien im selben Panel).
2. Wählen Sie **Datei ▸ Nach Inhalt vergleichen…**.
3. Die beiden Dateien werden nebeneinander mit hervorgehobenen Unterschieden geöffnet. Verwenden Sie die Vor-/Zurück-Steuerung, um zwischen geänderten Blöcken zu springen.
4. Wenn Sie den Bearbeitungsmodus aktivieren, können Sie jede Datei direkt anpassen und Ihre Änderungen speichern.

![Das Vergleichsfenster zeigt zwei Textdateien nebeneinander mit hervorgehobenen abweichenden Zeilen](screenshots/diff-window.png)
*(Abbildung: Zwei Textdateien im Vergleich; geänderte Zeilen sind auf beiden Seiten hervorgehoben.)*

## Dateien Byte für Byte vergleichen

Wenn zwei Dateien gleich aussehen, Sie aber nachweisen müssen, dass sie wirklich identisch sind (oder das eine abweichende Byte finden möchten), verwenden Sie den binären Vergleich. Er zeigt beide Dateien in einer Hex-Ansicht mit markierten abweichenden Bytes, was ideal ist, um Downloads zu überprüfen, kodierte Daten zu kontrollieren oder eine exakte Kopie zu bestätigen.

## Verzeichnisauflistungen vergleichen

Um Unterschiede zwischen zwei geöffneten Ordnern auf einen Blick zu erkennen, wählen Sie **Markieren ▸ Verzeichnisse vergleichen** (Shift+F2). Peach Commander markiert die Dateien, die sich unterscheiden oder auf der anderen Seite fehlen, sodass Sie sie mit den üblichen Kopier-, Verschiebe- und Löschbefehlen bearbeiten können.

## Einschränken, was zu einer Synchronisation gehört

Das Maskenfeld trägt eine Einschlussliste über Dateinamen. Für alles, was sich damit nicht sagen lässt, öffnet **Filtern…** daneben ein Blatt mit drei Reitern. Was dort gesetzt wird, gilt für den *nächsten* Vergleich, und der Knopf sagt dann, wie viele Kriterien aktiv sind – ein Filter, den man nicht sieht, ist der Weg zu einer unvollständigen Sicherung, die als fertig gemeldet wird.

- **Ausschließen** nimmt Muster, getrennt durch `;` oder `|`. Ein Name ohne Schrägstrich trifft in jeder Tiefe (`*.tmp`), ein Schrägstrich am Ende meint einen Ordner samt Inhalt (`node_modules/`), und ein Muster mit Schrägstrich trifft den relativen Pfad (`src/*/generated`). Groß- und Kleinschreibung wird ignoriert.
- **Größe** und **Datum** beurteilen ein Paar als Ganzes: fällt eine der beiden Seiten heraus, bleibt das ganze Paar draußen. Das ist Absicht. Nur auf eine Seite angewandt, ließe ein Ausschluss das Paar einseitig aussehen und würde zu einer Kopie in die falsche Richtung.
- **In den letzten N Tagen** wird ab jedem Vergleich gemessen, nicht ab dem Speichern einer Vorlage – ein gespeicherter Auftrag bedeutet also weiterhin „der letzte Monat“.
- Der Reiter **Plugins** fragt ein Inhalts-Plugin nach der Seite, von der eine Datei kopiert würde. Dafür braucht es eine echte Datei, also wird er nur angeboten, wenn beide Seiten Ordner auf diesem Mac sind.

Ein ausgeschlossener Ordner wird auch im Spiegelmodus nicht gelöscht – ein Spiegel entfernt nur, was er wirklich verglichen hat. Die Statuszeile sagt, wie viele Einträge der Filter zurückgehalten hat, neben dem, was der Lauf tun wird. Ein Filter wird mit der Sync-Vorlage gespeichert und geladen, zu der er gehört.

## Zwei Ordner beidseitig gleich halten

Die zwei ursprünglichen Modi können eines nicht unterscheiden: eine Datei, die nur auf einer Seite
liegt, ist entweder **hier neu** oder **dort gelöscht**, und beides sieht gleich aus. Der symmetrische
Modus kopiert sie deshalb – wer auf dem Notebook etwas löscht und synchronisiert, bekommt es aus der
Sicherung zurück – und der Spiegelmodus löscht, aber nur in eine Richtung, sodass alles verloren ist,
was auf der Zielseite entstanden ist.

**Beidseitig (mit Gedächtnis)** löst das, indem es sich merkt, wie beide Ordner aussahen, als sie
zuletzt übereinstimmten. Mit diesem Datensatz kann eine Löschung auf einer Seite auf die andere
übertragen werden.

- Der **erste** Lauf eines Paares hat keinen Datensatz, verhält sich also genau wie vorher und löscht
  nichts. Er schreibt den Datensatz. Ab dem zweiten Lauf wirkt der Modus.
- Eine übertragene Löschung steht in eigener Farbe mit einem `⇒🗑` und ist **nicht angehakt**. Sie ist
  die einzige Zeile, die aus dem Gedächtnis der App kommt und nicht aus etwas, das man in den beiden
  Ordnern sehen kann – also haken Sie sie selbst an. Ein Klick auf den Pfeil bietet die anderen
  Antworten: die Datei stattdessen zurückkopieren, oder beide Seiten lassen.
- Auf einer Seite geändert und auf der anderen gelöscht ist ein **Konflikt**, nie eine Löschung.
  Ebenso eine Datei, die auf beiden Seiten geändert wurde.
- Nichts wird auf eine Abwesenheit hin gelöscht, die der Vergleich nicht bestätigen konnte – ein
  unlesbarer Ordner oder einer, den der Filter zurückgehalten hat, beweist nichts über seinen Inhalt.
- Nur zwei Ordner auf diesem Mac. Kein Server und kein Archiv: eine Löschung in einem Archiv schreibt
  es neu, eine Löschung auf einem Server ist endgültig, und dieser Modus ist nicht der, mit dem man
  das versucht.

**Für eine Löschung gibt es kein Rückgängig.** Auf diesem Mac landet eine gelöschte Datei im
Papierkorb und lässt sich im Finder zurückholen; das ist das ganze Netz. Der Datensatz liegt bei den
Einstellungen der App – verschiebt man einen der Ordner, hat das Paar keine Vorgeschichte mehr, und
ein Lauf ohne Vorgeschichte löscht nichts. In diese Richtung soll dieser Ausfall auch zeigen.

## Tastenkürzel

| Aktion | Tastenkürzel |
| --- | --- |
| Verzeichnisauflistungen vergleichen (abweichende Dateien markieren) | Shift+F2 |
| Nach Inhalt vergleichen | Datei ▸ Nach Inhalt vergleichen… |
| Verzeichnisse synchronisieren | Befehle ▸ Verzeichnisse synchronisieren… |

## Hinweise

- **Nach Inhalt vs. nach Datum/Größe.** Ein schneller Vergleich gleicht Dateien nach Größe und Änderungsdatum ab, was schnell ist, aber sich täuschen lässt, wenn die Zeitstempel bei identischen Dateien abweichen. Aktivieren Sie **nach Inhalt** für ein verlässliches Ergebnis, um den Preis, jede Datei lesen zu müssen.
- **Unterordner und Filter.** Das Synchronisierungsfenster kann in Unterordner absteigen und lässt sich mit einer Filtermaske einschränken, sodass Sie genau die Dateitypen synchronisieren können, die Ihnen wichtig sind.
- **Sie behalten die Kontrolle.** Das Synchronisieren läuft nie von selbst – Sie prüfen die vorgeschlagenen Richtungen im Ergebnisraster und können jede davon ändern, bevor etwas kopiert wird.
- **Voreinstellungen.** Häufig verwendete Synchronisierungskonfigurationen können gespeichert und wiederverwendet werden, sodass Sie nicht jedes Mal dieselben Optionen erneut eingeben müssen.
