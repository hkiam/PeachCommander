---
title: AI-assistent
slug: ai-assistant
section: Plug-ins
order: 122
related: [plugins, settings, privacy-and-security]
---

De AI-assistent is een optionele, verwijderbare plug-in die je helpt in gewone taal met je bestanden te werken. Hij kan een document samenvatten of uitleggen, een betere bestandsnaam voorstellen, tekst vertalen of proeflezen, gegevens in een tabel zetten en zelfs een map ordenen — en hij kan bestandsacties voor je uitvoeren nadat hij je eerst een plan heeft getoond. Hij draait op het apparaat met Apple Intelligence indien beschikbaar, of je kunt hem naar een cloudmodel laten wijzen. Omdat het een plug-in is, kun je hem volledig uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## De assistent openen

Kies **Opdrachten ▸ AI Assistant** om de assistent te tonen in een vastgezet paneel aan de rechterkant van het venster. Typ een verzoek en druk op Return; de assistent kan bestanden lezen, dingen opzoeken en — met jouw bevestiging — wijzigingen aanbrengen.

![De AI-assistentchat vastgezet naast de bestandspanelen](screenshots/ai-chat.png)
*(Afbeelding: De AI-assistent, rechts vastgezet, werkt aan een verzoek.)*

## Rechtsklikacties (AI ▸)

De snelste manier om de assistent te gebruiken is het **AI ▸**-submenu in het rechtsklikmenu:

- **Op een bestand** — Samenvatten, Uitleggen, Naam voorstellen, Vertalen naar Engels, Proeflezen, Taken detecteren en Tabel maken.
- **Op de paneelachtergrond** — Deze map ordenen en Waarschijnlijke duplicaten vinden.

Elke **AI ▸**-actie opent zijn **eigen chat met titel** (bijvoorbeeld *Samenvatten – report.txt*), zodat verschillende taken gescheiden blijven in plaats van op te stapelen in één lang gesprek. Wanneer je zelf in het invoerveld typt, gaat dat verzoek verder in de huidige chat.

## Je chats beheren

- Gebruik de chatwisselaar boven in het paneel om tussen gesprekken te schakelen.
- Het menu **Verwijder ▾** biedt **Deze chat verwijderen** en **Alle chats verwijderen**, zodat je alles in één keer kunt wissen als de lijst lang wordt. Lege chats worden automatisch opgeruimd wanneer je het paneel sluit.

## Wijzigingen worden eerst bevestigd

Voor alles wat bestanden wijzigt — verplaatsen, hernoemen, schrijven, verwijderen — toont de assistent een **plan en wacht op jouw bevestiging** voordat hij handelt. Je kunt dit in Instellingen wijzigen door de autonomie van de assistent te verhogen, of deze naar alleen-lezen verlagen zodat hij nooit iets wijzigt.

## Instellingen

Open **Configuratie ▸ Instellingen ▸ AI** om de assistent op één pagina te configureren:

- **Voorkeursmodel** — Automatisch (cloud indien geconfigureerd, anders op het apparaat), Op het apparaat (Apple Intelligence) of Cloud.
- **Cloud-eindpunt, model en API-sleutel** — om een OpenAI-compatibel model te gebruiken in plaats van dat op het apparaat. De sleutel wordt bewaard in de macOS-sleutelhanger, nooit in je configuratiebestanden.
- **Autonomie van de assistent** — alleen-lezen, wijzigingen bevestigen (de standaard) of autonoom.
- **Aangepaste systeemprompt** — optionele instructies die bepalen hoe de assistent antwoordt.
- **MCP-server** — een optionele, uitsluitend lokale server waarmee een externe agent de app kan aansturen; standaard uit en met een token te beschermen.

![De AI-pagina in Instellingen met de opties voor autonomie en de MCP-server](screenshots/settings-ai.png)
*(Afbeelding: Alle assistentopties staan op één AI-pagina in Instellingen.)*

## Privacy

- Met Apple Intelligence draait de assistent **op je Mac**; er verlaat niets het apparaat.
- Een cloudmodel wordt **alleen gebruikt als je er een configureert**, en de API-sleutel blijft in de sleutelhanger.
- Bestandswijzigende acties worden bevestigd voordat ze worden uitgevoerd, tenzij je het autonomieniveau bewust verhoogt.
