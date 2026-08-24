---
title: Markdown en HTML in de viewer
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Druk op F3 op een `.md`- of `.html`-bestand en het verschijnt opgemaakt in plaats van als broncode: koppen, lijsten, tabellen, koppelingen, takenlijsten en codeblokken gekleurd per taal. Diagrammen die als ` ```mermaid `-blok zijn geschreven worden getekend, en wiskunde tussen dollartekens wordt gezet.

Dit is een plugin. Alles op deze pagina komt van **Markdown and HTML**, dat u kunt uitschakelen in **Configuratie ▸ Plugins…** — verderop staat wat er dan verandert.

## Waar de opgemaakte weergave verschijnt

- **De viewer (F3).** De opgemaakte pagina. Het menu **Weergave** biedt nog steeds Tekst, Code en Hex, dus de broncode is één klik weg, en de naam van de plugin staat ook in die lijst.
- **Quick View (Ctrl+Q) en de infopagina** van het zijpaneel tonen dezelfde weergave, zodat een voorbeeld en een volledige weergave van hetzelfde bestand elkaar nooit tegenspreken.
- **De galerij** toont een kleine afbeelding van het begin van een Markdown-bestand in plaats van een algemeen documentpictogram.
- **Quick Look (Cmd+Y)** is het eigen voorbeeld van macOS en wordt *niet* beïnvloed — dat paneel is van het systeem, en geen plugin kan daarin tekenen.

## Het symbooloverzicht

Druk op **Symbolen** in de viewer voor de koppen van het document, genest zoals ze geschreven zijn, en klik er een aan om er in de pagina naartoe te springen. Het werkt in de opgemaakte weergave en in de broncode, en beide zijn het erover eens waar een kop staat.

## Diagrammen en wiskunde

Een codeblok met de taal `mermaid` wordt een diagram; `$…$` en `$$…$$` worden gezette wiskunde. Beide worden **op uw Mac** getekend, door onderdelen die in de plugin worden meegeleverd — er wordt niets gedownload, en geen deel van uw document wordt ergens naartoe gestuurd. Een dollarteken in een codeblok of in inline code blijft een dollarteken.

Een document zonder diagram en zonder formule laadt geen van beide onderdelen, dus een gewone README kost niets extra. Een diagram dat niet gelezen kan worden toont de fout waar het blok stond, met de tekst van het blok eronder, in plaats van te verdwijnen.

Beide kunnen apart worden uitgeschakeld in **Configuratie ▸ Instellingen ▸ Markdown**, waar ook staat welke versie in gebruik is en waar die vandaan komt.

## Uw eigen versie

Hebt u een nieuwere of andere versie van Mermaid of KaTeX nodig, zet die dan in de map die de knop **Engine Folder…** opent; die wordt dan gebruikt in plaats van de meegeleverde. De bestandsnamen zijn `mermaid.min.js`, `katex.min.js`, `katex.min.css` en `auto-render.min.js`. Er wordt nooit iets van internet voor u gehaald.

## Wat de opgemaakte pagina niet doet

De opgemaakte pagina is opzettelijk afgeschermd, want een Markdown-bestand is inhoud die van elders komt:

- **Hij laadt niets via het netwerk.** Een afbeelding waarvan het adres met `http` begint blijft met opzet leeg: die ophalen zou die server vertellen wanneer u het bestand opende, en van welk adres. Een afbeelding die naast het document op de schijf staat wordt gewoon geladen.
- **Scripts en HTML van het document worden nooit uitgevoerd.** HTML die in een Markdown-bestand staat wordt als tekst getoond, en een `.html`-bestand wordt weergegeven met scripts uitgeschakeld.

## Uitschakelen

Schakel de plugin uit in **Configuratie ▸ Plugins…** en `.md`- en `.html`-bestanden openen als tekst. Het overzicht blijft werken, de syntaxiskleuring blijft werken, en verder verandert er niets — de opgemaakte weergave wordt simpelweg niet meer aangeboden. Hetzelfde geldt als u op de instellingenpagina van de plugin alleen de opgemaakte weergave uitschakelt.

## Grenzen

- Bestanden boven een groottelimiet (standaard 8 MB, op de instellingenpagina) openen als tekst. Een zeer groot gegenereerd document in een opgemaakte pagina veranderen is langzaam, en de tekstviewer opent het meteen.
- De opgemaakte pagina kan niet worden bewerkt. Gebruik daarvoor F4, of de weergave Tekst voor **Opmaken**, **Codering** en **Ga naar**, die voor broncode gelden en niet voor een gerenderde pagina.
