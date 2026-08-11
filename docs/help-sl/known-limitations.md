---
title: Znane omejitve
slug: known-limitations
section: Pomoč in odpravljanje težav
order: 144
related: [troubleshooting]
---

Peach Commander naredi veliko, a nekaj funkcij ima v trenutni različici poštene meje. Če jih poznate vnaprej, se izognete zmedi, ko se kaj obnaša nepričakovano. Ta stran našteva trenutne omejitve in, kjer je mogoče, preprosto rešitev.

## Arhivi

- **Razdeljeni (večdelni) arhivi ZIP se odprejo, vendar morajo biti vsi deli na voljo.** Običajni ZIP — vključno z ZIP64, torej več kot 65.535 elementov ali nad 4 GB — pa tudi TAR in z gzipom stisnjen TAR se odprejo neposredno kot mape. Odpre se tudi arhiv, razdeljen na več datotek: pritisnite Enter na datoteki `.zip` nabora `.z01`, `.z02`, … ali na datoteki `.001` nabora `name.zip.001`. Vsi deli morajo biti v isti mapi, nabor, ki mu eden manjka, pa je zavrnjen, namesto da bi se odprl na pol prebran. Razdeljeni arhivi TAR niso zajeti.
- **Šifrirani arhivi ZIP** (starejši ZipCrypto in WinZip AES) so podprti za brskanje, a boste vprašani za geslo.
- Druge oblike, kot so CPIO, ISO, CAB, LZH, XAR in PAX, se odprejo prek pomožnega orodja namesto domačega bralnika.

## Omrežje (SFTP / SCP)

- **Prek SFTP je mogoče spremeniti pravice in časovne oznake, lastnika ne.** Protokol nosi lastnika in skupino le kot številki in uporabniškega imena prek njega ni mogoče razrešiti — sprememba lastnika je zato zavrnjena, namesto da bi jo ugibali, prav tako zastavice datotek macOS, ki jih na drugi strani ni. Prek navadnega FTP je mogoče nastaviti le pravice, z izbirnim ukazom `SITE CHMOD`; strežnik, ki ga ne ponuja, to pove, namesto da bi hlinil uspeh.
- Ob prvi povezavi s strežnikom SFTP boste vprašani, da zaupate njegovemu ključu gostitelja. Peach Commander si ga nato zapomni (zaupanje ob prvi uporabi).

## Osveževanje map

- **Za zunanje spremembe se spremljajo le mape na tem Macu.** Mapa na tem Macu se posodobi sama, brž ko drug program v njej ustvari, spremeni ali odstrani datoteko. Oddaljeno mesto (FTP ali SFTP) in notranjost arhiva se ne spremljata, saj ta protokola ne ponujata načina za obvestilo — tam pritisnite F2 ali Ctrl+R za ponovno branje.

## Druge trenutne meje

- **Zelo dolge poti: brskanje deluje, kopiranje še ne.** macOS kot argument klica zavrne vsako pot, daljšo od 1024 bajtov, in tako globoko vgnezdene mape se pojavljajo. Izpis, odpiranje, preimenovanje, ustvarjanje in brisanje jih dosežejo; **F5 Kopiraj in F6 Premakni še ne** in tam javita napako. Delo bliže vrhu drevesa map se preostalemu primeru izogne.
- **Ta predogledna različica ni podpisana.** Gatekeeper prepreči prvi zagon, način, kako ga dovolite, pa je odvisen od različice macOS. V **macOS 15 Sequoia in novejšem**: enkrat dvokliknite, zaprite opozorilo, nato pojdite v **Sistemske nastavitve ▸ Zasebnost in varnost** in kliknite **Vseeno odpri** — Apple je v macOS 15 odstranil bližnjico z desnim klikom za nepodpisano programsko opremo, zato desni klik tam ne pomaga več. V **macOS 13–14**: z desno tipko kliknite aplikacijo, izberite Odpri in potrdite. Samodejne posodobitve v tej različici še niso na voljo.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Osveži dejavno podokno | F2 ali Ctrl+R |
| Prenesi z URL | Cmd+Shift+U |

## Opombe

To so omejitve trenutne različice in pričakuje se, da se bodo v kasnejših izdajah izboljšale. Če naletite na obnašanje, ki tu ni opisano, glejte temo o odpravljanju težav.
