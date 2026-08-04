---
title: Von einer URL herunterladen
slug: downloading-from-url
section: Netzwerk & Fernzugriff
order: 102
related: [ftp-and-sftp]
---

Peach Commander kann eine Datei direkt von einer HTTP- oder HTTPS-Webadresse in das aktive Panel holen, ohne einen Browser zu öffnen. Fügen Sie einen Link ein, bestätigen Sie den Namen, unter dem sie gespeichert wird, und der Download läuft von selbst — mit Fortsetzung, falls die Verbindung abbricht, Stapel-Downloads für viele Links auf einmal und optionaler Prüfsummenverifizierung, damit Sie sicher wissen, dass die Datei unversehrt angekommen ist.

## Eine Datei herunterladen

1. Öffnen Sie den Panel-Ordner, in dem die Datei landen soll.
2. Wählen Sie **Netz ▸ Von URL herunterladen** oder drücken Sie Cmd+Shift+U.
3. Fügen Sie die Webadresse in das Feld **URL(s)** ein. Wenn Sie zuvor einen Link kopiert haben, wird er für Sie eingetragen.
4. Prüfen Sie den Namen unter **Speichern unter** — er wird aus dem Link vorgeschlagen und Sie können ihn frei bearbeiten.
5. Klicken Sie auf **Herunterladen**.

![Der Dialog „Von URL herunterladen" mit einem Link, einem bearbeitbaren Dateinamen und Optionen](screenshots/download-url.png)
*(Abbildung: Der Download-Dialog — einen Link einfügen, den Namen bearbeiten und optionale Verifizierung, Anmeldedaten, Header oder einen Proxy festlegen.)*

Standardmäßig läuft der Download **im Hintergrund**, sodass Sie in den Panels weiterarbeiten können, während er überträgt. Schalten Sie **Im Hintergrund herunterladen** aus, um darauf zu warten, oder aktivieren Sie **Für später in die Warteschlange**, um ihn einzurichten, ohne ihn schon zu starten.

## Mehrere Dateien auf einmal herunterladen

Fügen Sie eine Webadresse pro Zeile in das Feld **URL(s)** ein. Wenn mehr als ein Link vorhanden ist, wird der Name jeder Datei automatisch aus ihrem Link abgeleitet und die Felder **Speichern unter** und **Verifizieren** pro Datei werden deaktiviert.

## Einen unterbrochenen Download fortsetzen

Wenn eine Übertragung abgeschnitten wird, behält Peach Commander das bereits Empfangene in einer temporären `.part`-Datei. Wenn Sie denselben Download erneut starten, wird er dort fortgesetzt, wo er aufgehört hat, sofern der Server dies unterstützt, statt von vorne zu beginnen. Die `.part`-Datei wird erst in den endgültigen Namen umbenannt, wenn der Download erfolgreich abgeschlossen ist.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Von URL herunterladen | Cmd+Shift+U |

## Tipps

- **Die Datei verifizieren.** Fügen Sie bei einem einzelnen Download eine erwartete **SHA-256**-Prüfsumme in das Feld **Verifizieren** ein. Nach der Übertragung wird die Prüfsumme der Datei damit verglichen, sodass Sie darauf vertrauen können, dass die Datei mit dem übereinstimmt, was der Herausgeber angegeben hat.
- **Anmeldung erforderlich?** Geben Sie in den **Auth**-Feldern einen Benutzernamen und ein Passwort für Websites ein, die Basisauthentifizierung verwenden. Für tokenbasierten Zugriff fügen Sie im Feld **Header** eine Zeile `Authorization: Bearer …` hinzu.
- **Benutzerdefinierte Header.** Fügen Sie im Feld **Header** einen Header pro Zeile hinzu, zum Beispiel `Referer: …` oder `Cookie: …`, für Links, die nur mit bestimmten Anfrage-Headern funktionieren.
- **Proxy.** Leiten Sie den Download über einen HTTP- oder SOCKS5-Proxy, indem Sie **Proxy**-Host, -Port und -Typ ausfüllen.
- **Nicht vertrauenswürdige Zertifikate.** Aktivieren Sie **Nicht vertrauenswürdiges Zertifikat zulassen** nur für eine Website, der Sie vertrauen und die ein selbstsigniertes Zertifikat verwendet; dies deaktiviert die normale HTTPS-Sicherheitsprüfung für diesen Download.
- **Hinweis:** Das Kürzel war früher Cmd+Shift+D, das auch „Gehe zu ▸ Schreibtisch“ verwendet — eines von beiden feuerte also nie. Das Herunterladen liegt jetzt auf Cmd+Shift+U (U wie URL), Schreibtisch behält Cmd+Shift+D wie im Finder.
