---
title: Start-menyn och egna kommandon
slug: start-menu
section: Anpassning
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

**Start**-menyn är din egen personliga meny, placerad i menyraden bredvid Arkiv, Redigera och de övriga. Den innehåller kommandon du definierar själv, så att de åtgärder du oftast tar till alltid är ett klick bort. I traditionen från klassiska tvåpanels-filhanterare kan varje post köra ett inbyggt kommando, starta ett externt program eller en app, eller hoppa direkt till en mapp. Peach Commander levereras med Start-menyn tom och redo för dig att fylla.

## Så här lägger du till egna kommandon

1. Välj **Start > Ändra Start-menyn…**. Peach Commander öppnar din användarkommandofil (och skapar den med ett kommenterat exempel första gången).
2. Lägg till ett avsnitt per kommando. Varje avsnitt börjar med ett namn inom hakparenteser, följt av några enkla nycklar:
   - **cmd** — vad som ska köras: en programsökväg, en app, ett inbyggt `cm_`-kommando, eller ett annat av dina egna kommandon.
   - **param** — parametrar som skickas till ett program. Platshållare fylls i när kommandot körs: `%P` (källmapp), `%N` (aktuell fil), `%T` (den andra panelens mapp), `%M` (den andra panelens fil), `%S` (markerade filer).
   - **path** — mappen att starta i (standard är den aktuella mappen).
   - **menu** — titeln som visas i Start-menyn.
   - **key** — ett valfritt kortkommando, t.ex. `C+S+B`.
3. Spara filen. Start-menyn uppdaterar sig själv nästa gång Peach Commander blir aktivt, så dina nya poster visas direkt.

## Tips

- För att öppna den aktuella mappen i Terminal, ställ in **cmd** på `open`, **param** på `-a Terminal %P` och **menu** på `Öppna terminal här`.
- Rikta **cmd** mot ett `cm_`-kommando för att ge en inbyggd åtgärd en egen Start-menypost och ett eget kortkommando.
- Ordningen i filen är ordningen i menyn, så lägg dina mest använda kommandon överst.

## Anmärkningar

- Du kan även ersätta hela menyraden med din egen. Välj **Konfiguration > Redigera menyfil…** för att öppna en menyfil som utgår från den aktuella, fullt lokaliserade inbyggda menyn; redigera fritt och dina ändringar tillämpas nästa gång appen aktiveras. Radera filen för att återställa den vanliga menyraden.
