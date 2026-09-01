---
title: Voorvertoning van bestanden die niet op deze Mac staan
slug: remote-previews
section: Bekijken en bewerken
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander toont een voorvertoning van het bestand onder de cursor in het informatiezijpaneel, in Quick View en als miniaturen in de galerijweergave. Als dat bestand niet op een schijf van deze Mac staat, kost het tonen ervan iets echts — een download, een uitpakactie of allebei — en niemand heeft erom gevraagd: de cursor is er alleen maar op gaan staan. Peach Commander bepaalt daarom vooraf wat een voorvertoning mag kosten; deze pagina legt uit wat het bepaalt en hoe u dat verandert.

## Bestanden in een archief

Een bestand in een archief kunt u net zo voorvertonen als een bestand daarbuiten. Peach Commander pakt het op de achtergrond uit naar een tijdelijke kopie en toont die. Hetzelfde geldt voor Quick Look, voor openen in een ander programma met Enter of een dubbelklik, en voor het submenu Openen met.

Wat een ander programma krijgt is een kopie, en die is alleen-lezen: wat u daar wijzigt wordt niet terug in het archief geschreven. Peach Commander zegt dat de eerste keer, met een vakje om het niet meer te zeggen. Wilt u een bestand bewerken dat in een archief zit, pak het dan eerst uit met F5 en werk met het uitgepakte bestand.

## Wat een voorvertoning mag kosten

Een voorvertoning volgt de cursor en gebeurt dus ongevraagd. Daarom geldt er een budget dat afhangt van waar de inhoud van het bestand werkelijk staat:

- Op een schijf van deze Mac is er geen grens, en voorvertoningen gedragen zich precies zoals altijd.
- Op een netwerklocatie — een gekoppelde share, FTP, SFTP, Amazon S3 of een pluginschijf — worden bestanden tot 4 MB voorvertoond, zolang Peach Commander nog niet heeft gemeten hoe snel die verbinding echt is. Daarna is alles toegestaan wat het in ongeveer anderhalve seconde kan lezen, zodat een snelle share grote bestanden toont en een trage kleine bestanden weigert.
- In een archief wordt een bestand voor de voorvertoning tot 32 MB uitgepakt.
- Een bestand dat een clouddienst nog niet naar deze Mac heeft gedownload wordt nooit opgehaald alleen omdat de cursor erop is komen te staan.
- In archiefformaten die bestand voor bestand moeten worden uitgepakt — CPIO, ISO, CAB, LZH en dergelijke — wordt niets automatisch voorvertoond, omdat elk afzonderlijk bestand een volledige gang door het archief kost.

Een geweigerde voorvertoning is geen leeg paneel: het zijpaneel toont het symbool van het bestand, de naam, de grootte en de datum, plus één regel met de reden. Quick Look toont het toch en is aan geen van deze grenzen gebonden.

## De grenzen wijzigen

1. Open Instellingen ▸ Bewerken/Bekijken.
2. Zet “Bestanden op netwerklocaties automatisch voorvertonen” uit om netwerkvoorvertoningen helemaal te stoppen, of zet “Netwerkbestanden tot (MB)” op de gewenste grootte.
3. Zet “Bestanden uit de cloud downloaden voor een voorvertoning” aan als u de voorvertoning liever hebt dan het bespaarde verkeer.
4. Stel “Uit archieven uitpakken tot (MB)” in voor hoe groot een bestand in een archief mag zijn.

Twee andere instellingen hebben geen eigen bedieningselement en staan in `peachcmd.ini` onder `[Preview]`: `AutoPreviewSeconds` is het tijdbudget dat geldt zodra een verbinding is gemeten (standaard 1,5; 0 schakelt het uit), en `AutoPreviewLocalMB` is een bovengrens voor lokale schijven (0 betekent geen grens).

## Waar de uitgepakte kopieën blijven

Kopieën worden naar de tijdelijke map van het systeem geschreven, en de voorvertoningen delen ze in plaats van elk een eigen kopie te maken. Een kopie voor een voorvertoning wordt verwijderd zodra u het archief verlaat; een kopie die aan een ander programma is gegeven blijft tot u Peach Commander afsluit, omdat dat programma hem nog open heeft. Wat een onverwacht afsluiten achterlaat wordt bij de volgende start herkend en dan opgeruimd.

Miniaturen in de galerijweergave volgen hetzelfde budget, en bestanden in een archief houden daar hun algemene symbool in plaats van een miniatuur.
