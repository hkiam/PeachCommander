---
title: Asistent IA
slug: ai-assistant
section: Pluginuri
order: 122
related: [plugins, settings, privacy-and-security]
---

Asistentul IA este un plugin opțional, care poate fi eliminat și care vă ajută să lucrați cu fișierele în limbaj obișnuit. Poate rezuma sau explica un document, propune un nume de fișier mai bun, traduce sau corecta un text, transforma date într-un tabel și chiar ordona un dosar — și poate efectua în locul dumneavoastră operații cu fișiere după ce vă arată mai întâi un plan. Vine ca două pluginuri: **AI On-Device** rulează pe Apple Intelligence și oferă acțiunile care arată o propunere și o aplică, în timp ce **AI Assistant** este discuția și are nevoie de un model în cloud. Activați unul, sau pe amândouă. **Sosesc dezactivate.** Activați-le din **Configurare ▸ Pluginuri…** și reporniți, ori lăsați-le oprite și nu apare nimic — niciun meniu IA ▸, nicio discuție, nicio coloană. Este voit cât timp funcția e în beta: poate redenumi, muta și șterge fișiere și poate rula pentru dumneavoastră comenzi de shell, fiecare în spatele unui plan pe care îl aprobați, iar asta e multă putere pentru a i-o da implicit unei noutăți. Fără o cheie API totul se petrece pe Mac-ul dumneavoastră, deci e vorba de putere, nu de date care părăsesc mașina. Pluginul **AI Column** arată ce au aflat acele acțiuni — un rezumat, un tip, un subiect, o dată — drept coloane în panou; el nu pornește niciun model. Sosește oprit împreună cu ele și rămâne opțional, și nu arată nimic până nu îl activați și nu adăugați una dintre coloanele sale. Din aceeași pagină puteți elimina complet oricare dintre ele.

**Pe dispozitiv sau în cloud.** Modelul local este privat și gratuit, și e mic: primește câteva mii de cuvinte odată. A citi un fișier lung *în întregime* funcționează de aceea altfel — asistentul îl citește pe bucăți și îmbină rezultatele, ceea ce durează cu atât mai mult cu cât fișierul e mai lung. Pentru muncă grea peste multe fișiere, ori pentru conversații lungi, un model din cloud e mai rapid și ține mai mult deodată. Acțiunile din meniul contextual rulează întotdeauna pe Mac-ul dumneavoastră; discuția e jumătatea care vrea un punct terminal, iar **Setări ▸ IA** e locul unde îi dați unul.

## Deschiderea asistentului

Alegeți **Comenzi ▸ Asistent IA** pentru a arăta asistentul într-un panou ancorat în dreapta ferestrei. Scrieți o cerere și apăsați Enter; asistentul poate citi fișiere, căuta informații și — cu confirmarea dumneavoastră — face modificări.

![Discuția asistentului IA ancorată lângă panourile de fișiere](screenshots/ai-chat.png)
*(Figura: asistentul IA, ancorat în dreapta, lucrând la o cerere.)*

## Acțiuni din meniul contextual (IA ▸)

Cea mai rapidă cale de a folosi asistentul e submeniul **IA ▸** din meniul contextual:

- **Pe un fișier** — Rezumă, Explică, Clasifică, Propune un nume, Propune un comentariu, Tradu în engleză, Corectează, Detectează sarcini și Fă un tabel.
- **Pe fundalul panoului** — Ordonează acest dosar, Caută după înțeles și Găsește duplicate probabile.

**Rezumă**, **Explică**, **Clasifică**, **Propune un nume**, **Propune un comentariu**, **Fă un tabel** și **Ordonează acest dosar** vin din pluginul **AI On-Device** și își fac treaba fără a deschide vreo discuție — și pe o scanare sau o captură de ecran, fiindcă mai întâi se citesc cuvintele de pe imagine: își arată propunerea într-o foaie, dumneavoastră debifați ce vreți să rămână neatins, și nimic pe disc nu se schimbă până nu aprobați. Celelalte acțiuni aparțin pluginului **AI Assistant** și deschid o **discuție proprie, cu titlu** (de pildă *Tradu – raport.txt*), astfel încât sarcini diferite rămân separate în loc să se îngrămădească într-o singură conversație lungă. Când scrieți chiar dumneavoastră în câmpul de intrare, acea cerere continuă discuția curentă.

