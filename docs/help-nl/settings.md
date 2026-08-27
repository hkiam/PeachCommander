---
title: Instellingen
slug: settings
section: Aanpassen
order: 116
related: [appearance, keyboard-shortcuts]
---

Het instellingenvenster is waar je Peach Commander afstemt op jouw werkwijze: welke balken verschijnen, hoe bestanden worden getoond, hoe kopieer- en verwijderbewerkingen zich gedragen, het archiefformaat dat wordt gebruikt bij inpakken, tabbladgedrag, FTP-standaarden, de weergavetaal en meer. Instellingen zijn gegroepeerd in pagina's zodat je een optie snel vindt, en elke wijziging wordt automatisch opgeslagen in je persoonlijke configuratiemap.

## Instellingen openen

1. Kies **Peach Commander > Instellingen…**, of druk op Cmd+, (komma).
2. Je kunt hetzelfde venster ook openen via **Configuratie > Opties…**.
3. Kies een pagina uit de lijst links; de opties voor die pagina verschijnen rechts.
4. Pas de regelaars aan. Wijzigingen werken meteen, tenzij een opmerking op de pagina anders vermeldt.
5. Wil je direct naar een optie, typ dan in het zoekveld boven aan het venster. Overeenkomende instellingen uit *alle* pagina's worden vermeld met de pagina waar ze staan, en als je er een kiest, opent die pagina met de instelling gemarkeerd. ↑/↓ lopen door de resultaten, Return opent de gemarkeerde, en Esc verlaat de zoekopdracht en zet de pagina terug waar je vandaan kwam.

![Het instellingenvenster met de pagina Lay-out en aankruisvakken voor de interfacebalken](screenshots/settings-layout.png)
*(Afbeelding: De pagina Lay-out bepaalt welke balken rond de panelen worden getoond.)*

## De pagina's

Het venster heeft deze pagina's, op volgorde:

- **Lay-out** — toon of verberg de schijvenbalk, tabbalk, padbalk en statusbalk, en kies welke pagina's het zijpaneel aanbiedt.
- **Weergave** — hoe bestanden en mappen worden weergegeven, inclusief de datumnotatie.
- **Symbolen** — het uiterlijk van symbolen in de bestandslijsten.
- **Bediening** — algemeen gedrag, zoals wat er gebeurt als je in een paneel typt (snelzoeken versus de opdrachtregel).
- **Kleuren** — aangepaste paneelkleuren, of laat ze het huidige thema volgen.
- **Bevestiging** — welke acties eerst om bevestiging vragen, zoals verwijderen.
- **Bewerken/Bekijken** — of bewaren in de editor een `.bak`-back-upkopie houdt, de programma's om bestanden te bewerken en te bekijken, en koppelingen per type.
- **Kopiëren/Verwijderen** — bestandsmetadata behouden, snel klonen, alleen nieuwere bestanden kopiëren, controleren na kopiëren, verwijderingen naar de prullenmand sturen, en een optionele snelheidslimiet instellen.
- **Zip/Inpakken** — het standaard archiefformaat en compressieniveau bij inpakken.
- **Plug-ins** — schakel geïnstalleerde plug-ins in of uit.
- **Tabbladen** — hoe maptabbladen openen en zich gedragen.
- **FTP** — netwerkstandaarden zoals het keep-alive-interval.
- **Toetsenbord** — bekijk en wijzig sneltoetsen.
- **Taal** — kies Systeemstandaard, English of Deutsch.
- **AI** — configureer de AI-assistent: voorkeursmodel, cloud-eindpunt en sleutel, autonomie en de optionele MCP-server (zie [AI Assistant](ai-assistant.md)).
- **Overig** — open je configuratiemap in de Finder.

Ingeschakelde plug-ins kunnen na de ingebouwde pagina's hun eigen pagina toevoegen — bijvoorbeeld **Disk Map** en **System Monitor** — zodat hun opties in hetzelfde venster staan (zie [Plug-ins](plugins.md)).

![Het instellingenvenster met de pagina Weergave en opties voor hoe bestanden worden getoond](screenshots/settings-display.png)
*(Afbeelding: De pagina Weergave bepaalt hoe bestanden en mappen worden weergegeven.)*

![Het instellingenvenster met de pagina Bediening](screenshots/settings-operation.png)
*(Afbeelding: De pagina Bediening regelt snelzoeken en muisgedrag.)*

## Waar je instellingen worden bewaard

Je configuratie wordt bewaard in platte-tekstbestanden in je persoonlijke Application Support-map, op `~/Library/Application Support/PeachCommander`. Ga naar de pagina **Overig** en klik op **Open configuratiemap** om deze te openen. Opgeslagen FTP-wachtwoorden staan niet in deze bestanden; ze worden veilig bewaard in de macOS-sleutelhanger.

Instellingen worden weggeschreven terwijl je ze wijzigt. Je kunt ook op elk moment forceren op te slaan met **Configuratie > Instellingen bewaren**, en de huidige vensterpositie en paneellay-out opslaan met **Configuratie > Positie bewaren**.

## Instellingen overnemen uit Total Commander

Als je overstapt van Total Commander op Windows, kun je je opgeslagen FTP-sites importeren. Kies **Configuratie > wincmd.ini importeren…** en selecteer je Total Commander FTP-configuratiebestand. Je verbindingen worden in dezelfde volgorde als daar aan Peach Commander toegevoegd.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Instellingen openen | Cmd+, |

## Opmerkingen

- De pagina **Taal** biedt Systeemstandaard, English en Deutsch. Een taalwijziging werkt pas nadat je Peach Commander opnieuw start.
- Kleuren die je op de pagina **Kleuren** instelt, overschrijven het thema; gebruik daar **Herstel standaardwaarden** om terug te keren naar de themakleuren.
- Peach Commander bewaart zijn instellingen alleen in zijn eigen configuratiemap, zodat je wijzigingen nooit andere apps beïnvloeden en eenvoudig te back-uppen zijn door die map te kopiëren.
