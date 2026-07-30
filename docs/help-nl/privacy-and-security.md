---
title: Privacy en beveiliging
slug: privacy-and-security
section: macOS en privacy
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander is gebouwd om je niet in de weg te zitten en je gegevens op je Mac te houden. Wachtwoorden worden aan de macOS-sleutelhanger overgedragen, crashinformatie verlaat je computer nooit zonder jouw toestemming, en de app verzamelt geen gebruiksstatistieken. Dit onderwerp legt uit waar je gevoelige gegevens staan en hoe je de ene systeemtoestemming verleent die een bestandsbeheerder nodig heeft om zijn werk te doen.

## Waar wachtwoorden worden bewaard

Elk wachtwoord of sleutelwachtwoord dat je bewaart — voor een FTP- of SFTP-verbinding, of om een met wachtwoord beveiligd archief te openen — wordt weggeschreven naar de macOS-**sleutelhanger**, dezelfde beveiligde opslag die het systeem gebruikt voor je wifi- en website-aanmeldingen. Wachtwoorden worden nooit als platte tekst in de eigen instellingen of verbindingsbestanden van Peach Commander geschreven.

1. Kies bij het bewaren van een verbindings- of archiefwachtwoord de optie om het te onthouden.
2. Het wachtwoord wordt opgeslagen in je aanmeldsleutelhanger, beschermd door je account.
3. Om een bewaard wachtwoord later te bekijken of te verwijderen, open je de app **Sleutelhangertoegang** (in Programma's ▸ Hulpprogramma's) en zoek je op de verbindingsnaam.

## Volledige schijftoegang verlenen

macOS houdt sommige locaties privé — Mail, Berichten en de gegevens van andere apps in je Bibliotheek-map — totdat je expliciet toegang geeft. Omdat een bestandsbeheerder bij elk bestand hoort te kunnen, vraagt Peach Commander om **Volledige schijftoegang**. De app blijft werken met beperkte toegang totdat je die verleent; je ziet die beschermde mappen dan alleen niet.

1. Kies **Opdrachten ▸ Volledige schijftoegang…**, of klik op **Open Systeeminstellingen** wanneer de app aanbiedt je bij het starten te begeleiden.
2. Zet in **Systeeminstellingen ▸ Privacy en beveiliging ▸ Volledige schijftoegang** de schakelaar naast Peach Commander aan.
3. Herstart de app als daarom wordt gevraagd.

## Crashrapporten blijven lokaal

Als de app onverwacht stopt, schrijft macOS een crashrapport naar je eigen diagnostiekmap. Bij de volgende start merkt Peach Commander dit op en biedt aan je te helpen een foutrapport in te dienen — maar alleen met jouw toestemming.

- Je kunt **Toon in Finder** kiezen om het rapport te zien, of **Kopieer rapport naar klembord** om het zelf in een foutrapport te plakken.
- Er wordt nooit iets automatisch verzonden, en er is geen crashrapportagedienst van derden bij betrokken.

## Opmerkingen

- **Geen telemetrie.** Peach Commander volgt je activiteit niet en stuurt nergens gebruiksstatistieken heen.
- **Beperkte toegang is veilig.** Sla je Volledige schijftoegang over, dan bladert en beheert de app nog steeds de bestanden die je normaal kunt zien; alleen systeembeschermde locaties blijven verborgen.
- **Jij beheert bewaarde wachtwoorden.** Omdat inloggegevens in de sleutelhanger staan, beheer en herroep je ze met standaard macOS-hulpmiddelen in plaats van in de app.
