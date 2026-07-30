---
title: Znane omejitve
slug: known-limitations
section: Pomoč in odpravljanje težav
order: 144
related: [troubleshooting]
---

Peach Commander naredi veliko, a nekaj funkcij ima v trenutni različici poštene meje. Če jih poznate vnaprej, se izognete zmedi, ko se kaj obnaša nepričakovano. Ta stran našteva trenutne omejitve in, kjer je mogoče, preprosto rešitev.

## Arhivi

- **Zelo velikih datotek ZIP (ZIP64) ni mogoče odpreti z vgrajenim bralnikom.** Standardni arhivi ZIP, TAR in z gzip stisnjen TAR se odprejo neposredno kot mape. Arhivi ZIP64 — uporabljeni, ko arhiv vsebuje več kot približno 65.000 elementov ali presega 4 GB — so zunaj tega, kar obvladuje domači bralnik, tako da se morda ne odprejo ali naštejejo nepopolno.
- **Šifrirani arhivi ZIP** (starejši ZipCrypto in WinZip AES) so podprti za brskanje, a boste vprašani za geslo.
- Druge oblike, kot so CPIO, ISO, CAB, LZH, XAR in PAX, se odprejo prek pomožnega orodja namesto domačega bralnika.

## Omrežje (SFTP / SCP)

- **Spreminjanje atributov datotek prek SFTP v tej različici nima učinka.** Prek SFTP/SCP lahko brskate, prenašate in nalagate, a zahteve za spremembo dovoljenj, lastništva ali časovnih žigov na oddaljenem strežniku so tiho prezrte. Te spremembe naredite na samem strežniku, ali prek drugega protokola.
- Ob prvi povezavi s strežnikom SFTP boste vprašani, da zaupate njegovemu ključu gostitelja. Peach Commander si ga nato zapomni (zaupanje ob prvi uporabi).

## Prenašanje z URL

- Ukaz **Prenesi z URL** (meni Omrežje) trenutno uporablja bližnjico Cmd+Shift+D, ki je ista bližnjica kot Pojdi > Namizje. Ko sta na voljo oba, sta menija lahko v sporu — za gotovost zaženite prenos neposredno iz menija Omrežje.

## Osveževanje map

- **Podokno opazi zunanje spremembe z majhno zakasnitvijo, ne takoj.** Peach Commander preverja trenutno mapo glede sprememb približno vsaki 2 sekundi, tako da se datoteka, ki jo doda ali odstrani druga aplikacija, lahko pojavi šele čez trenutek. Če ne želite čakati, osvežite dejavno podokno ročno s tipko F2 ali Ctrl+R.

## Druge trenutne meje

- **Nekatere zelo dolge absolutne poti** (globoko vgnezdene mape, katerih celotna pot je nenavadno dolga) morda niso obravnavane zanesljivo. Delo bliže vrhu drevesa map se temu izogne.
- **Ta predogledna gradnja ni podpisana.** Gatekeeper v macOS lahko ob prvem odpiranju opozori, da je aplikacija od neznanega razvijalca. Kliknite aplikacijo z desno tipko in izberite Odpri, nato potrdite, da jo zaženete. Samodejne posodobitve v tej gradnji še niso na voljo.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Osveži dejavno podokno | F2 ali Ctrl+R |
| Prenesi z URL | Cmd+Shift+D |

## Opombe

To so omejitve trenutne različice in pričakuje se, da se bodo v kasnejših izdajah izboljšale. Če naletite na obnašanje, ki tu ni opisano, glejte temo o odpravljanju težav.
