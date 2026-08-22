---
title: Den inbyggda terminalen
slug: terminal
section: Insticksprogram
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander kan köra ett riktigt skal i sitt eget fönster, i en remsa längst ned som kallas dockan. Det är ditt inloggningsskal — det som `$SHELL` pekar ut, eller `/bin/zsh` om det inte går att använda — så din `PATH`, dina alias och dina funktioner finns där, precis som i Terminal.

Det här är inte samma sak som **Öppna Terminal här**, som startar Apples Terminal i den aktuella mappen och lämnar dig med två fönster. Den inbyggda stannar där dina filer är, och känner till dem.

Det är ett tillägg: vill du inte ha det, stäng av eller ta bort det under **Konfiguration ▸ Tillägg…**, så försvinner dockan med det.

![Den inbyggda terminalen, fäst under de två filpanelerna](screenshots/terminal.png)
*(Figur: skalet körs i mappen som den aktiva panelen visar.)*

## Öppna den och flytta dig

Tryck **Ctrl** tillsammans med tangenten till vänster om ”1” för att flytta tangentbordet mellan filpanelen och terminalen. Det kortkommandot är bundet till tangentens *position*, inte till dess tecken, så det är samma fysiska tangent vad än din layout kallar den: grav accent på ett US-tangentbord, `^` på ett tyskt, `@` på ett franskt.

Allt annat finns i menyn **Terminal**:

| Åtgärd | Vad den gör |
| --- | --- |
| Visa terminalen | Fäller ihop den och fram igen; flikarna och det som körs i dem blir som de är |
| Växla mellan panel och terminal | Flyttar tangentbordsfokus, utan att ändra något annat |
| Ny terminalflik | Ytterligare ett skal, i samma mapp |
| Stäng terminalfliken | Stänger den — och frågar först om något fortfarande körs i den |
| Dela terminalen | Två skal sida vid sida i samma flik |
| Gå till panelens mapp | Gör `cd` till där den aktiva panelen står |
| Infoga de valda filnamnen | Skriver de markerade namnen vid prompten, citerade |
| Kör kommandoraden i terminalen | Skickar det du skrev på kommandoraden till skalet i stället för att köra det osynligt |

Så länge terminalen har fokus går **funktionstangenterna dit**, inte till filpanelen — F5 i en textredigerare inuti terminalen måste nå redigeraren. Funktionstangentraden säger det, i stället för att visa tangenter som inte kommer att utlösa något.

## Bron tillbaka till panelen

**Cmd-klicka på en sökväg** i terminalens utdata så går panelen dit. En fil från `ls`, en sökväg i ett kompilatorfel, ett namn från `git status` — ett klick och du tittar på den.

Det sker bara när ordet under pekaren verkligen motsvarar något som finns. Ett Cmd-klick på vanlig text gör ingenting i stället för att navigera någonstans godtyckligt, och ett vanligt klick markerar text som förut.

**Släpp filer på terminalen** så hamnar deras sökvägar vid prompten, citerade, redo för ett kommando du är halvvägs igenom att skriva.

## Låta panelen följa skalet

Av som standard: när du gör `cd` i terminalen står panelen kvar. Slå på **Låt den aktiva panelen följa terminalen** på terminalens inställningssida så följer den med i stället.

Det kräver hjälp av ditt skal, för ett skal talar inte om vart det har gått. Inställningssidan visar ett kort utdrag att lägga i din `~/.zshrc` och en knapp för att kopiera det; det får zsh att rapportera sin arbetsmapp (escape-sekvensen OSC 7) före varje prompt. Utan utdraget är inställningen på och ingenting följer — därför står utdraget alldeles intill.

## Sökning och historik

**Cmd+F** söker i det terminalen har skrivit ut.

En terminal behåller **5 000 rader** historik som standard — nog för att rulla tillbaka genom en kompilering. Ändras på inställningssidan. Mycket stora värden begränsas, eftersom en historik på femtio miljoner rader är ett minnesproblem vars orsak är omöjlig att se utifrån.

## Var den sitter

Terminalen öppnas i dockan längst ned, för det är formen den behöver: ett skal behöver bredd, och sidopanelen rymmer vid sina förvalda 300 punkter omkring 44 kolumner där nederkanten av ett 1200 punkter brett fönster rymmer 176.

Du kan ändå flytta den. Dra den till sidopanelen om det passar dig bättre, eller använd placeringsreglagen som beskrivs i [Tillägg](plugins.md); att flytta den **hänger om samma skal** i stället för att starta ett nytt, så det som körs fortsätter köras. Kommandona i menyn **Terminal** följer den: de tar fram den där den är, i stället för att öppna dockan.

Flikarna kommer tillbaka när du startar appen igen, i de mappar de var i. Det som *kördes* i dem gör det inte — en omstart avslutar de processerna, som i vilken terminal som helst. Om den var öppen när du avslutade kommer också tillbaka.

## När du avslutar

Att stänga appen stänger skalen. Det som fortfarande körs i dem avslutas, precis som att stänga ett Terminal-fönster avslutar det som finns i det. Därför frågar det först när du stänger en flik där något körs.
