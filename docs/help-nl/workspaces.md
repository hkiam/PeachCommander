---
title: Werkruimtes
slug: workspaces
section: Aanpassen
order: 118
related: [settings, panels-and-tabs]
---

Een werkruimte is een benoemde context waarin u werkt: “Back-ups opruimen”, “Sollicitatiestukken sorteren”. Elke werkruimte onthoudt beide panelen, alle geopende tabbladen, welk tabblad aan welke kant actief is, de weergavemodus, de mappenboom, de vooruit/terug-geschiedenis en welke bestanden u had gemarkeerd, het snelfilter en de indeling van het venster — het zijpaneel, het dok, de balken en de plek van de scheiding. Wisselen kost één klik, en onderweg gaat er nooit iets verloren — een werkruimte wordt nooit bewaard, omdat ze nooit eindigt.

Tot u een tweede aanmaakt, is er niets te zien. Geen balk, geen menu, geen sneltoetsen.

## Zo werkt het

1. Richt beide panelen in voor de taak die voorligt: open de mappen, voeg de tabbladen toe, kies de weergave die u wilt.
2. Open het menu **Ga** en kies **Werkruimten…**, daarna **Nieuwe werkruimte…**. Geef haar een naam.
3. Boven in het venster verschijnt een strook gekleurde chips, en in de menubalk verschijnt het menu **Werkruimte**. De nieuwe werkruimte begint als kopie van de indeling waarin u zat.
4. Richt de nieuwe werkruimte in voor haar eigen taak. De werkruimte waaruit u kwam, behoudt wat ze had.
5. Klik op een chip om te wisselen, of druk op **Ctrl+1** tot **Ctrl+9**. Alles wisselt mee.

## Terug naar een beginpunt

Elke werkruimte onthoudt ook de indeling waarmee ze is opgezet. **Werkruimte ▸ Huidige staat in werkruimte bewaren** (Cmd+Ctrl+S) maakt de huidige indeling tot dat beginpunt, en **Terug naar bewaarde staat** brengt u er na een middag dwalen weer heen.

Dat staat los van het voortdurende onthouden: u hoeft nooit te bewaren om uw plek niet kwijt te raken.

## De verzamelbak

Elke werkruimte heeft een bak — voor wat er tijdens het opruimen werkelijk gebeurt: drie mappen diep in
de back-ups vindt u iets dat bij een heel ander karwei hoort. **Sleep bestanden naar de chip van een
andere werkruimte** en ze belanden in *diens* bak — u schakelt niet, en er wordt niets gekopieerd of
verplaatst; de teller op de chip loopt op en u gaat verder. Houd bij het neerzetten **⌥** ingedrukt om
in plaats daarvan naar die map te kopiëren, of **⌘** om te verplaatsen. **Ctrl+Cmd+A** legt de selectie
in de bak van de huidige werkruimte, de pagina **Verzamelbak** in het zijpaneel toont de inhoud, en
**Werkruimte ▸ Verzamelbak naar het andere paneel kopiëren** doet de hele bak in één bewerking.

Sindsdien verwijderde bestanden, of bestanden op een niet-aangekoppeld volume, worden als ontbrekend
getoond in plaats van verwijderd, en een bulkbewerking biedt aan ze over te slaan of eerst uit de bak te
halen. Een verplaatsing haalt het verplaatste eruit; een kopie laat hem zoals hij was.

| Actie | Sneltoets |
| --- | --- |
| Naar werkruimte 1 tot 9 schakelen | Ctrl+1 … Ctrl+9 |
| De huidige indeling het beginpunt maken | Cmd+Ctrl+S |

## Tips

- Klik met de rechtermuisknop op een chip om haar te hernoemen, een kleur te geven of te verwijderen — of klik op de **✕** aan de rechterkant, die de werkruimte na een bevestiging verwijdert. De kleur is waaraan u werkruimten in één oogopslag herkent wanneer het venster smal is en de namen niet meer passen.
- Negen is het maximum, zodat elke chip herkenbaar blijft.
- **Weergave ▸ Werkruimtebalk tonen** verbergt de strook zonder de functie uit te schakelen, voor wie met het toetsenbord tussen werkruimten wisselt.
- Werkruimten kunnen bij **Instellingen ▸ Tabbladen** helemaal worden uitgeschakeld. Uw werkruimten blijven bewaard en komen ongewijzigd terug wanneer u de functie weer inschakelt.

## Een werkruimte tot een map beperken

Een werkruimte kan te horen krijgen waar zij over gaat, en controleert dan voordat een bewerking
daarbuiten reikt. Klik met de rechtermuisknop op haar chip, **Tot map beperken ▸ Op de actieve map
instellen**, en kies of bewerkingen erbuiten toegestaan zijn, bevraagd worden of geweigerd.

