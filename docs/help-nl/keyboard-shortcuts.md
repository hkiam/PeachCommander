---
title: Toetsenbord en sneltoetsen
slug: keyboard-shortcuts
section: Aanpassen
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander is gemaakt om vanaf het toetsenbord te bedienen. Het wordt geleverd met twee kant-en-klare sneltoetsschema's en laat je elke opdracht opnieuw toewijzen aan de toetsen die je verkiest. Kom je van een klassieke tweepaneels-bestandsbeheerder, dan kun je de toetsen behouden die je al kent; wil je liever vertrouwde Mac-combinaties, schakel dan met één klik over naar het macOS-schema. Een doorzoekbare commandobrowser laat je alles ontdekken wat de app kan en elke opdracht op naam uitvoeren.

## Van toetsenbordschema wisselen

1. Open **Instellingen** (Cmd+, of **Configuratie > Instellingen…**) en kies de pagina **Toetsenbord**.
2. Kies een schema in het menu **Schema**:
   - **Total Commander (klassiek)** (de standaard) behoudt de traditionele toetsen, met Ctrl-gebaseerde combinaties zoals Ctrl+R om een paneel te verversen.
   - **macOS** wijst dezelfde acties toe aan vertrouwde Mac-toetsen waar dat zinvol is, bijvoorbeeld Cmd+C om bestanden te kopiëren en Cmd+F om te zoeken.
3. De wijziging werkt meteen in de menu's en de sneltoetsbalk. **Sneltoetsen bewerken…** staat er direct onder, omdat losse toewijzingen boven op het schema komen dat je hebt gekozen.

## Sneltoetsen aanpassen

1. Kies **Configuratie > Sneltoetsen bewerken…**, of klik op **Sneltoetsen bewerken…** op de pagina Toetsenbord in Instellingen.
2. Zoek een opdracht met het zoekveld en selecteer de rij ervan.
3. Klik op **Opnemen…** en druk op de gewenste toetsencombinatie. Ze wordt meteen toegewezen.
4. Was die combinatie al door een andere opdracht in gebruik, dan meldt een bericht van welke opdracht ze is overgenomen.
5. Gebruik **Wis** om de sneltoets van een opdracht te verwijderen, of **Standaardwaarden herstellen** om al je wijzigingen te verwerpen en terug te keren naar de oorspronkelijke toetsen van het schema.

![De sneltoetseditor met opdrachten en hun toegewezen toetsen](screenshots/keys-editor.png)
*(Afbeelding: Zoek een opdracht en gebruik Opnemen, Wis of Standaardwaarden herstellen om de sneltoets te wijzigen.)*

## Alle opdrachten doorbladeren

1. Kies **Configuratie > Commandobrowser…**.
2. Typ in het zoekveld om te filteren op naam, categorie of beschrijving.
3. Dubbelklik op een opdracht, of selecteer hem en klik op **Voer uit**, om hem op het actieve paneel uit te voeren.

![De commandobrowser met een doorzoekbare lijst van opdrachten](screenshots/command-browser.png)
*(Afbeelding: Elke opdracht in één doorzoekbare lijst, met een korte beschrijving van elk.)*

## Sneltoetsen

| Actie | Menupad |
|---|---|
| Kies een schema | Instellingen > Toetsenbord > Schema |
| Sneltoetsen bewerken | Configuratie > Sneltoetsen bewerken… |
| Alle opdrachten doorbladeren | Configuratie > Commandobrowser… |
| Het actieve paneel verversen | F2 (ook Ctrl+R) |

## Opmerkingen

- Je aangepaste sneltoetsen worden automatisch bewaard en boven op het actieve schema gelegd. Van schema wisselen behoudt je persoonlijke overschrijvingen.
- Opdrachten die in de huidige context niet beschikbaar zijn, verschijnen gedimd in zowel de sneltoetseditor als de commandobrowser.
- Om de functietoetsen (F1–F12) rechtstreeks te gebruiken, zet je **Gebruik F1, F2, enz. als standaardfunctietoetsen** aan in Systeeminstellingen > Toetsenbord. Houd anders de **Fn**-toets samen met de functietoets ingedrukt.
