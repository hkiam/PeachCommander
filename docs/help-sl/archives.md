---
title: Delo z arhivi
slug: archives
section: Arhivi
order: 80
related: [copying-files]
---

Peach Commander obravnava arhive kot mape. Vstopite lahko v arhiv ZIP, TAR ali drugo podprto obliko, pregledate njegovo vsebino in iz njega kopirate datoteke — vse brez predhodnega razširjanja na disk. Ko želite ustvariti arhiv, ukaz Zapakiraj združi vaš izbor v obliko ZIP, 7z, TAR ali drugo, z izbirnim šifriranjem in razdeljenimi nosilci. To je priročno za pakiranje datotek za pošiljanje, krčenje mape za shranjevanje ali vpogled v preneseno datoteko, preden se odločite za razširjanje.

## Prebrskajte arhiv kot mapo

1. V podoknu premaknite kazalko na datoteko arhiva (na primer `.zip` ali `.tar.gz`).
2. Pritisnite Enter ali Ctrl+PageDown, da vstopite, tako kot bi odprli mapo.
3. Po vsebini se pomikajte običajno. Pritisnite Backspace ali Ctrl+PageUp, da se vrnete navzgor in zapustite arhiv.
4. Za izvleček datotek jih izberite in kopirajte (F5) v drugo podokno.

![Brskanje po notranjosti arhiva, kot da bi bil mapa](screenshots/archive-browse.png)
*(Slika: odprt arhiv, prikazan kot običajen seznam mape, z datotekami, pripravljenimi za kopiranje.)*

ZIP, TAR in z gzip stisnjen TAR se berejo neposredno. Druge oblike, kot so CPIO, ISO, CAB, LZH, XAR in PAX, se berejo prek vgrajenih sistemskih orodij. Šifrirane arhive ZIP (klasične in AES) je mogoče odpreti, ko navedete geslo.

## Zapakirajte datoteke v nov arhiv

1. Izberite datoteke in mape, ki jih želite vključiti, v dejavnem podoknu.
2. Izberite Datoteka ▸ Zapakiraj… ali pritisnite Alt+F5. (Za pakiranje in nato brisanje izvirnikov uporabite Alt+Shift+F5.)
3. V pogovornem oknu izberite obliko arhiva (ZIP, 7z, TAR, tar.gz, bzip2, xz ali RAR), raven stiskanja in kam ga shraniti.
4. Po želji vklopite šifriranje AES-256 in nastavite geslo, ali arhiv razdelite na nosilce fiksne velikosti.
5. Potrdite, da ustvarite arhiv.

![Pogovorno okno Zapakiraj, ki prikazuje obliko, stiskanje, šifriranje in možnosti razdelitve](screenshots/pack-dialog.png)
*(Slika: pogovorno okno Zapakiraj, kjer izberete obliko in nastavite možnosti šifriranja in razdelitve na nosilce.)*

## Razširite ali preizkusite arhiv

1. Postavite arhiv za izvleček v dejavno podokno in ciljno mapo v drugo podokno.
2. Izberite Datoteka ▸ Razširi… ali pritisnite Alt+F9, nato potrdite cilj.
3. Za preverjanje arhiva glede poškodb brez izvlečka izberite Datoteka ▸ Preizkusi arhiv.

## Uredite ZIP na mestu

Datoteke lahko dodate ali odstranite znotraj obstoječega ZIP brez razširjanja. Odprite ZIP kot mapo, nato kopirajte datoteke vanj ali brišite datoteke kot običajno — sprememba se zapiše neposredno nazaj v arhiv.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Vstopi v arhiv pod kazalko | Enter ali Ctrl+PageDown |
| Zapusti arhiv (pojdi navzgor) | Backspace ali Ctrl+PageUp |
| Zapakiraj | Alt+F5 |
| Zapakiraj in izbriši izvirnike | Alt+Shift+F5 |
| Razširi | Alt+F9 |

## Opombe

- Pakiranje v 7z, xz, bzip2 in RAR se opira na zunanja orodja. RAR zlasti zahteva namestitev lastniškega programa RAR; brez njega ta oblika ni na voljo.
- Urejanje ZIP na mestu prepiše celoten arhiv, tako da datumi spremembe datotek v njem niso ohranjeni.
- Zelo veliki posamezni elementi so pri izvlečku omejeni na 512 MiB. Izvleček je mogoče preklicati med izvajanjem.
- Izjemno veliki arhivi (ZIP64) niso podprti.
