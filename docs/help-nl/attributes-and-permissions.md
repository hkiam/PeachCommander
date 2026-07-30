---
title: Attributen & machtigingen
slug: attributes-and-permissions
section: Krachtige hulpmiddelen
order: 96
related: [file-utilities]
---

Met Peach Commander kun je de metadata op laag niveau van bestanden en mappen inspecteren en wijzigen die Finder grotendeels buiten bereik houdt: POSIX-lees-/schrijf-/uitvoermachtigingen, de eigenaar en groep, de gewijzigde en aangemaakte datums, macOS-vlaggen zoals verborgen en vergrendeld, en uitgebreide attributen. Je kunt ook de toegangsbeheerlijst (ACL) van een bestand bewerken voor fijnmazige regels per gebruiker of per groep, koppelingen en aliassen maken die naar andere items verwijzen, en je eigen opmerkingen toevoegen. Deze hulpmiddelen zijn gericht op ervaren gebruikers die precieze controle nodig hebben over hoe items zich gedragen en wie ze mag aanraken.

## Attributen wijzigen

1. Selecteer een of meer items in het actieve paneel.
2. Kies **Bestand > Attributen wijzigen…**.
3. Stel in wat je nodig hebt: wissel de lees-/schrijf-/uitvoervakjes voor eigenaar, groep en iedereen (of typ direct een octale waarde), wijzig de eigenaar of groep, wissel de vlaggen verborgen of vergrendeld, en stel de gewijzigde of aangemaakte datum in. Gebruik **Huidige gebruiken** voor de huidige tijd, of kopieer een datum van een ander bestand.
4. Om dezelfde wijziging door de inhoud van een map toe te passen, zet je de recursieve optie aan en kies je of deze bestanden, mappen of beide beïnvloedt.
5. Klik op OK om de wijziging uit te voeren. Recursieve wijzigingen draaien als achtergrondtaak met een voortgangsbalk.

![Venster Attributen wijzigen met het machtigingenraster, vlaggen en datumvelden](screenshots/attributes-dialog.png)
*(Afbeelding: Het venster Attributen wijzigen. Gemengde waarden over een selectie van meerdere bestanden worden als een streepje getoond totdat je ze instelt.)*

## Een ACL bewerken

Voor regels die verder gaan dan het basismodel eigenaar/groep/iedereen bewerk je de toegangsbeheerlijst van het item.

1. Open **Bestand > Attributen wijzigen…** en open van daaruit de ACL-editor.
2. Elke rij is één regel: de gebruiker of groep waarop deze van toepassing is, of deze toestaat of weigert, en welke machtigingen (lezen, schrijven, verwijderen enzovoort) deze verleent.
3. Voeg rijen toe, verwijder of bewerk ze, en bewaar vervolgens om de lijst terug naar het item te schrijven.

## Koppelingen, aliassen en opmerkingen maken

- **Bestand > Symbolische koppeling maken…** maakt een symbolische koppeling (symlink) die via het pad naar het item onder de cursor verwijst.
- **Bestand > Harde koppeling maken…** maakt een harde koppeling naar dezelfde bestandsgegevens. Harde koppelingen werken alleen voor bestanden op hetzelfde volume.
- **Bestand > Alias maken…** maakt een macOS-alias die Finder ook kan volgen.
- **Bestand > Opmerking bewerken…** (Ctrl+Z) opent een teksteditor voor een opmerking per bestand. Opmerkingen kunnen in hun eigen kolom en in statustips worden getoond.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Opmerking bewerken | Ctrl+Z |

## Opmerkingen

- Het wijzigen van de eigenaar of groep vereist meestal privileges die je als normale gebruiker niet hebt; wanneer dat gebeurt, wordt de wijziging als mislukt gerapporteerd in plaats van toegepast, en gaan de rest van je wijzigingen alsnog door.
- Opmerkingen worden opgeslagen in een `descript.ion`-bestand naast je items en kunnen, afhankelijk van je instellingen, ook als Finder-opmerkingen worden bewaard. Beide worden gelezen bij het weergeven van een opmerking.
- Een symbolische koppeling en een alias verwijzen beide naar een doel, maar een symbolische koppeling slaat een gewoon pad op terwijl een alias een macOS-verwijzing opslaat die blijft werken als het doel wordt verplaatst of hernoemd. Een harde koppeling is een tweede naam voor dezelfde bestandsgegevens, geen verwijzing.
