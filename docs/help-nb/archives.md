---
title: Arbeide med arkiver
slug: archives
section: Arkiver
order: 80
related: [copying-files]
---

Peach Commander behandler arkiver som mapper. Du kan gå inn i et ZIP-, TAR- eller annet støttet arkiv, bla i innholdet og kopiere filer ut — alt uten å pakke ut til disken først. Når du vil opprette et arkiv, samler Pakk-kommandoen utvalget ditt i et ZIP-, 7z-, TAR- eller annet format, med valgfri kryptering og oppdelte volumer. Dette er praktisk for å samle filer for å sende, krympe en mappe for lagring, eller kikke inni en nedlasting før du forplikter deg til å pakke den ut.

## Bla i et arkiv som en mappe

1. I et panel flytter du markøren til en arkivfil (for eksempel en `.zip` eller `.tar.gz`).
2. Trykk Enter eller Ctrl+PageDown for å gå inn, akkurat som du ville åpnet en mappe.
3. Naviger i innholdet normalt. Trykk Backspace eller Ctrl+PageUp for å gå tilbake opp og forlate arkivet.
4. For å trekke filer ut, merk dem og kopier (F5) til det andre panelet.

![Bla inne i et arkiv som om det var en mappe](screenshots/archive-browse.png)
*(Figur: Et åpnet arkiv vist som en vanlig mappeliste, med filene klare til å kopieres ut.)*

ZIP, TAR og gzip-komprimert TAR leses direkte. Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX leses gjennom innebygde systemverktøy. Krypterte ZIP-arkiver (både klassiske og AES) kan åpnes når du oppgir passordet.

## Pakk filer inn i et nytt arkiv

1. Merk filene og mappene du vil inkludere i det aktive panelet.
2. Velg Fil ▸ Pakk… eller trykk Alt+F5. (For å pakke og deretter slette originalene, bruk Alt+Shift+F5.)
3. I dialogen velger du arkivformatet (ZIP, 7z, TAR, tar.gz, bzip2, xz eller RAR), komprimeringsnivået og hvor det skal lagres.
4. Slå eventuelt på AES-256-kryptering og sett et passord, eller del arkivet opp i volumer med fast størrelse.
5. Bekreft for å opprette arkivet.

![Pakk-dialogen som viser format, komprimering, kryptering og oppdelingsalternativer](screenshots/pack-dialog.png)
*(Figur: Pakk-dialogen, der du velger formatet og angir kryptering og oppdelingsvolum-alternativer.)*

## Pakk ut eller test et arkiv

1. Legg arkivet du vil pakke ut i det aktive panelet og målmappen i det andre panelet.
2. Velg Fil ▸ Pakk ut… eller trykk Alt+F9, og bekreft deretter målet.
3. For å sjekke et arkiv for skade uten å pakke det ut, velg Fil ▸ Test arkiv.

## Rediger en ZIP på stedet

Du kan legge til eller fjerne filer inne i et eksisterende ZIP-arkiv uten å pakke det ut. Åpne ZIP-en som en mappe, og kopier deretter filer inn eller slett filer som vanlig — endringen skrives rett tilbake til arkivet.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Gå inn i arkiv under markøren | Enter eller Ctrl+PageDown |
| Forlat arkiv (gå opp) | Backspace eller Ctrl+PageUp |
| Pakk | Alt+F5 |
| Pakk og slett originaler | Alt+Shift+F5 |
| Pakk ut | Alt+F9 |

## Merknader

- Pakking til 7z, xz, bzip2 og RAR er avhengig av eksterne verktøy. RAR krever spesielt at det proprietære RAR-programmet er installert; uten det er det formatet utilgjengelig.
- Redigering av en ZIP på stedet skriver om hele arkivet, så tidsstempler for filendringer inni det bevares ikke.
- Svært store enkeltmedlemmer er begrenset til 512 MiB ved utpakking. Utpakking kan avbrytes mens den kjører.
- ZIP64-arkiver åpnes som alle andre, så et arkiv med mer enn 65 535 elementer eller over 4 GB kan leses normalt; grensen per utpakket fil ovenfor gjelder fortsatt.
