---
title: Erscheinungsbild
slug: appearance
section: Anpassen
order: 114
related: [settings]
---

Peach Commander kann sich dem Aussehen des restlichen Mac anpassen oder einen eigenen Stil annehmen. Sie können der hellen oder dunklen Systemeinstellung folgen (oder eine davon erzwingen), die Datei-Panels umfärben, Dateien nach Typ hervorheben und Schriftgröße der Liste sowie Datumsformat anpassen, sodass die Panels genau so lesbar sind, wie Sie es möchten.

## Helles, dunkles oder Systemerscheinungsbild einstellen

1. Öffnen Sie das Einstellungsfenster über Konfiguration > Optionen… oder drücken Sie Cmd+,.
2. Wählen Sie die Seite **Farben**.
3. Wählen Sie im Menü **Erscheinungsbild** eine der folgenden Optionen:
   - **System (macOS folgen)** – passt sich automatisch der aktuellen hellen/dunklen Einstellung Ihres Mac an.
   - **Hell** – verwendet immer die helle Palette.
   - **Dunkel** – verwendet immer die dunkle Palette.

![Einstellungsseite „Farben" mit dem Menü „Erscheinungsbild" und den Farbfeldern für die Panels](screenshots/settings-colors.png)
*(Abbildung: Die Seite „Farben": Wählen Sie ein Erscheinungsbild und überschreiben Sie einzelne Panel-Farben.)*

## Panel-Farben anpassen

Auf derselben Seite **Farben** aktivieren Sie unter **Eigene Panel-Farben** das Kontrollkästchen neben einem Element und wählen eine Farbe aus dem Farbfeld daneben:

- **Text** – die Datei- und Ordnernamen.
- **Hintergrund** – der Panel-Hintergrund.
- **Markierter Text** – die Farbe für markierte Dateien.
- **Cursor-Rahmen** – der Umriss um das aktuelle Element.

Lassen Sie ein Kontrollkästchen deaktiviert, um die eingebaute Farbe für dieses Element beizubehalten. Klicken Sie auf **Auf Standard zurücksetzen**, um alle Überschreibungen auf einmal zu entfernen.

## Dateien nach Typ einfärben

1. Öffnen Sie Konfiguration > Optionen… und wählen Sie die Seite **Anzeige**.
2. Klicken Sie auf **Dateityp-Farben…**.
3. Fügen Sie eine Regel mit einer Namensmaske wie `*.zip` oder `*.txt` hinzu und wählen Sie dann eine Farbe für die dazu passenden Dateien.
4. Verwenden Sie **Regel hinzufügen** für weitere Masken; klicken Sie auf **Fertig** zum Speichern oder auf **Abbrechen** zum Verwerfen.

Passende Dateien erscheinen dann in beiden Panels in der von Ihnen gewählten Farbe.

## Schriftgröße und Datumsformat anpassen

Auf der Seite **Anzeige** können Sie außerdem:

- die **Schriftgröße** der Panel-Liste in Punkt wählen.
- ein Muster für das **Datumsformat** eingeben, um zu steuern, wie Änderungsdaten angezeigt werden; lassen Sie es leer, um das regionale Format Ihres Mac zu verwenden. Unter dem Feld erscheint während der Eingabe eine Live-Vorschau.
- den **Wechselnden Zeilenhintergrund** aktivieren, um mit Zebrastreifen lange Listen leichter überblickbar zu machen.

## Tastenkürzel

| Aktion | Tastenkürzel |
| --- | --- |
| Einstellungen öffnen | Cmd+, |

## Hinweise

- Die Einstellung zum Erscheinungsbild gestaltet die Datei-Panels. Systemdialoge, Warnungen und Standardsteuerelemente folgen stets macOS.
- Der eingebaute Datei-Betrachter verwendet aufeinander abgestimmte helle und dunkle Paletten für die Syntaxhervorhebung, sodass hervorgehobener Code in beiden Erscheinungsbildern lesbar bleibt.
- Eigene Farben und Dateityp-Regeln werden mit Ihren Einstellungen gespeichert und bei jedem Öffnen der App erneut angewendet.