Er wordt gecontroleerd voordat een verwijdering bestanden van buiten neemt, voordat een kopie of
verplaatsing erbuiten landt, en voordat een hernoeming of nieuwe map erbuiten schrijft. **Navigeren
wordt nooit beperkt** — een bestandsbeheerder die weigert een map te tonen is stuk, en de waarde zit
volledig in het moment vóór F8. Bewaringen in de editor vallen er ook buiten; die gebeuren in hun eigen
venster.

## Het journaal

Elke werkruimte houdt bij wat erin is gedaan — bezochte mappen, uitgevoerde bewerkingen, ingetypte
shell-regels, en alles wat een mapbeperking heeft geweigerd. **Werkruimte ▸ Journaal…** toont het,
nieuwste dag eerst, met een filter **Problemen** voor alles wat mislukte of werd tegengehouden.

Return herhaalt de geselecteerde regel, onder dezelfde regel als de geschiedenis: alleen een kopie of
verplaatsing is met één toetsaanslag te herhalen, en een shell-regel wordt in de opdrachtregel gezet in
plaats van uitgevoerd. Het journaal staat bewust los van de globale geschiedenis — die beantwoordt
"waar kom ik meestal" en rangschikt op frequentie; dit beantwoordt "wat is hier gebeurd" en behoudt de
volgorde. Het wordt met zijn werkruimte verwijderd, blijft anders onbeperkt bewaard, en is uit te
schakelen bij **Instellingen ▸ Tabbladen**.

## Een werkruimte doorgeven

**Werkruimte ▸ Werkruimte exporteren…** schrijft de huidige werkruimte naar een `.pcworkspace`-bestand
dat u iemand kunt sturen of in een projectmap kunt bewaren. **Werkruimte importeren…** leest het weer
in, en dubbelklikken in de Finder ook.

Wat meegaat is het **bewaarde beginpunt** van de werkruimte — druk eerst op ⌘⌃S als u de indeling
wilt die u nu voor u hebt — samen met de naam, de kleur, de mapgrens en de verzamelbak. Mappen binnen
uw thuismap worden verkort geschreven, zodat het bestand opengaat in de thuismap van de *ander* en
niet in een map met uw naam erin.

Wat bewust niet meegaat:

- **Alles wat een inloggegeven zou kunnen zijn.** Tabbladen die naar een verbinding of een gekoppelde plug-inschijf wijzen, worden bij het exporteren verwijderd, en het verslag noemt het aantal. Er is niets te verliezen, want over een verbinding wordt niets opgeschreven.
- **Het journaal.** Het houdt bij wat *u* hebt gedaan en noemt mappen op uw machine. Het blijft hier.
- Cursorposities, de ongedaan-maken-geschiedenis, de venstergrootte en open weergave-, bewerk-, zoek- of synchronisatievensters.
- Terminaltabbladen en gesprekken met de assistent. Die horen bij deze Mac; een werkruimtebestand draagt *waar* gewerkt wordt, niet wat er draait.

Een import **voegt** altijd een werkruimte toe; hij vervangt nooit die waarin u zit en wisselt nooit
uit zichzelf — een bestand dat iemand stuurde hoort uw venster niet te verzetten. Mappen die niet op
deze Mac staan gaan open op de dichtstbijzijnde die er wel is, items in de verzamelbak houden hun
paden en staan grijs, en een mapgrens waarvan de map ontbreekt blijft bestaan maar vraagt in plaats
van te weigeren. Een verslag noemt dat allemaal.

## Opmerkingen

- Wisselen vraagt nooit of er bewaard moet worden en sluit nooit iets. Lopende bestandsbewerkingen lopen door, en alles in een terminal eveneens: de tabbladen van de werkruimte die u verlaat worden opzijgezet met levende shells, niet afgesloten. Ook de gesprekken van de assistent volgen de werkruimte.
- Ongedaan maken volgt een werkruimte alleen zolang de app draait: een stap draagt de handeling die hem terugdraait, en die kan niet naar schijf worden geschreven.
- Een werkruimte legt maplocaties vast, niet de bestanden erin. Is een bewaarde map verplaatst of verwijderd, dan opent dat tabblad in de dichtstbijzijnde map die nog bestaat.
- Bij het opwaarderen van een eerdere versie: werkruimten die u eerder had bewaard worden chips, en de sessie waarin u zat wordt de eerste. Er gaat niets verloren, en de oude `workspaces.ini` blijft behouden als `workspaces.ini.migrated`.
