---
title: System Monitor
slug: system-monitor
section: Plugins
order: 124
related: [plugins, settings]
---

Das System-Monitor-Plugin blendet eine Live-Anzeige der Aktivität Ihres Macs direkt in die Titelleiste des Fensters ein: kleine Chips für CPU, Speicher, Festplatte, Netzwerk und — sofern die Hardware sie bereitstellt — GPU, Batterie und Sensoren. Jeder Chip wird einmal pro Sekunde aktualisiert; klicken Sie auf einen, um ein Pop-up mit einem Verlaufsdiagramm und einer detaillierten Aufschlüsselung zu erhalten. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸ Plugins…** aktivieren, konfigurieren oder entfernen.

## Die Chips in der Titelleiste

Wenn das Plugin eingeschaltet ist, sitzt eine Reihe kompakter Chips in der Titelleiste. Jeder Chip besteht aus einem farbigen Punkt, einer kurzen Beschriftung und einem Live-Wert (einige mit einer eingebetteten Sparkline):

| Chip | Zeigt |
| --- | --- |
| **CPU** | Prozessorauslastung, mit Detail pro Kern |
| **RAM** | Belegter / gesamter Speicher (plus verdrahtet, komprimiert, Swap) |
| **HDD** | Speicherplatz des Startvolumes und Lese-/Schreibdurchsatz |
| **Net** | Download-/Upload-Raten und -Summen |
| **GPU** · **Batt** · **Sens** | GPU-Auslastung · Batterieladung & -zustand · Lüfterdrehzahlen und Temperaturen |

Klicken Sie auf einen Chip, um ein Pop-up mit dem großen aktuellen Wert, einer **HISTORY**-Sparkline, einer **DETAILS**-Schlüssel/Wert-Liste und — bei der CPU — einer **CORE LOAD**-Liste mit Balken pro Kern zu öffnen.

## Konfigurieren

Wählen Sie **Befehle ▸ System Monitor…** (oder öffnen Sie **Konfiguration ▸ Einstellungen ▸ System Monitor**), um die Anzeige zu konfigurieren:

- **System-Monitor in Titelleiste anzeigen** — der Hauptschalter für die Chips.
- **Profil** — die Voreinstellungen *Minimal*, *Mittel* oder *Maximal*, die eine sinnvolle Auswahl an Modulen treffen.
- **Die Modultabelle** — schalten Sie jedes Modul (CPU, GPU, RAM, HDD, Net, Batt, Sens) ein oder aus, wählen Sie seine Farbe und ziehen Sie Zeilen, um die Reihenfolge festzulegen, in der sie in der Titelleiste erscheinen. Module, die Ihre Hardware nicht melden kann, werden als *(n/a)* angezeigt.

![Die System-Monitor-Einstellungen mit der Modultabelle, den Profilen und den Farben pro Modul](screenshots/system-monitor.png)
*(Abbildung: Wählen Sie, welche Module erscheinen, ihre Farben und ihre Reihenfolge.)*

## Hinweise

- Alles wird gemessen, niemals vorgetäuscht: Module, deren Daten die Hardware nicht bereitstellt (oft GPU oder Sensoren bei manchen Macs), bleiben nicht verfügbar, statt erfundene Zahlen zu zeigen. Auf Desktops ist die Batterie nicht verfügbar.
- Die Abtastung läuft nur über einen Hintergrund-Timer, solange die Anzeige sichtbar ist, und bewahrt etwa 30 Minuten Verlauf für die Diagramme.
- Ihre Modulauswahl, Farben und Reihenfolge werden mit der Konfiguration der App gespeichert.
