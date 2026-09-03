---
title: Partajări de rețea
slug: network-shares
section: Rețea și acces la distanță
order: 104
related: [ftp-and-sftp]
---

Peach Commander se poate conecta la serverele de fișiere din rețeaua dvs. locală sau de întreprindere — partajări SMB (Windows/Samba) și AFP — și afișa conținutul lor într-un panou exact ca un folder de pe propriul Mac. Odată ce o partajare este conectată, puteți parcurge, copia, muta, redenumi și deschide fișiere în ea exact ca local, inclusiv copierea între partajare și celălalt panou al dvs.

## Conectarea la un server

1. Faceți clic pe panoul la care doriți să vă conectați (partajarea conectată se deschide în panoul activ).
2. Apăsați Cmd+K, sau alegeți **Rețea > Vecinătate de rețea > Conectează partajare de rețea…**.
3. În dialogul **Conectare la server**, tastați adresa serverului. Puteți indica:
   - o adresă SMB, de exemplu `smb://fileserver/projects`
   - o adresă AFP, de exemplu `afp://fileserver/projects`
   - o cale în stil Windows, de exemplu `\\fileserver\projects\reports`
   - un simplu nume `server/partajare`
4. Faceți clic pe Conectează (sau apăsați Enter). Dacă serverul are nevoie de nume și parolă, macOS afișează fereastra sa obișnuită de autentificare — introduceți acolo datele dvs.
5. Când partajarea este gata, panoul activ o deschide automat. Parcurgeți și lucrați cu ea ca cu orice alt folder.

## Deconectare

O partajare conectată apare ca un volum montat pe Mac-ul dvs. Pentru a o deconecta, ejectați-o în modul obișnuit macOS — de exemplu din bara laterală Finder sau din lista de dispozitive din Peach Commander.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Conectează partajare de rețea… | Cmd+K |

## Note

- Autentificarea (nume de utilizator, parolă și o eventuală opțiune „reține în inelul meu de chei") este gestionată de fereastra obișnuită de autentificare macOS, astfel încât parolele de server salvate funcționează ca în Finder.
- Dacă indicați o adresă care nu poate fi analizată, Peach Commander cere o adresă SMB/AFP, o cale în stil Windows sau un nume `server/partajare`, și nimic nu este montat.
- După ce confirmați, conexiunea poate dura un moment în timp ce macOS montează partajarea; panoul comută la ea de îndată ce devine disponibilă.
- Aceasta se conectează la dispozitive partajate într-o rețea. Pentru a ajunge în schimb la un server FTP, FTPS sau SFTP, vedeți subiectul înrudit de mai jos.
- O cale în stil Windows funcționează și în **Mergi la dosar** și în bara de cale de deasupra unui panou, nu doar în „Conectare la server”. Tastați acolo `\\fileserver\projects\reports` și ajungeți în acel dosar.
- Dacă partajarea este deja conectată, mergeți direct la dosar — fără fereastră de autentificare și fără un al doilea drum la server. Se montează întotdeauna doar partajarea în sine; dosarele de dedesubt se ating printr-o navigare obișnuită, astfel încât tot arborele de deasupra rămâne accesibil.
