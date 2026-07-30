---
title: Task Manager
slug: task-manager
section: Plug-ins
order: 125
related: [plugins, viewing-files, deleting-files]
---

De Task Manager-plug-in verandert de actieve processen op je Mac in een map die je kunt doorbladeren. Hij verschijnt als een **TaskManager**-schijf in de schijvenbalk; open hem en elk proces is een rij die je kunt sorteren, als een bestand inspecteren of beëindigen — met dezelfde toetsen die je al voor bestanden gebruikt. Het is een plug-in, dus je kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## Openen

1. Klik op de **📊 TaskManager**-vermelding in de schijvenbalk (die staat direct na je startschijf).
2. Het paneel vult zich met één rij per actief proces. De naam van elke rij is de procesnaam gevolgd door de PID, bijvoorbeeld `Finder (462)`.

![Task Manager toont actieve processen met de kolommen PID, CPU, geheugen en command](screenshots/task-manager.png)
*(Afbeelding: actieve processen getoond als een bestandslijst die je kunt sorteren en waarop je kunt handelen.)*

## Wat elke kolom betekent

Naast de gebruikelijke kolommen Grootte (geheugen) en Datum (starttijd) voegt Task Manager proceskolommen toe:

| Kolom | Betekenis |
| --- | --- |
| **PID** | Proces-id |
| **CPU %** | Recent processorgebruik (verschijnt pas na een tweede vernieuwing) |
| **Threads** | Aantal threads |
| **State** | R actief · S slapend · T gestopt · Z zombie · I inactief |
| **User** | Eigenaar |
| **PPID** | Proces-id van de ouder |
| **Command** | Volledige opdrachtregel |

Sorteer op elke kolom (bijvoorbeeld CPU % of Grootte/geheugen), net zoals je in een gewone map zou doen.

## Een proces inspecteren of beëindigen

- **Bekijken (F3)** toont een rapport *Process Information*: naam, PID, ouder, gebruiker, status, threads, geheugen, CPU, starttijd, pad naar het uitvoerbare bestand en de volledige opdrachtregel.
- **Verwijderen (F8)** beëindigt het proces. De eerste verwijdering stuurt een nette **quit** (SIGTERM); een proces dat nog draait een tweede keer verwijderen escaleert naar een **force quit** (SIGKILL). De plug-in richt zich nooit op PID 1.

## Opmerkingen

- Basisgegevens (PID, ouder, gebruiker, status) zijn voor elk proces leesbaar, net als bij `ps`. Geheugen, threads en CPU kunnen alleen worden gelezen voor **je eigen** processen; bij andere processen blijven die kolommen leeg (ze vereisen verhoogde rechten, een latere toevoeging).
- CPU % is een verschil tussen twee metingen, dus het blijft leeg tot het paneel een tweede keer wordt vernieuwd (het paneel vernieuwt ongeveer elke twee seconden).
- De lijst is alleen-lezen, afgezien van het beëindigen van een proces — je kunt er geen bestanden naartoe kopiëren.
