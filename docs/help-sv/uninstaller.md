---
title: Uninstaller
slug: uninstaller
section: Insticksprogram
order: 126
related: [plugins, deleting-files]
---

Att dra en app till papperskorgen lämnar dess stödfiler, cacheminnen, inställningar och behållare utspridda över dina Library-mappar. Uninstaller-insticksprogrammet tar bort ett program **och** de kvarlämnade filerna: det hittar allt appen lämnat efter sig, visar dig listan med en storlek för varje objekt och flyttar allt till papperskorgen när du bekräftar. Det är ett insticksprogram, så du kan slå av det eller ta bort det i **Konfiguration ▸ Insticksprogram…**.

## Avinstallera en app under markören

1. Placera markören på ett program (`.app`) i en panel.
2. Välj **Arkiv ▸ Avinstallera program…**, eller högerklicka ▸ **Avinstallera program…**, eller tryck på **Cmd+Shift+U**.
3. Granskningsfönstret öppnas och listar appen plus varje relaterad fil den hittade, var och en märkt med sin kategori, sökväg och storlek.
4. Avmarkera allt du vill behålla och klicka sedan på **Flytta till papperskorgen** (eller **Ta bort permanent**).

![Granskningsfönstret för avinstallation som listar en apps kvarlämnade filer med kryssrutor och storlekar](screenshots/uninstaller.png)
*(Figur: granska exakt vad som kommer att tas bort innan något raderas.)*

## Bläddra bland alla installerade appar

Välj **Kommandon ▸ Avinstallera program…** för att öppna en sökbar lista över de appar som är installerade på din Mac, med varje apps namn, storlek och installationsdatum. Markera en (eller flera), klicka på **Avinstallera…**, och du landar i samma granskningsfönster. Du kan filtrera listan genom att skriva i sökfältet.

## Hitta kvarlämnade filer

Välj **Kommandon ▸ Hitta kvarlämnade filer…** för att söka efter stödfiler, cacheminnen och inställningar som tillhör appar du **redan** har tagit bort. Granska dem på samma sätt och rensa bort dem. Om ingenting hittas talar insticksprogrammet om det för dig.

## Hur grundligt att söka

Granskningsfönstret har en tillförlitlighetskontroll:

- **Precise** — filer förankrade i appens paketidentifierare. Hög tillförlitlighet; förvalda.
- **Enhanced** — lägger till namnmatchade filer; lämnade omarkerade så att du kan bestämma.
- **Deep** — Enhanced plus en Spotlight-svepning efter allt annat som nämner appen; också lämnat omarkerat.

## Anmärkningar

- Ingenting raderas direkt av insticksprogrammet — objekt går genom appens papperskorg eller permanenta radering, precis som vilken annan filåtgärd som helst. Att ta bort filer i `/Library` eller `/var` kan kräva ett administratörslösenord.
- Innan borttagning avslutar insticksprogrammet den app som körs och lastar ur dess bakgrundsobjekt (launchd), och erbjuder sedan att städa upp eventuella nu tomma leverantörsmappar.
- Om appen installerades med **Homebrew** varnar insticksprogrammet dig och föreslår `brew uninstall --cask` så att Homebrew hålls synkroniserat. App Store-appar noteras också.
- Matchningarna Enhanced och Deep är avsiktligt av lägre tillförlitlighet och börjar omarkerade — granska dem innan du tar bort. Vissa bakgrundsobjekt som installerats via det moderna API:et för inloggningsobjekt kan inte tas bort här.
