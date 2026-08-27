---
title: Indstillinger
slug: settings
section: Tilpasning
order: 116
related: [appearance, keyboard-shortcuts]
---

Indstillinger-vinduet er, hvor du skræddersyr Peach Commander til den måde, du arbejder på: hvilke linjer der vises, hvordan filer vises, hvordan kopierings- og sletningshandlinger opfører sig, arkivformatet brugt når du pakker, faneadfærd, FTP-standarder, visningssproget og mere. Indstillinger er grupperet i sider, så du hurtigt kan finde en mulighed, og hver ændring gemmes automatisk til din personlige konfigurationsmappe.

## Åbn Indstillinger

1. Vælg **Peach Commander > Indstillinger…**, eller tryk på Cmd+, (komma).
2. Du kan også åbne det samme vindue fra **Konfiguration > Muligheder…**.
3. Vælg en side fra listen til venstre; mulighederne for den side vises til højre.
4. Justér kontrollerne. Ændringer træder i kraft med det samme, medmindre en note på siden siger andet.
5. Vil du direkte til en indstilling, skriv i søgefeltet øverst i vinduet. Matchende indstillinger fra *alle* sider vises sammen med den side, de hører til, og vælger du en, åbnes den side med indstillingen fremhævet. ↑/↓ bevæger sig gennem resultaterne, Return åbner det fremhævede, og Esc forlader søgningen og sætter den side tilbage, du kom fra.

![Indstillinger-vinduet der viser Layout-siden med afkrydsningsfelter til grænsefladelinjerne](screenshots/settings-layout.png)
*(Figur: Layout-siden styrer, hvilke linjer der vises omkring panelerne.)*

## Siderne

Vinduet har disse sider, i rækkefølge:

- **Layout** — vis eller skjul drevlinjen, fanelinjen, stilinjen og statuslinjen, og vælg hvilke sider sidepanelet tilbyder.
- **Visning** — hvordan filer og mapper vises, inklusive datoformatet.
- **Ikoner** — ikonudseende i fillisterne.
- **Betjening** — generel adfærd, såsom hvad der sker, når du skriver i et panel (hurtigsøgning kontra kommandolinjen).
- **Farver** — tilpassede panelfarver, eller lad dem følge det aktuelle tema.
- **Bekræftelse** — hvilke handlinger der beder dig bekræfte først, såsom sletning.
- **Rediger/Vis** — om lagring i editoren beholder en `.bak`-sikkerhedskopi, programmerne brugt til at redigere og vise filer, og associationer pr. type.
- **Kopier/Slet** — bevar filmetadata, brug hurtig kloning, kopier kun nyere filer, verificér efter kopiering, send sletninger til papirkurven og indstil en valgfri hastighedsgrænse.
- **Zip/Pakker** — standardarkivformatet og komprimeringsniveauet brugt når du pakker.
- **Plugins** — slå installerede plugins til eller fra.
- **Faner** — hvordan mappefaner åbner og opfører sig.
- **FTP** — netværksstandarder såsom keep-alive-intervallet.
- **Tastatur** — gennemse og ændr tastaturgenveje.
- **Sprog** — vælg Systemstandard, English eller Deutsch.
- **AI** — konfigurér AI-assistenten: foretrukken model, skyendepunkt og -nøgle, autonomi og den valgfrie MCP-server (se [AI Assistant](ai-assistant.md)).
- **Diverse** — åbn din konfigurationsmappe i Finder.

Aktiverede plugins kan tilføje deres egne sider efter de indbyggede — for eksempel **Disk Map** og **System Monitor** — så deres muligheder bor i det samme vindue (se [Plugins](plugins.md)).

![Indstillinger-vinduet der viser Visning-sidens muligheder for hvordan filer vises](screenshots/settings-display.png)
*(Figur: Visning-siden styrer, hvordan filer og mapper vises.)*

![Indstillinger-vinduet der viser Betjening-siden](screenshots/settings-operation.png)
*(Figur: Betjening-siden styrer hurtigsøgning og museadfærd.)*

## Hvor dine indstillinger gemmes

Din konfiguration holdes i klartekstfiler inde i din personlige Application Support-mappe, på `~/Library/Application Support/PeachCommander`. For at åbne den, gå til **Diverse**-siden og klik på **Åbn konfigurationsmappe**. Gemte FTP-adgangskoder gemmes ikke i disse filer; de holdes sikkert i macOS-nøgleringen.

Indstillinger skrives, efterhånden som du ændrer dem. Du kan også tvinge en gemning når som helst med **Konfiguration > Gem indstillinger** og gemme den aktuelle vinduesplacering og panellayout med **Konfiguration > Gem position**.

## At tage indstillinger med fra Total Commander

Hvis du flytter fra Total Commander på Windows, kan du importere dine gemte FTP-steder. Vælg **Konfiguration > Importer wincmd.ini…** og vælg din Total Commander-FTP-konfigurationsfil. Dine forbindelser tilføjes til Peach Commander i den samme rækkefølge, de optrådte der.

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn Indstillinger | Cmd+, |

## Bemærkninger

- **Sprog**-siden tilbyder Systemstandard, English og Deutsch. At ændre sproget træder først i kraft, efter du genstarter Peach Commander.
- Farver sat på **Farver**-siden tilsidesætter temaet; brug **Gendan standardindstillinger** der for at vende tilbage til temaets farver.
- Peach Commander gemmer sine indstillinger kun i sin egen konfigurationsmappe, så dine ændringer påvirker aldrig andre apps og er nemme at sikkerhedskopiere ved at kopiere den mappe.
