---
title: Amazon S3 und S3-kompatible Speicher
slug: amazon-s3
section: Plugins
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Ein S3-Bucket lässt sich in einem Panel durchsuchen wie jeder Ordner. Wählen Sie **Mit Amazon S3 verbinden…** im Menü Netz, tragen Sie Endpunkt und Schlüssel ein, und der Speicher erscheint im aktiven Panel — mit der **Bucket-Liste als oberster Ebene**, und jedem Bucket als gewöhnlichem Verzeichnis darunter.

Es funktioniert mit Amazon S3 und mit allem, was dasselbe Protokoll spricht: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 und DigitalOcean Spaces sind alle erreichbar.

Es ist ein Plugin, Sie können es also unter **Konfiguration ▸ Plugins…** abschalten oder entfernen.

## Verbinden

Das Menü **Dienst** setzt die zwei Einstellungen, die man nicht erraten kann — ob HTTPS verwendet wird und ob der Endpunkt Pfad-Adressierung braucht — und lässt den Endpunkt selbst offen, weil er meist von Ihrem Konto abhängt. Beide Einstellungen scheitern auf eine Weise, die nach etwas anderem aussieht: Virtual-Hosted-Adressierung gegen eine nackte IP-Adresse ist ein Namensauflösungsfehler, und Pfad-Adressierung gegen Amazon ist ein „Bucket existiert nicht", das wie ein fehlender Bucket klingt.

Der **Secret Access Key** wandert über den Host in die **Schlüsselbundverwaltung**, niemals in eine Konfigurationsdatei. Lassen Sie das Feld bei einer späteren Verbindung leer, wird der gespeicherte verwendet.

**Diese Verbindung merken** behält Endpunkt, Region, Key-ID und Adressierungsart — nie das Geheimnis — in `~/Library/Application Support/PeachCommander/s3/profiles.json`. Eine gemerkte Verbindung wird außerdem ein Chip in der Laufwerksleiste, und ein Klick darauf verbindet sie direkt, statt diesen Dialog erneut zu öffnen.

### Profile, die Sie schon haben

Wenn Sie die AWS-Kommandozeile nutzen, werden ihre Profile im Menü **Name** mit *(AWS CLI)* angeboten, gelesen aus `~/.aws/credentials` und `~/.aws/config` — samt Region, Session-Token und `s3.addressing_style`. Dorthin wird nichts zurückgeschrieben, und ein solches Profil wird **nicht** von selbst gemerkt: eine zweite Kopie eines Geheimnisses zu halten ist etwas, das man verlangt, nicht etwas, das passiert, weil man einen Namen aus einem Menü gewählt hat.

### Öffentliche Buckets

**Anonym verbinden** sendet gar keine Signatur, was ein öffentlich lesbarer Bucket will. Ist der Bucket nicht öffentlich, wird Ihnen genau das gesagt — und nicht, Ihr Schlüssel sei abgelehnt worden. Es gab keinen Schlüssel.

## Was möglich ist

Auflisten, Lesen, Schreiben, Ordner und Buckets anlegen, Löschen, Umbenennen und Verschieben funktionieren alle. Kopien und Verschiebungen finden **auf dem Server** statt: die Bytes laufen nicht über Ihren Mac.

Ein Ordner ist in S3 nichts Wirkliches — er ist entweder ein gemeinsames Präfix der Schlüssel darunter oder ein Null-Byte-Objekt, dessen Name auf `/` endet. Beides wird als Ordner gezeigt. Einen anzulegen schreibt diesen Marker; einen zu löschen löscht jedes Objekt darunter, weil es nichts anderes zu löschen gibt.

Auf der obersten Ebene legt **Neuer Ordner einen Bucket an** — die oberste Ebene *ist* die Bucket-Liste, etwas anderes könnte es dort nicht bedeuten.

**Speicherklasse** und **ETag** stehen als Panel-Spalten bereit (Rechtsklick auf die Spaltenüberschrift). Beide stammen aus der Auflistung und kosten daher nichts.

## Was Sie davon erwarten können

**Ein Bucket lässt sich nicht umbenennen.** S3 hat diese Operation nicht, und die Alternative — jedes Objekt in einen neuen Bucket kopieren und den alten löschen — ist nicht, was ein Umbenennen-Dialog verlangt hat. Es wird verweigert statt vorgetäuscht.

**Übertragungen erfassen ganze Dateien.** Eine Datei wird in einem Stück geholt oder gesendet; eine abgebrochene Übertragung beginnt neu statt fortzusetzen. Große Uploads werden automatisch in Teile zerlegt; scheitert ein Teil, werden die Teile aufgeräumt und nicht liegengelassen, damit sie nicht berechnet werden.

**Einen Ordner umzubenennen ist nicht atomar.** Es kopiert und löscht ein Objekt nach dem anderen und hält beim ersten Fehler an, statt in einen halb verschobenen Zustand weiterzulaufen.

**Archivierte Objekte lassen sich nicht direkt lesen.** Ein Objekt in Glacier oder Deep Archive muss zuerst wiederhergestellt werden, in der AWS-Konsole oder mit der CLI. Das Panel sagt das, anstatt zu scheitern, als sei das Objekt beschädigt.

**Einen sehr großen Ordner aufzulisten dauert so lange wie der Server braucht.** Objekte kommen tausendweise, und das Panel füllt sich, wenn die letzte Seite eingetroffen ist.

**Jede Anfrage kostet bei einem bezahlten Dienst Geld.** Das Plugin ist darauf geschrieben, so wenig wie möglich zu fragen — Spalten stammen aus der Auflistung, die schon stattgefunden hat, die Region eines Buckets wird einmal gelernt und behalten — aber einen Bucket zu durchsuchen ist nicht so kostenlos wie eine Festplatte zu durchsuchen.
