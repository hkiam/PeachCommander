---
title: Tangentbord och kortkommandon
slug: keyboard-shortcuts
section: Anpassning
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander är byggt för att styras från tangentbordet. Det levereras med två färdiga kortkommandoscheman och låter dig binda om vilket kommando som helst till de tangenter du föredrar. Om du kommer från en klassisk tvåpanelsfilhanterare kan du behålla tangenterna du redan kan; om du hellre vill använda välbekanta Mac-kombinationer, byt till macOS-schemat med ett klick. En sökbar kommandowebbläsare låter dig upptäcka allt appen kan göra och köra vilket kommando som helst efter namn.

## Byt tangentbordsschema

1. Öppna menyn **Konfiguration**.
2. Välj **Tangentbordsschema**, och välj sedan ett:
   - **TC Classic** (standard) behåller de traditionella tangenterna, med Ctrl-baserade kombinationer såsom Ctrl+R för att uppdatera en panel.
   - **macOS Native** mappar samma åtgärder till välbekanta Mac-tangenter där det är rimligt, till exempel Cmd+C för att kopiera filer och Cmd+F för att söka.
3. En bock visar det aktiva schemat. Ändringen träder i kraft omedelbart över menyerna och kortkommandofältet.

## Anpassa kortkommandon

1. Välj **Konfiguration > Kortkommandon…**.
2. Hitta ett kommando med hjälp av sökfältet, och markera sedan dess rad.
3. Klicka på **Spela in…** och tryck på tangentkombinationen du vill ha. Den tilldelas direkt.
4. Om den kombinationen redan användes av ett annat kommando talar en notis om vilket kommando den togs från.
5. Använd **Rensa** för att ta bort ett kommandos kortkommando, eller **Återställ standard** för att förkasta alla dina ändringar och återgå till schemats ursprungliga tangenter.

![Redigeraren för kortkommandon som listar kommandon med sina tilldelade tangenter](screenshots/keys-editor.png)
*(Figur: Sök efter ett kommando, och använd sedan Spela in, Rensa eller Återställ standard för att ändra dess kortkommando.)*

## Bläddra bland alla kommandon

1. Välj **Konfiguration > Kommandowebbläsare…**.
2. Skriv i sökfältet för att filtrera efter namn, kategori eller beskrivning.
3. Dubbelklicka på ett kommando, eller markera det och klicka på **Kör**, för att utföra det på den aktiva panelen.

![Kommandowebbläsaren som visar en sökbar lista över kommandon](screenshots/command-browser.png)
*(Figur: Varje kommando i en sökbar lista, med en kort beskrivning av vart och ett.)*

## Kortkommandon

| Åtgärd | Menysökväg |
|---|---|
| Välj det klassiska schemat | Konfiguration > Tangentbordsschema > TC Classic |
| Välj Mac-schemat | Konfiguration > Tangentbordsschema > macOS Native |
| Redigera kortkommandon | Konfiguration > Kortkommandon… |
| Bläddra bland alla kommandon | Konfiguration > Kommandowebbläsare… |
| Uppdatera den aktiva panelen | F2 (även Ctrl+R) |

## Anteckningar

- Dina egna kortkommandon sparas automatiskt och läggs ovanpå det aktiva schemat. Att byta schema behåller dina personliga åsidosättningar.
- Kommandon som inte är tillgängliga i den aktuella kontexten visas nedtonade både i redigeraren för kortkommandon och i kommandowebbläsaren.
- För att använda funktionstangenterna (F1–F12) direkt, slå på **Använd F1-, F2- osv. tangenter som standardfunktionstangenter** i Systeminställningar > Tangentbord. Annars, håll ned tangenten **Fn** tillsammans med funktionstangenten.
