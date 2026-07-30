---
title: Arbejde med arkiver
slug: archives
section: Arkiver
order: 80
related: [copying-files]
---

Peach Commander behandler arkiver som mapper. Du kan træde ind i et ZIP-, TAR- eller andet understøttet arkiv, gennemse dets indhold og kopiere filer ud — alt sammen uden at pakke ud til disken først. Når du vil oprette et arkiv, samler Pak-kommandoen din markering i et ZIP-, 7z-, TAR- eller andet format, med valgfri kryptering og opdelte diskenheder. Dette er praktisk til at samle filer, der skal sendes, til at skrumpe en mappe til opbevaring eller til at kigge ind i en overførsel, før du forpligter dig til at pakke den ud.

## Gennemse et arkiv som en mappe

1. Flyt markøren til en arkivfil i et panel (for eksempel en `.zip` eller `.tar.gz`).
2. Tryk på Enter eller Ctrl+PageDown for at træde ind, præcis som du ville åbne en mappe.
3. Naviger i indholdet på normal vis. Tryk på Backspace eller Ctrl+PageUp for at gå tilbage op og forlade arkivet.
4. For at trække filer ud skal du markere dem og kopiere (F5) til det andet panel.

![Gennemsyn inde i et arkiv, som om det var en mappe](screenshots/archive-browse.png)
*(Figur: Et åbnet arkiv vist som en almindelig mappeliste, med dets filer klar til at kopiere ud.)*

ZIP, TAR og gzip-komprimeret TAR læses direkte. Andre formater såsom CPIO, ISO, CAB, LZH, XAR og PAX læses via indbyggede systemværktøjer. Krypterede ZIP-arkiver (både klassiske og AES) kan åbnes, når du angiver adgangskoden.

## Pak filer ind i et nyt arkiv

1. Markér de filer og mapper, du vil inkludere, i det aktive panel.
2. Vælg Fil ▸ Pak… eller tryk på Alt+F5. (For at pakke og derefter slette originalerne, brug Alt+Shift+F5.)
3. I dialogen skal du vælge arkivformatet (ZIP, 7z, TAR, tar.gz, bzip2, xz eller RAR), komprimeringsniveauet og hvor det skal gemmes.
4. Slå eventuelt AES-256-kryptering til og angiv en adgangskode, eller opdel arkivet i diskenheder af fast størrelse.
5. Bekræft for at oprette arkivet.

![Pak-dialogen med indstillinger for format, komprimering, kryptering og opdeling](screenshots/pack-dialog.png)
*(Figur: Pak-dialogen, hvor du vælger formatet og indstiller kryptering og opdelte diskenheder.)*

## Pak et arkiv ud eller test det

1. Placér det arkiv, du vil pakke ud, i det aktive panel og destinationsmappen i det andet panel.
2. Vælg Fil ▸ Pak ud… eller tryk på Alt+F9, og bekræft derefter destinationen.
3. For at kontrollere et arkiv for skader uden at pakke det ud, vælg Fil ▸ Test arkiv.

## Redigér en ZIP på stedet

Du kan tilføje eller fjerne filer inde i et eksisterende ZIP-arkiv uden at pakke det ud. Åbn ZIP-arkivet som en mappe, og kopiér derefter filer ind eller slet filer som sædvanligt — ændringen skrives direkte tilbage til arkivet.

## Genveje

| Handling | Genvej |
| --- | --- |
| Gå ind i arkiv under markøren | Enter eller Ctrl+PageDown |
| Forlad arkiv (gå op) | Backspace eller Ctrl+PageUp |
| Pak | Alt+F5 |
| Pak og slet originaler | Alt+Shift+F5 |
| Pak ud | Alt+F9 |

## Bemærkninger

- Pakning til 7z, xz, bzip2 og RAR er afhængig af eksterne værktøjer. Især RAR kræver, at det proprietære RAR-program er installeret; uden det er det format ikke tilgængeligt.
- Redigering af en ZIP på stedet omskriver hele arkivet, så filernes ændringstidsstempler indeni bevares ikke.
- Meget store enkeltmedlemmer begrænses til 512 MiB ved udpakning. Udpakning kan annulleres, mens den kører.
- Ekstremt store arkiver (ZIP64) understøttes ikke.
