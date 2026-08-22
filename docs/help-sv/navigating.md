---
title: Navigera
slug: navigating
section: Kom igång
order: 14
related: [interface-overview, favorites]
---

Peach Commander visar två mappar sida vid sida, så det mesta av tiden går åt till att flytta en panel från mapp till mapp. Du kan öppna mappar, gå upp i hierarkin, spåra tillbaka var du har varit, skriva en sökväg direkt och hoppa rakt till vardagliga platser som Hem, Skrivbord och Hämtade filer. Varje åtgärd gäller den *aktiva* panelen — den med den markerade sökvägsraden.

## Öppna mappar och gå upp igen

1. Flytta markeringsraden med piltangenterna tills en mapp är markerad.
2. Tryck på **Enter** (eller dubbelklicka) för att öppna den. Detta går även in i arkiv och öppnar filer med deras standardapp.
3. Gå upp en nivå till den överordnade mappen med **Ctrl+PageUp** (eller **Backspace**).
4. För att hoppa till toppen av den aktuella enheten, välj **Gå ▸ Rot**.

## Gå bakåt och framåt

Peach Commander kommer ihåg de mappar du har besökt i varje panel, precis som en webbläsare.

- Tryck på **Alt+Left** för att gå tillbaka till föregående mapp, och **Alt+Right** för att gå framåt igen.
- Tryck på **Alt+Down** för att öppna en lista med senaste mappar och hoppa till någon av dem.

## Skriv en sökväg eller använd sökvägsraden

Sökvägsraden överst i varje panel visar var du är och fungerar även som ett snabbt sätt att ta dig någonstans.

![Redigerbar sökvägsrad som visar den aktuella mappen som klickbara segment](screenshots/path-bar-crop.png)
*(Bild: Sökvägsraden. Klicka på ett segment för att hoppa till den mappen, eller på pennan för att skriva en fullständig sökväg.)*

- Klicka på ett segment av sökvägen (t.ex. en överordnad mapps namn) för att hoppa direkt dit.
- Klicka på pennan till höger på sökvägsraden för att göra den till ett textfält, skriv eller klistra sedan in valfri sökväg och tryck på Enter.
- Eller välj **Arkiv ▸ Gå till mapp…** (**Cmd+Shift+G**) för att skriva en sökväg var som helst ifrån.

## Hoppa till vanliga platser

Menyn **Gå** tar den aktiva panelen till de mappar du använder mest:

- **Hem**, **Skrivbord**, **Hämtade filer**, **Papperskorg** och **iCloud Drive**.
- **iCloud Drive** visas när det är inställt på din Mac.

## Växla paneler och enheter

- Tryck på **Tab** för att flytta fokus mellan vänster och höger panel.
- Enhetsraden ovanför varje panel listar dina monterade volymer med ledigt utrymme; klicka på en volym för att växla den panelen till den.
- Tryck på **Ctrl+U** för att byta plats på de två panelerna (deras mappar byter sida); **Ctrl+Shift+U** byter dem tillsammans med deras flikar.
- Tryck på **Ctrl+=** för att rikta den andra panelen mot samma mapp som den aktiva (*mål = källa*) — behändigt strax före en kopiering eller flytt.
- **Gå ▸ Vänster = Höger** och **Gå ▸ Höger = Vänster** gör samma sak men namnger sidan rakt ut: den första visar höger panels mapp till vänster, den andra visar vänster panels mapp till höger. Till skillnad från *mål = källa* beror de inte på vilken panel som är aktiv, så deras två knappar på knappraden betyder alltid samma sak.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna mapp/fil under markören | Enter |
| Gå till överordnad mapp | Ctrl+PageUp (eller Backspace) |
| Bakåt/framåt i historiken | Alt+Left / Alt+Right |
| Historiklista | Alt+Down |
| Gå till mapp… (skriv en sökväg) | Cmd+Shift+G |
| Hem | Cmd+Shift+H |
| Skrivbord | Cmd+Shift+D |
| Hämtade filer | Option+Cmd+L |
| Växla aktiv panel | Tab |
| Global historik (oavsett panel) | Ctrl+Cmd+H |

## Tips

- En panel håller sig själv uppdaterad: en fil som ett annat program skapar, ändrar eller tar bort i mappen du tittar på visas av sig själv, och markören och dina markeringar står kvar. Stäng av det under **Konfiguration ▸ Alternativ ▸ Visning** om en mapp som något skriver till hela tiden uppdateras oavbrutet.
- Varje panel har sin egen historik, så Bakåt och Framåt påverkar bara den aktiva sidan.
- Om en inskriven sökväg inte är en giltig mapp behåller sökvägsraden i tysthet din senaste plats i stället för att navigera.
- Papperskorg och iCloud Drive i Gå-menyn har inget standardkortkommando, men du kan tilldela ett i **Konfiguration ▸ Alternativ ▸ Tangentbord**.