**Mai multe fișiere odată.** Marcați o selecție și acțiunea rulează peste fiecare fișier marcat, unul după altul. Acțiunile care folosesc o foaie arată în ea progresul, iar **Anulează** se oprește între fișiere; cele care deschid o discuție pun progresul în bara de stare, unde **Oprește** face același lucru. Oricum, puteți privi primele rezultate și opri totul.

**Propune un nume** se termină cu un buton, nu cu o frază: numele propus apare într-o bară sub conversație, cu un buton **Redenumește** alături. A-l apăsa este aprobarea — nu vi se cere de două ori.

### Formulările dumneavoastră

Ceea ce fiecare acțiune cere modelului este un fișier text pe care îl puteți edita: `aichat/skills.json` pentru acțiunile pe fișiere și `aichat/folder-skills.json` pentru cele pe dosare, în dosarul dumneavoastră de configurare. Ambele se scriu cu formulările încorporate la prima rulare a asistentului, ca să vedeți formatul. `{name}` și `{path}` stau pentru fișier. Ștergeți un fișier ca să reveniți la formularea încorporată.

**Acțiuni proprii.** Adăugați o intrare cu un `id` la alegerea dumneavoastră și va putea fi rulată ca orice altă comandă, numind `plugin.ai.skill.<id>` — în meniul utilizatorului, pe bara de butoane sau pe o scurtătură de tastatură. (Pentru o acțiune pe dosar, `plugin.ai.folderskill.<id>`.) Submeniul **IA ▸** listează doar acțiunile încorporate: e construit din manifestul pluginului fără a-l încărca, astfel încât un plugin dezactivat să nu contribuie cu nimic — de aceea acțiunile proprii le plasați dumneavoastră în loc să apară acolo. Numiți un id care nu există și asistentul o spune, în loc să nu facă nimic.

## Cereți-i să găsească un fișier

Nu trebuie să știți unde se află un fișier. Descrieți-l și asistentul îl caută în indexul pe care macOS îl ține deja pentru discul dumneavoastră — deci nu e nimic de construit și nici de așteptat să se pună la zi.

- *„Găsește factura PDF de luna trecută"* — un tip, un cuvânt din nume și o fereastră de timp.
- *„Unde sunt toate dosarele mele node_modules?"* — dosare, după nume, oriunde în dosarul personal.
- *„Care fișier menționează contractul de la Aachen?"* — cuvinte **din interiorul** fișierelor, ceea ce căutarea obișnuită Găsește fișiere nu poate face dacă nu îi arătați mai întâi un dosar.

Puteți îndruma unde caută: implicit dosarul personal, întreg calculatorul, sau doar dosarul afișat într-un panou. Vă spune pe care dintre ele l-a folosit, astfel încât un răspuns gol să se poată citi, în loc să semene cu o ridicare din umeri.

Două limite de știut. macOS ține unele locuri în afara indexului său — și în afara razei oricărei aplicații fără Acces complet la disc — deci „nu s-a găsit nimic" nu dovedește că un fișier nu există; vedeți [Depanare](troubleshooting). Iar un fișier tocmai creat poate să nu fie încă indexat, caz în care **Găsește fișiere** (Alt+F7), care parcurge singur dosarele, îl va găsi oricum.

## Gestionarea discuțiilor

- Folosiți selectorul de discuții din partea de sus a panoului pentru a trece de la o conversație la alta.
- Meniul **Șterge ▾** oferă **Șterge această discuție** și **Șterge toate discuțiile**, ca să curățați tot dintr-odată când lista se lungește. Discuțiile goale se curăță singure când închideți panoul.

## Modificările se confirmă mai întâi

Pentru orice modifică fișiere — mutare, redenumire, scriere, ștergere — asistentul arată un **plan și așteaptă confirmarea dumneavoastră** înainte de a acționa. Puteți schimba asta în Setări ridicând autonomia asistentului, ori coborând-o la doar-citire, ca să nu modifice niciodată nimic. O copiere sau o mutare e raportată ca făcută când e făcută: asistentul așteaptă încheierea transferului, iar dumneavoastră îl puteți urmări în Managerul de transferuri ca pe orice altă operație.

