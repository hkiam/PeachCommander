---
title: KI-Assistent
slug: ai-assistant
section: Plugins
order: 122
related: [plugins, settings, privacy-and-security]
---

Der KI-Assistent ist ein optionales, entfernbares Plugin, das Ihnen dabei hilft, in natürlicher Sprache mit Ihren Dateien zu arbeiten. Er kann ein Dokument zusammenfassen oder erläutern, einen besseren Dateinamen vorschlagen, Text übersetzen oder Korrektur lesen, Daten in eine Tabelle umwandeln und sogar einen Ordner organisieren – und er kann Dateiaktionen für Sie ausführen, nachdem er Ihnen zuvor einen Plan gezeigt hat. Er läuft direkt auf dem Gerät mit Apple Intelligence, sofern verfügbar, oder Sie können ihn auf ein Cloud-Modell verweisen. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸ Plugins…** vollständig deaktivieren oder entfernen.

## Den Assistenten öffnen

Wählen Sie **Befehle ▸ KI-Assistent**, um den Assistenten in einem angedockten Panel rechts im Fenster anzuzeigen. Geben Sie eine Anfrage ein und drücken Sie die Eingabetaste; der Assistent kann Dateien lesen, Dinge nachschlagen und – mit Ihrer Bestätigung – Änderungen vornehmen.

![Der Chat des KI-Assistenten, angedockt neben den Datei-Panels](screenshots/ai-chat.png)
*(Abbildung: Der KI-Assistent, rechts angedockt, arbeitet an einer Anfrage.)*

## Aktionen im Rechtsklick-Menü (KI ▸)

Am schnellsten nutzen Sie den Assistenten über das Untermenü **KI ▸** im Rechtsklick-Menü:

- **Auf einer Datei** – Zusammenfassen, Erläutern, Namen vorschlagen, Kommentar vorschlagen, Ins Englische übersetzen, Korrektur lesen, Aufgaben erkennen und Tabelle erstellen.
- **Auf dem Panel-Hintergrund** – Diesen Ordner organisieren und Mögliche Duplikate finden.

Jede **KI ▸**-Aktion öffnet ihren **eigenen benannten Chat** (zum Beispiel *Zusammenfassen – report.txt*), sodass verschiedene Aufgaben getrennt bleiben und sich nicht zu einer langen Konversation aufstauen. Wenn Sie selbst in das Eingabefeld tippen, setzt diese Anfrage den aktuellen Chat fort.

## Ihre Chats verwalten

- Verwenden Sie den Chat-Umschalter oben im Panel, um zwischen Konversationen zu wechseln.
- Das Menü **Löschen ▾** bietet **Diesen Chat löschen** und **Alle Chats löschen**, sodass Sie alles auf einmal leeren können, wenn die Liste lang wird. Leere Chats werden automatisch bereinigt, wenn Sie das Panel schließen.

## Änderungen werden zuerst bestätigt

Bei allem, was Dateien verändert – Verschieben, Umbenennen, Schreiben, Löschen –, zeigt der Assistent einen **Plan und wartet auf Ihre Bestätigung**, bevor er handelt. Sie können dies in den Einstellungen ändern, indem Sie die Autonomie des Assistenten erhöhen, oder sie auf schreibgeschützt senken, sodass er niemals etwas ändert.

## Einstellungen

Öffnen Sie **Konfiguration ▸ Einstellungen ▸ KI**, um den Assistenten auf einer einzigen Seite zu konfigurieren:

- **Bevorzugtes Modell** – Automatisch (Cloud, falls konfiguriert, andernfalls auf dem Gerät), Auf dem Gerät (Apple Intelligence) oder Cloud.
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
