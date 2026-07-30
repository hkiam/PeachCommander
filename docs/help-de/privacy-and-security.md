---
title: Datenschutz & Sicherheit
slug: privacy-and-security
section: macOS & Datenschutz
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander ist so gebaut, dass es Ihnen nicht im Weg steht und Ihre Daten auf Ihrem Mac behält. Passwörter werden an den macOS-Schlüsselbund übergeben, Absturzinformationen verlassen Ihren Computer niemals ohne Ihre Zustimmung, und die App sammelt keine Nutzungsanalysen. Dieses Thema erklärt, wo Ihre vertraulichen Informationen liegen und wie Sie die eine Systemberechtigung erteilen, die ein Dateimanager benötigt, um seine Aufgabe zu erfüllen.

## Wo Passwörter gespeichert werden

Jedes Passwort oder jede Schlüssel-Passphrase, die Sie speichern — für eine FTP- oder SFTP-Verbindung oder zum Öffnen eines passwortgeschützten Archivs — wird in den macOS-**Schlüsselbund** geschrieben, denselben sicheren Speicher, den das System für Ihre WLAN- und Website-Anmeldungen verwendet. Passwörter werden niemals im Klartext in die eigenen Einstellungen oder Verbindungsdateien von Peach Commander geschrieben.

1. Wenn Sie ein Verbindungs- oder Archivpasswort speichern, wählen Sie die Option, es zu merken.
2. Das Passwort wird in Ihrem Anmelde-Schlüsselbund gespeichert, geschützt durch Ihr Benutzerkonto.
3. Um ein gespeichertes Passwort später zu überprüfen oder zu entfernen, öffnen Sie die App **Schlüsselbundverwaltung** (in Programme ▸ Dienstprogramme) und suchen Sie nach dem Verbindungsnamen.

## Vollständigen Festplattenzugriff erteilen

macOS hält einige Orte privat — die Daten von Mail, Nachrichten und anderen Apps innerhalb Ihres Library-Ordners — bis Sie den Zugriff ausdrücklich erlauben. Da ein Dateimanager jede Datei erreichen können soll, bittet Peach Commander um **Vollständigen Festplattenzugriff**. Die App funktioniert mit eingeschränktem Zugriff weiter, bis Sie ihn erteilen; Sie sehen lediglich jene geschützten Ordner nicht.

1. Wählen Sie **Befehle ▸ Vollständiger Festplattenzugriff…** oder klicken Sie auf **Systemeinstellungen öffnen**, wenn die App Ihnen beim Start anbietet, Sie zu führen.
2. Aktivieren Sie in **Systemeinstellungen ▸ Datenschutz & Sicherheit ▸ Vollständiger Festplattenzugriff** den Schalter neben Peach Commander.
3. Starten Sie die App neu, wenn Sie dazu aufgefordert werden.

## Absturzberichte bleiben lokal

Wenn die App unerwartet beendet wird, schreibt macOS einen Absturzbericht in Ihren eigenen Diagnoseordner. Beim nächsten Start bemerkt Peach Commander ihn und bietet an, Ihnen beim Einreichen eines Fehlerberichts zu helfen — aber nur mit Ihrer Zustimmung.

- Sie können **Im Finder anzeigen** wählen, um den Bericht zu sehen, oder **Bericht in die Zwischenablage kopieren**, um ihn selbst in einen Fehlerbericht einzufügen.
- Es wird niemals etwas automatisch übertragen, und es ist kein Drittanbieter-Dienst zur Absturzberichterstattung beteiligt.

## Hinweise

- **Keine Telemetrie.** Peach Commander verfolgt Ihre Aktivität nicht und sendet keine Nutzungsanalysen irgendwohin.
- **Eingeschränkter Zugriff ist sicher.** Wenn Sie den vollständigen Festplattenzugriff überspringen, durchsucht und verwaltet die App weiterhin die Dateien, die Sie normalerweise sehen können; nur systemgeschützte Orte werden ausgeblendet.
- **Sie steuern gespeicherte Passwörter.** Da Anmeldedaten im Schlüsselbund liegen, verwalten und widerrufen Sie sie mit den Standardwerkzeugen von macOS anstatt innerhalb der App.
