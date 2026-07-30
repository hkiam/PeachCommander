---
title: Tastatur & Kurzbefehle
slug: keyboard-shortcuts
section: Anpassen
order: 112
related: [keyboard-shortcuts-reference, settings]
---

Peach Commander ist dafür gebaut, von der Tastatur aus gesteuert zu werden. Er wird mit zwei fertigen Kurzbefehl-Schemata ausgeliefert und lässt Sie jeden Befehl auf die von Ihnen bevorzugten Tasten neu belegen. Wenn Sie von einem klassischen Zwei-Panel-Dateimanager kommen, können Sie die Tasten beibehalten, die Sie bereits kennen; wenn Sie lieber vertraute Mac-Kombinationen nutzen, wechseln Sie mit einem Klick zum macOS-Schema. Ein durchsuchbarer Befehlsbrowser lässt Sie alles entdecken, was die App kann, und jeden Befehl über seinen Namen ausführen.

## Kurzbefehl-Schemata wechseln

1. Öffnen Sie das Menü **Konfiguration**.
2. Wählen Sie **Tastaturschema** und dann eines aus:
   - **TC Classic** (die Voreinstellung) behält die traditionellen Tasten bei, mit Ctrl-basierten Kombinationen wie Ctrl+R zum Aktualisieren eines Panels.
   - **macOS Native** bildet dieselben Aktionen dort, wo es sinnvoll ist, auf vertraute Mac-Tasten ab, zum Beispiel Cmd+C zum Kopieren von Dateien und Cmd+F zum Suchen.
3. Ein Häkchen zeigt das aktive Schema an. Die Änderung wird sofort in den Menüs und der Kurzbefehlleiste wirksam.

## Kurzbefehle anpassen

1. Wählen Sie **Konfiguration > Tastaturkurzbefehle…**.
2. Finden Sie einen Befehl über das Suchfeld und wählen Sie dann seine Zeile aus.
3. Klicken Sie auf **Aufnehmen…** und drücken Sie die gewünschte Tastenkombination. Sie wird sofort zugewiesen.
4. Falls diese Kombination bereits von einem anderen Befehl verwendet wurde, teilt Ihnen ein Hinweis mit, von welchem Befehl sie übernommen wurde.
5. Verwenden Sie **Löschen**, um den Kurzbefehl eines Befehls zu entfernen, oder **Standard wiederherstellen**, um alle Ihre Änderungen zu verwerfen und zu den Originaltasten des Schemas zurückzukehren.

![Der Editor für Tastaturkurzbefehle mit einer Liste von Befehlen und ihren zugewiesenen Tasten](screenshots/keys-editor.png)
*(Abbildung: Suchen Sie einen Befehl und verwenden Sie dann Aufnehmen, Löschen oder Standard wiederherstellen, um seinen Kurzbefehl zu ändern.)*

## Alle Befehle durchsuchen

1. Wählen Sie **Konfiguration > Befehlsbrowser…**.
2. Tippen Sie in das Suchfeld, um nach Name, Kategorie oder Beschreibung zu filtern.
3. Doppelklicken Sie auf einen Befehl oder wählen Sie ihn aus und klicken Sie auf **Ausführen**, um ihn auf dem aktiven Panel auszuführen.

![Der Befehlsbrowser mit einer durchsuchbaren Liste von Befehlen](screenshots/command-browser.png)
*(Abbildung: Jeder Befehl in einer durchsuchbaren Liste, mit einer kurzen Beschreibung zu jedem.)*

## Kurzbefehle

| Aktion | Menüpfad |
|---|---|
| Das klassische Schema wählen | Konfiguration > Tastaturschema > TC Classic |
| Das Mac-Schema wählen | Konfiguration > Tastaturschema > macOS Native |
| Kurzbefehle bearbeiten | Konfiguration > Tastaturkurzbefehle… |
| Alle Befehle durchsuchen | Konfiguration > Befehlsbrowser… |
| Aktives Panel aktualisieren | F2 (auch Ctrl+R) |

## Hinweise

- Ihre benutzerdefinierten Kurzbefehle werden automatisch gespeichert und über das aktive Schema gelegt. Beim Wechsel des Schemas bleiben Ihre persönlichen Überschreibungen erhalten.
- Befehle, die im aktuellen Kontext nicht verfügbar sind, erscheinen sowohl im Kurzbefehl-Editor als auch im Befehlsbrowser abgeblendet.
- Um die Funktionstasten (F1–F12) direkt zu verwenden, aktivieren Sie **F1-, F2- usw. Tasten als Standard-Funktionstasten verwenden** unter Systemeinstellungen > Tastatur. Andernfalls halten Sie die **Fn**-Taste zusammen mit der Funktionstaste gedrückt.
