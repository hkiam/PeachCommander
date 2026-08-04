---
title: Znane omejitve
slug: known-limitations
section: Pomoč in odpravljanje težav
order: 144
related: [troubleshooting]
---

Peach Commander naredi veliko, a nekaj funkcij ima v trenutni različici poštene meje. Če jih poznate vnaprej, se izognete zmedi, ko se kaj obnaša nepričakovano. Ta stran našteva trenutne omejitve in, kjer je mogoče, preprosto rešitev.

## Arhivi

- **Razdeljenih (večdelnih) arhivov ni mogoče odpreti.** Običajni ZIP — vključno z ZIP64, torej več kot 65.535 elementov ali nad 4 GB — pa tudi TAR in z gzipom stisnjen TAR se odprejo neposredno kot mape. Arhiv, razdeljen na več datotek (`.z01`, `.zip.001`), ni podprt: najprej združite dele ali ga razpakirajte z orodjem, ki ga je ustvarilo.
- **Šifrirani arhivi ZIP** (starejši ZipCrypto in WinZip AES) so podprti za brskanje, a boste vprašani za geslo.
- Druge oblike, kot so CPIO, ISO, CAB, LZH, XAR in PAX, se odprejo prek pomožnega orodja namesto domačega bralnika.

## Omrežje (SFTP / SCP)

- **Spreminjanje atributov datotek prek SFTP v tej različici nima učinka.** Prek SFTP/SCP lahko brskate, prenašate in nalagate, a zahteve za spremembo dovoljenj, lastništva ali časovnih žigov na oddaljenem strežniku so tiho prezrte. Te spremembe naredite na samem strežniku, ali prek drugega protokola.
- Ob prvi povezavi s strežnikom SFTP boste vprašani, da zaupate njegovemu ključu gostitelja. Peach Commander si ga nato zapomni (zaupanje ob prvi uporabi).

## Prenašanje z URL

- Ukaz **Prenesi z URL** (meni Omrežje) trenutno uporablja bližnjico Cmd+Shift+D, ki je ista bližnjica kot Pojdi > Namizje. Ko sta na voljo oba, sta menija lahko v sporu — za gotovost zaženite prenos neposredno iz menija Omrežje.

## Osveževanje map

- **Za zunanje spremembe se spremljajo le mape na tem Macu.** Mapa na tem Macu se posodobi sama, brž ko drug program v njej ustvari, spremeni ali odstrani datoteko. Oddaljeno mesto (FTP ali SFTP) in notranjost arhiva se ne spremljata, saj ta protokola ne ponujata načina za obvestilo — tam pritisnite F2 ali Ctrl+R za ponovno branje.

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
