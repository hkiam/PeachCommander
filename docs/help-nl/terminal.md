---
title: De ingebouwde terminal
slug: terminal
section: Plug-ins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander kan een echte shell in zijn eigen venster draaien, in een strook onderaan die het dock heet. Het is uw login-shell — die `$SHELL` aanwijst, of `/bin/zsh` als die niet bruikbaar is — dus uw `PATH`, uw aliassen en uw functies zijn er allemaal, precies als in Terminal.

Dit is niet hetzelfde als **Open Terminal hier**, dat Apple's Terminal-app in de huidige map start en u met twee vensters achterlaat. De ingebouwde blijft waar uw bestanden zijn, en weet ervan.

Het is een plug-in: wilt u hem niet, schakel hem dan uit of verwijder hem via **Configuratie ▸ Plug-ins…**, en het dock gaat mee.

## Openen en verplaatsen

Druk op **Ctrl** samen met de toets links van de ‘1’ om het toetsenbord tussen het bestandspaneel en de terminal te verplaatsen. Die sneltoets is aan de *positie* van de toets gebonden, niet aan het teken, dus het is dezelfde fysieke toets hoe uw indeling hem ook noemt: het accent grave op een US-toetsenbord, `^` op een Duits, `@` op een Frans.

De rest staat in het menu **Terminal**:

| Actie | Wat het doet |
| --- | --- |
| Terminal tonen | Klapt hem in en weer uit; de tabbladen en wat erin draait blijven zoals ze zijn |
| Wisselen tussen paneel en terminal | Verplaatst de toetsenbordfocus, zonder verder iets te veranderen |
| Nieuw terminaltabblad | Nog een shell, in dezelfde map |
| Sluit het terminaltabblad | Sluit hem — en vraagt eerst of er nog iets in draait |
| Terminal splitsen | Twee shells naast elkaar in hetzelfde tabblad |
| Ga naar de map van het paneel | Doet `cd` naar waar het actieve paneel staat |
| Voeg de geselecteerde bestandsnamen in | Typt de geselecteerde namen op de prompt, tussen aanhalingstekens |
| Voer de opdrachtregel uit in de terminal | Stuurt wat u op de opdrachtregel typte naar de shell in plaats van het onzichtbaar uit te voeren |

Zolang de terminal de focus heeft, gaan de **functietoetsen daarheen**, niet naar het bestandspaneel — F5 in een teksteditor binnen de terminal moet de editor bereiken. De functietoetsenbalk zegt dat, in plaats van toetsen te tonen die niets doen.

## De brug terug naar het paneel

**Cmd-klik op een pad** in de uitvoer van de terminal en het paneel gaat erheen. Een bestand uit `ls`, een pad in een compilerfout, een naam uit `git status` — één klik en u kijkt ernaar.

Het werkt alleen als het woord onder de aanwijzer echt naar iets bestaands verwijst. Een Cmd-klik op gewone tekst doet niets in plaats van ergens willekeurig heen te navigeren, en een gewone klik selecteert tekst nog steeds zoals altijd.

**Sleep bestanden op de terminal** en hun paden komen op de prompt terecht, tussen aanhalingstekens, klaar voor een opdracht die u half getypt hebt.

## Het paneel de shell laten volgen

Standaard uit: als u in de terminal ergens heen `cd`t, blijft het paneel waar het is. Zet **Laat het actieve paneel de terminal volgen** aan op de instellingenpagina van de terminal en het volgt mee.

Daarvoor is de hulp van uw shell nodig, want een shell kondigt niet aan waar hij heen is gegaan. De instellingenpagina toont een kort fragment voor uw `~/.zshrc` en een knop om het te kopiëren; het laat zsh vóór elke prompt zijn werkmap melden (de OSC 7-escapereeks). Zonder dat fragment staat de instelling aan en volgt er niets — daarom staat het fragment er pal naast.

## Zoeken en terugbladeren

**Cmd+F** zoekt in wat de terminal heeft afgedrukt.

Een terminal bewaart standaard **5.000 regels** om in terug te bladeren — genoeg om door een build terug te scrollen. Aan te passen op de instellingenpagina. Zeer grote waarden worden begrensd, want een terugblader-buffer van vijftig miljoen regels is een geheugenprobleem waarvan de oorzaak van buitenaf niet te zien is.

## Waar hij zit

De terminal opent in het dock onderaan, want dat is de vorm die hij nodig heeft: een shell heeft breedte nodig, en het zijpaneel past op zijn standaard 300 punten ongeveer 44 kolommen waar de onderkant van een venster van 1200 punten er 176 past.

U kunt hem toch verplaatsen. Sleep hem naar het zijpaneel als dat u beter uitkomt, of gebruik de plaatsingsopties uit [Plug-ins](plugins.md); verplaatsen **hangt dezelfde shell om** in plaats van een nieuwe te starten, dus wat er draait blijft draaien. De opdrachten in het menu **Terminal** volgen hem: ze halen hem tevoorschijn waar hij is, in plaats van het dok te openen.

Tabbladen komen terug als u de app opnieuw start, in de mappen waar ze waren. Wat erin *draaide* niet — een herstart beëindigt die processen, zoals in elke terminal. Of hij open was toen u afsloot, komt ook terug.

## Bij afsluiten

De app sluiten sluit de shells. Wat er nog in draait wordt beëindigd, zoals het sluiten van een Terminal-venster beëindigt wat erin zit. Daarom vraagt het sluiten van een tabblad waarin iets draait eerst om bevestiging.
