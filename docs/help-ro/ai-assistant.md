---
title: Asistent IA
slug: ai-assistant
section: Pluginuri
order: 122
related: [plugins, settings, privacy-and-security]
---

Asistentul IA este un plugin opțional, care poate fi eliminat, ce vă ajută să lucrați cu fișierele în limbaj natural. Poate rezuma sau explica un document, sugera un nume de fișier mai bun, traduce sau corecta text, transforma date într-un tabel și chiar organiza un folder — și poate efectua acțiuni asupra fișierelor pentru dvs. după ce vă arată mai întâi un plan. Este alcătuit din două module: **AI On-Device** rulează pe Apple Intelligence și oferă acțiunile care arată o propunere și o aplică, în timp ce **AI Assistant** este conversația și necesită un model în cloud. Activați unul dintre ele sau pe amândouă. Deoarece este un plugin, îl puteți dezactiva sau elimina complet din **Configurare ▸ Pluginuri…**.

## Deschiderea asistentului

Alegeți **Comenzi ▸ Asistent IA** pentru a afișa asistentul într-un panou ancorat în dreapta ferestrei. Tastați o solicitare și apăsați Enter; asistentul poate citi fișiere, căuta lucruri și — cu confirmarea dvs. — face modificări.

![Chatul asistentului IA ancorat lângă panourile de fișiere](screenshots/ai-chat.png)
*(Figura: asistentul IA, ancorat în dreapta, lucrând la o solicitare.)*

## Acțiuni cu clic dreapta (IA ▸)

Cel mai rapid mod de a folosi asistentul este submeniul **IA ▸** din meniul cu clic dreapta:

- **Pe un fișier** — Rezumă, Explică, Sugerează un nume, Sugerează un comentariu, Traduce în engleză, Corectează, Detectează sarcini și Creează un tabel.
- **Pe fundalul panoului** — Caută după sens, Organizează acest folder și Găsește duplicate probabile.

**Rezumă**, **Explică**, **Sugerează un nume**, **Sugerează un comentariu** și **Organizează acest dosar** provin din modulul **AI On-Device** și își fac treaba fără a deschide vreo conversație: arată propunerea într-o filă, dumneavoastră debifați ce doriți să rămână neschimbat, iar pe disc nu se schimbă nimic până nu aprobați. Celelalte acțiuni aparțin modulului **AI Assistant** și deschid propria conversație denumită, astfel încât sarcinile rămân separate. Când scrieți chiar dumneavoastră în câmpul de introducere, cererea continuă conversația curentă.

## Gestionarea chaturilor

- Folosiți comutatorul de chaturi din partea de sus a panoului pentru a trece între conversații.
- Meniul **Șterge ▾** oferă **Șterge acest chat** și **Șterge toate chaturile**, astfel încât puteți curăța totul deodată când lista devine lungă. Chaturile goale sunt curățate automat când închideți panoul.

## Modificările sunt confirmate mai întâi

Pentru orice modifică fișiere — mutare, redenumire, scriere, ștergere — asistentul afișează un **plan și așteaptă confirmarea dvs.** înainte de a acționa. Puteți schimba acest lucru în Setări crescând autonomia asistentului, sau o coborâți la doar citire pentru ca să nu schimbe niciodată nimic.

## Setări

Deschideți **Configurare ▸ Setări ▸ IA** pentru a configura asistentul pe o singură pagină:

- **Model preferat** — ce model folosește conversația **AI Assistant**. De când acțiunile de pe dispozitiv au devenit un modul separat, aceasta privește doar conversația: *Cloud* și *Automat* folosesc punctul final de mai jos, iar *Pe dispozitiv* îi spune conversației că nu este necesară.
- **Punct final cloud, model și cheie API** — pentru a folosi un model compatibil OpenAI în locul celui de pe dispozitiv. Cheia este stocată în inelul de chei macOS, niciodată în fișierele dvs. de configurare.
- **Autonomia asistentului** — doar citire, confirmă modificările (implicit) sau autonom.
- **Prompt de sistem personalizat** — instrucțiuni opționale care modelează cum răspunde asistentul.
- **Server MCP** — un server opțional, doar local, care permite unui agent extern să conducă aplicația; dezactivat implicit și protejabil cu un token.

![Pagina IA din Setări cu opțiunile de autonomie și server MCP](screenshots/settings-ai.png)
*(Figura: toate opțiunile asistentului se află pe o singură pagină IA în Setări.)*

## Confidențialitate

- Cu Apple Intelligence asistentul rulează **pe Mac-ul dvs.**; nimic nu părăsește dispozitivul.
- Un model din cloud este folosit **doar dacă îl configurați**, iar cheia sa API este păstrată în inelul de chei.
- Acțiunile care modifică fișiere sunt confirmate înainte de a rula, cu excepția cazului în care creșteți în mod deliberat nivelul de autonomie.
