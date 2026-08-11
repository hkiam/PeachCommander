---
title: WebDAV-Server
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Ein WebDAV-Server — Nextcloud, ownCloud, eine Synology, ein Universitätsspeicher — lässt sich in einem Panel durchsuchen wie jeder Ordner. Wählen Sie **WebDAV verbinden…** im Menü Netz, geben Sie eine URL an, und der Server erscheint im aktiven Panel.

Es ist ein Plugin, Sie können es also unter **Konfiguration ▸ Plugins…** abschalten oder entfernen.

## Verbinden

Die URL ist die Sammlung, in der Sie landen wollen, mit Ihrem Benutzernamen vor dem Host:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Nach dem Passwort wird getrennt gefragt, und es wandert über den Host in den **Schlüsselbund**, nie in eine Konfigurationsdatei. Lassen Sie es bei einer späteren Verbindung leer, wird das gespeicherte verwendet.

Jede URL, mit der Sie sich verbinden, wird gemerkt — die letzten dreißig, die neueste zuerst — und beim nächsten Mal im Aufklappmenü angeboten. Diese Liste liegt in `~/Library/Application Support/PeachCommander/webdav/sites.json` und enthält **nur URLs**; ein Passwort wird dort nie hineingeschrieben.

## Nutzen Sie https

Die Anmeldung erfolgt per HTTP Basic, das heißt Benutzername und Passwort reisen base64-kodiert — kodiert, nicht verschlüsselt. Über `https://` schützt die Verbindung sie. Über `http://` liegen sie praktisch offen, und alles zwischen Ihnen und dem Server kann sie mitlesen. Einfaches `http://` wird akzeptiert, weil ein Server auf dem eigenen Rechner oder in einem abgeschlossenen Laborsegment ein legitimer Fall ist — eine gute Voreinstellung ist es nicht.

## Was Sie tun können

Auflisten, Lesen, Schreiben, Ordner anlegen, Löschen, Umbenennen und Verschieben funktionieren alle — sie bilden auf die WebDAV-Verben `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` und `MOVE` ab. Ein Panel auf einem WebDAV-Server verhält sich für die alltägliche Arbeit also wie ein Panel auf einer Platte.

## Womit Sie rechnen sollten

**Übertragungen laufen ganzdateiweise.** Eine Datei wird in einem Stück geholt oder gesendet; es gibt keine Bereichsübertragung, eine abgebrochene Übertragung einer großen Datei beginnt also von vorn, statt fortzusetzen.

**Kopieren innerhalb des Servers geht über Ihren Mac.** Das Plugin verwendet das Verb `COPY` nicht, das Duplizieren einer Datei auf dem Server lädt sie also herunter und wieder hoch. Auf einer langsamen Leitung ist Verschieben — das der Server selbst erledigt — deutlich schneller als Kopieren.

**Nichts wird gesperrt.** WebDAVs `LOCK` wird nicht genutzt; schreiben zwei Personen gleichzeitig dieselbe Datei, entscheidet, wer zuletzt sichert — genau wie auf einer Netzwerkfreigabe ohne Sperren.

**Nur Basic-Authentifizierung.** Server, die Digest, ein Bearer-Token oder einen Single-Sign-on-Ablauf verlangen, lehnen die Verbindung ab. Viele davon bieten stattdessen ein anwendungsspezifisches Passwort an, und das funktioniert hier.