**Puteți fi de acord cu o parte dintr-un plan.** Când un plan cuprinde mai multe fișiere — redenumirea unui dosar întreg, golirea Descărcărilor — fiecare apare ca o linie bifată deasupra butoanelor. Debifați-le pe cele pe care vreți să le lăsați în pace și apăsați **Confirmă și execută**: restul merge mai departe, iar ce ați debifat nu e atins. A debifa tot e totuna cu a anula, și asistentul o spune, în loc să raporteze că nu a făcut nimic. Un plan care e o singură acțiune nu are listă, fiindcă Confirmă și Anulează îi spun deja da și nu.

## Ce a făcut asistentul și cum să luați înapoi

**Acțiuni ▾** din discuție are două intrări:

- **Arată ce a făcut asistentul…** listează fiecare modificare, cea mai recentă întâi, cu ce i s-a cerut și cum a ieșit — inclusiv încercările pe care setarea de autonomie le-a refuzat. Un agent extern conectat prin MCP se află în aceeași listă.
- **Anulează ultima modificare** ia înapoi cea mai recentă modificare care are un invers: o redenumire se redenumește înapoi, o mutare se mută înapoi. Acolo unde nimic nu poate fi luat înapoi, lista spune de ce — un fișier suprascris nu a fost păstrat nicăieri, iar elementele din Coș se restaurează din Finder.

Puteți și doar să cereți: *„anulează asta"* și *„ce ai modificat?"* ajung la aceleași două funcții.

## Coloane în panou

Ce au aflat acțiunile e disponibil ca și coloane. Adăugați-le din editorul de seturi de coloane: **Rezumat IA** arată prima linie a unui rezumat, iar **Tip IA**, **Subiect IA** și **Dată IA** arată ce a făcut **Clasifică** dintr-un fișier — sub aceste nume în română, traduse în fiecare limbă. Fiecare rămâne goală până când o acțiune citește acel fișier — aceste coloane arată muncă deja făcută și nu pornesc niciodată singure modelul. **Limbă** din același plugin recunoaște în ce limbă e scris un fișier text, complet fără model.

Aceleași trei sunt și substituenți la redenumire. `[=ai_column.ai_topic]-[Y]-[M].[E]` în fereastra de redenumire multiplă (Ctrl+M) dă unui dosar plin de fișiere `dokument1.pdf` numele a ceea ce sunt: pentru asta nu s-a construit nimic, fiindcă masca de redenumire a rezolvat dintotdeauna `[=provider.field]` prin sistemul de coloane. Întâi clasificați, apoi redenumiți. Antetul urmează limba dumneavoastră; `ai_column.ai_topic` din interiorul măștii nu — deci o mască funcționează mai departe dacă schimbați limba.

## Setări

Deschideți **Configurare ▸ Setări ▸ IA** pentru a configura asistentul pe o singură pagină:

- **Modelul discuției** — pe ce rulează discuția **AI Assistant**. De când acțiunile locale au devenit propriul plugin există două răspunsuri, nu trei: *Punctul terminal din cloud de mai jos, dacă ați indicat unul*, sau *Nimic — lăsați treaba pluginului AI On-Device*. Pagina e grupată la fel: întâi setările discuției, sub ele ce au voie ambele jumătăți.
- **Punct terminal în cloud, model și cheie API** — pentru a folosi un model compatibil OpenAI în locul celui local. Cheia se păstrează în brelocul macOS, niciodată în fișierele dumneavoastră de configurare.
- **Autonomia asistentului** — doar citire, confirmă modificările (implicit) sau autonom.
- **Prompt de sistem propriu** — instrucțiuni opționale care modelează felul în care asistentul răspunde.
- **Server MCP** — un server opțional, strict local, care permite unui agent extern să conducă aplicația; oprit implicit și protejabil cu un token.

![Pagina IA din Setări cu autonomia și opțiunile serverului MCP](screenshots/settings-ai.png)
*(Figura: toate opțiunile asistentului stau pe o singură pagină IA din Setări.)*

## Confidențialitate

- Cu Apple Intelligence asistentul rulează **pe Mac-ul dumneavoastră**; nimic nu părăsește dispozitivul.
- Un model din cloud e folosit **doar dacă îl configurați**, iar cheia sa API rămâne în breloc.
- Acțiunile care modifică fișiere se confirmă înainte de a rula, dacă nu ridicați deliberat nivelul de autonomie.
