---
title: Forhåndsvisning av filer som ikke ligger på denne Macen
slug: remote-previews
section: Vise og redigere
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander viser en forhåndsvisning av filen under markøren i informasjonssidepanelet, i Quick View og som miniatyrbilder i gallerivisningen. Når den filen ikke ligger på en disk i denne Macen, koster det noe virkelig å vise den — en nedlasting, en utpakking eller begge deler — og ingen har bedt om det: markøren har bare flyttet seg til filen. Derfor avgjør Peach Commander på forhånd hva en forhåndsvisning får koste; denne siden forklarer hva den avgjør og hvordan du endrer det.

## Filer inne i et arkiv

En fil inne i et arkiv kan forhåndsvises akkurat som en fil utenfor. Peach Commander pakker den ut i bakgrunnen til en midlertidig kopi og viser den. Det samme gjelder Quick Look, åpning i et annet program med Enter eller dobbeltklikk, og undermenyen Åpne med.

Det et annet program får, er en kopi, og den er skrivebeskyttet: det du endrer der, skrives ikke tilbake til arkivet. Peach Commander sier det første gang, med en avkrysningsboks for å slutte å si det. Vil du redigere en fil som ligger i et arkiv, pakk den først ut med F5 og arbeid med den utpakkede filen.

## Hva en forhåndsvisning får koste

En forhåndsvisning følger markøren og skjer altså uten at noen har bedt om det. Derfor er den bundet av et budsjett som avhenger av hvor filens innhold faktisk ligger:

- På en disk i denne Macen finnes ingen grense, og forhåndsvisninger oppfører seg nøyaktig som før.
- På et nettverkssted — en montert deling, FTP, SFTP, Amazon S3 eller et plugin-volum — vises filer opptil 4 MB, helt til Peach Commander har målt hvor rask den forbindelsen egentlig er. Deretter tillates alt som kan leses på omtrent halvannet sekund, slik at en rask deling viser store filer og en treg avviser små.
- I et arkiv pakkes en fil ut for forhåndsvisning opptil 32 MB.
- En fil som en skytjeneste ennå ikke har lastet ned til denne Macen, hentes aldri bare fordi markøren havnet på den.
- I arkivformater som må pakkes ut fil for fil — CPIO, ISO, CAB, LZH og lignende — forhåndsvises ingenting automatisk, fordi hver eneste fil koster en full gjennomgang av arkivet.

En avvist forhåndsvisning er ikke et tomt panel: sidepanelet viser filens symbol, navn, størrelse og dato, pluss én linje med grunnen. Quick Look viser den likevel og er ikke bundet av noen av disse grensene.

## Endre grensene

1. Åpne Innstillinger ▸ Rediger/Vis.
2. Slå av «Forhåndsvis filer på nettverkssteder automatisk» for å stoppe nettverksforhåndsvisninger helt, eller sett «Nettverksfiler opptil (MB)» til ønsket størrelse.
3. Slå på «Last ned filer fra skyen for å forhåndsvise dem» hvis du heller vil ha forhåndsvisningen enn den sparte trafikken.
4. Sett «Pakk ut fra arkiver opptil (MB)» for hvor stor en fil i et arkiv får være.

To andre innstillinger har ingen egen kontroll og står i `peachcmd.ini` under `[Preview]`: `AutoPreviewSeconds` er tidsbudsjettet som gjelder når en forbindelse er målt (1,5 som standard; 0 slår det av), og `AutoPreviewLocalMB` er et tak for lokale disker (0 betyr ingen grense).

## Hvor de utpakkede kopiene havner

Kopier skrives til systemets midlertidige mappe, og forhåndsvisningene deler dem i stedet for at hver lager sin egen. En kopi laget for en forhåndsvisning fjernes når du forlater arkivet; en kopi gitt til et annet program blir liggende til du avslutter Peach Commander, fordi det programmet fortsatt har den åpen. Det en uventet avslutning etterlater, gjenkjennes ved neste oppstart og ryddes bort da.

Miniatyrbilder i gallerivisningen følger samme budsjett, og filer inne i et arkiv beholder der sitt generelle symbol i stedet for et miniatyrbilde.
