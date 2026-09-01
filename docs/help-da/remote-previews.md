---
title: Eksempelvisning af filer, der ikke ligger på denne Mac
slug: remote-previews
section: Visning og redigering
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander viser en eksempelvisning af filen under markøren i informationssidepanelet, i Quick View og som miniaturer i galerivisningen. Når den fil ikke ligger på en disk i denne Mac, koster det noget virkeligt at vise den — en overførsel, en udpakning eller begge dele — og ingen har bedt om det: markøren er blot flyttet hen på filen. Derfor afgør Peach Commander på forhånd, hvad en eksempelvisning må koste; denne side forklarer, hvad den afgør, og hvordan du ændrer det.

## Filer inde i et arkiv

En fil inde i et arkiv kan vises på samme måde som en fil udenfor. Peach Commander pakker den i baggrunden ud til en midlertidig kopi og viser den. Det samme gælder Quick Look, åbning i et andet program med Enter eller dobbeltklik og undermenuen Åbn med.

Det, et andet program får, er en kopi, og den er skrivebeskyttet: det, du ændrer dér, skrives ikke tilbage i arkivet. Peach Commander siger det første gang, med et felt til at holde op med at sige det. Vil du redigere en fil, der ligger i et arkiv, så pak den først ud med F5 og arbejd med den udpakkede fil.

## Hvad en eksempelvisning må koste

En eksempelvisning følger markøren og sker altså uden at være bedt om det. Derfor er den underlagt et budget, der afhænger af, hvor filens indhold i virkeligheden ligger:

- På en disk i denne Mac er der ingen grænse, og eksempelvisninger opfører sig præcis som hidtil.
- På en netværksplacering — et tilsluttet delt drev, FTP, SFTP, Amazon S3 eller et plugin-drev — vises filer op til 4 MB, indtil Peach Commander har målt, hvor hurtig den forbindelse i virkeligheden er. Derefter tillades alt, hvad der kan læses på omkring halvandet sekund, så et hurtigt delt drev viser store filer og et langsomt afviser små.
- I et arkiv pakkes en fil ud til eksempelvisning op til 32 MB.
- En fil, som en skytjeneste endnu ikke har hentet ned til denne Mac, hentes aldrig, blot fordi markøren er flyttet hen på den.
- I arkivformater, der skal pakkes ud fil for fil — CPIO, ISO, CAB, LZH og lignende — vises intet automatisk, fordi hver enkelt fil koster en fuld gennemgang af arkivet.

En afvist eksempelvisning er ikke et tomt panel: sidepanelet viser filens symbol, dens navn, størrelse og dato samt en linje med begrundelsen. Quick Look viser den alligevel og er ikke underlagt nogen af disse grænser.

## Ændr grænserne

1. Åbn Indstillinger ▸ Rediger/Vis.
2. Slå “Vis automatisk eksempler på filer på netværksplaceringer” fra for helt at stoppe eksempelvisninger over netværket, eller sæt “Netværksfiler op til (MB)” til den ønskede størrelse.
3. Slå “Hent filer fra skyen for at vise dem” til, hvis du hellere vil have eksempelvisningen end den sparede trafik.
4. Sæt “Pak ud fra arkiver op til (MB)” for, hvor stor en fil i et arkiv må være.

To yderligere indstillinger har ingen egen betjening og står i `peachcmd.ini` under `[Preview]`: `AutoPreviewSeconds` er tidsbudgettet, der gælder, når en forbindelse er målt (1,5 som standard; 0 slår det fra), og `AutoPreviewLocalMB` er et loft for lokale diske (0 betyder ingen grænse).

## Hvor de udpakkede kopier havner

Kopier skrives til systemets midlertidige mappe, og eksempelvisningerne deles om dem i stedet for hver at lave sin egen. En kopi lavet til en eksempelvisning fjernes, når du forlader arkivet; en kopi givet til et andet program bliver, indtil du afslutter Peach Commander, fordi det program stadig har den åben. Det, en uventet afslutning efterlader, genkendes ved næste start og ryddes så væk.

Miniaturer i galerivisningen følger samme budget, og filer inde i et arkiv beholder dér deres generelle symbol i stedet for en miniature.
