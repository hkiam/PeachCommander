---
title: Opgavehåndtering
slug: task-manager
section: Plugins
order: 125
related: [plugins, viewing-files, deleting-files]
---

Task Manager-pluginet gør de kørende processer på din Mac til en mappe, du kan gennemse. Det vises som et **TaskManager**-drev i drevlinjen; åbn det, og hver proces er en række, du kan sortere, granske som en fil eller afslutte — med de samme taster, du allerede bruger til filer. Det er et plugin, så du kan slå det fra eller fjerne det i **Konfiguration ▸ Plugins…**.

## Åbn det

1. Klik på **📊 TaskManager**-emnet i drevlinjen (det sidder lige efter dit startdrev).
2. Panelet fyldes med én række pr. kørende proces. Hver rækkes navn er procesnavnet efterfulgt af dens PID, for eksempel `Finder (462)`.
3. Knappen **TaskManager** forbliver valgt, mens du er i den, og fanen får drevets navn. Skift til en anden fane og tilbage — eller afslut og åbn appen igen — og fanen viser igen proceslisten. Du forlader den ved at gå et niveau op eller klikke på en anden diskenhed i drevlinjen.

![Task Manager der viser kørende processer med kolonnerne PID, CPU, hukommelse og kommando](screenshots/task-manager.png)
*(Figur: kørende processer vist som en filliste, du kan sortere og handle på.)*

## Hvad hver kolonne betyder

Ved siden af kolonnen Dato (starttidspunkt) tilføjer Task Manager proceskolonner. Størrelsen på en procesrække viser `DIR`, fordi en proces er en mappe, du kan åbne (se nedenfor) — hukommelsen har sine egne kolonner:

| Kolonne | Betydning |
| --- | --- |
| **PID** | Proces-id |
| **CPU %** | Nylig processorbrug (kræver en anden opdatering for at dukke op) |
| **Memory** | Hukommelsesaftryk — hvad denne proces står til regnskab for (tallet Aktivitetsovervågning viser) |
| **Resident** | Resident størrelse, delte sider medregnet; udfyldt for hver proces |
| **Threads** | Antal tråde |
| **State** | R kører · S sover · T stoppet · Z zombie · I inaktiv, plus de endelser `ps` tilføjer (s = sessionsleder, + = forgrund, N = lav prioritet) |
| **User** | Ejer |
| **PPID** | Forældreprocessens id |
| **Read** | Bytes læst fra disken siden processen startede |
| **Written** | Bytes skrevet til disken siden processen startede |
| **Wakeups** | Interrupt-opvågninger siden processen startede |
| **Signed** | Hvem der har signeret programmet: Apple, et Developer ID-team, ad-hoc eller usigneret |
| **Command** | Fuld kommandolinje |

Sortér efter enhver kolonne (for eksempel CPU % eller Størrelse/hukommelse), præcis som du ville gøre i en almindelig mappe.

## Granske eller afslutte en proces

- **Vis (F3)** viser en rapport med *Procesoplysninger*: navn, PID, forælder, bruger, tilstand, tråde, hukommelse, CPU, starttidspunkt, sti til den eksekverbare fil og den fulde kommandolinje.
- **Slet (F8)** afslutter processen. Den første sletning sender en pæn **quit** (SIGTERM); at slette en proces, der stadig kører, en anden gang eskalerer til en **force quit** (SIGKILL). Pluginet retter sig aldrig mod PID 1.

## Find de processer, der bruger en fil

Højreklik på en vilkårlig række og vælg **Find processer efter fil…**, og indtast så stien til en fil. Hver proces, der har filen åben lige nu, fremhæves, og markøren springer til den første, der kan ændre den:

- **Blå** — processen læser kun filen.
- **Orange** — processen skriver kun til den.
- **Lilla** — processen gør begge dele.

Stien udfyldes på forhånd fra markøren i det andet panel, så du kan pege på en fil derovre og spørge uden at skrive. **Find proces efter port…** i den samme menu besvarer søskendespørgsmålet: hvilken proces lytter på en TCP/UDP-port. Vælg **Ryd filfremhævning** for at fjerne farverne; det fjerner dem også at forlade proceslisten.

## Åbn en proces for at se dens filer

Tryk Retur på en proces — eller dobbeltklik på den — og panelet viser de filer, processen har åbne lige nu, som almindelige filrækker med deres rigtige størrelse og dato. Derfra:

- **Vis (F3)** åbner selve filen.
- **Gå til filen** viser den i det andet panel, hvor du kan arbejde med den.
- **Vis i Finder** giver den videre til Finder.

Kun åbne filer tæller: et bibliotek, processen blot har lagt i hukommelsen, og dens arbejdsmappe er ikke åbne filer. En anden brugers proces viser en tom mappe.

## Bemærkninger

- Grundlæggende oplysninger (PID, forælder, bruger, tilstand, signatur) kan læses for hver proces. Hukommelsesaftryk, tråde, disk-I/O og listen over åbne filer kan læses for **dine egne** processer, hvilket på en normal Mac er størstedelen af listen. For andre brugeres processer udfyldes CPU og Resident i stedet fra `ps` — et gennemsnit over hele levetiden i stedet for forskellen mellem to målinger, som de øvrige rækker bærer — og tråde og aftryk forbliver tomme.
- CPU % er en ændring mellem to målinger, så den er blank, indtil panelet opdaterer en anden gang (panelet opdateres omtrent hvert andet sekund).
- Listen er skrivebeskyttet bortset fra at afslutte en proces — du kan ikke kopiere filer ind i den.
- Fremhævningsfarverne følger dit farvetema: Norton-paletten bruger i stedet grøn, rød og magenta.
- Kun de håndtag, din konto må se på, bliver fundet, hvilket i praksis betyder dine egne processer. Et bibliotek, som en proces blot har lagt i hukommelsen, eller dens arbejdsmappe, er ikke et åbent håndtag og rapporteres ikke.
- Kolonnen **Signed** fyldes ud i løbet af de første sekunder: at læse en signatur tager cirka et millisekund, og der er hundredvis af forskellige programmer, så der læses nogle få pr. opdatering, og de huskes derefter. En tom celle betyder “ikke læst endnu”, ikke “usigneret”.
- **Signed** siger, hvem der har signeret programmet, ikke om det er notariseret: at kontrollere notarisering betyder at hashe hele programmet, hvilket ville tage sekunder for hvert enkelt.
- Det hurtige filter (Ctrl+S) rammer her også kolonnerne og ikke kun navnet, og et udtryk kan nævne den kolonne, det gælder: `user:root state:R` spørger, hvad root kører lige nu. Udtryk adskilles med mellemrum, og alle skal passe; tekst, der ikke nævner nogen kolonne, forbliver én almindelig delstreng, mellemrum inklusive.
