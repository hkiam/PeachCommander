---
title: Asistent IA
slug: ai-assistant
section: Pluginuri
order: 122
related: [plugins, settings, privacy-and-security]
---

Asistentul IA este un plugin opțional, care poate fi eliminat, ce vă ajută să lucrați cu fișierele în limbaj natural. Poate rezuma sau explica un document, sugera un nume de fișier mai bun, traduce sau corecta text, transforma date într-un tabel și chiar organiza un folder — și poate efectua acțiuni asupra fișierelor pentru dvs. după ce vă arată mai întâi un plan. Rulează pe dispozitiv cu Apple Intelligence când este disponibil, sau îl puteți îndrepta către un model din cloud. Deoarece este un plugin, îl puteți dezactiva sau elimina complet din **Configurare ▸ Pluginuri…**.

## Deschiderea asistentului

Alegeți **Comenzi ▸ Asistent IA** pentru a afișa asistentul într-un panou ancorat în dreapta ferestrei. Tastați o solicitare și apăsați Enter; asistentul poate citi fișiere, căuta lucruri și — cu confirmarea dvs. — face modificări.

![Chatul asistentului IA ancorat lângă panourile de fișiere](screenshots/ai-chat.png)
*(Figura: asistentul IA, ancorat în dreapta, lucrând la o solicitare.)*

## Acțiuni cu clic dreapta (IA ▸)

Cel mai rapid mod de a folosi asistentul este submeniul **IA ▸** din meniul cu clic dreapta:

- **Pe un fișier** — Rezumă, Explică, Sugerează un nume, Traduce în engleză, Corectează, Detectează sarcini și Creează un tabel.
- **Pe fundalul panoului** — Organizează acest folder și Găsește duplicate probabile.

Fiecare acțiune **IA ▸** deschide **propriul chat cu titlu** (de exemplu, *Rezumă – raport.txt*), astfel încât sarcinile diferite rămân separate în loc să se îngrămădească într-o singură conversație lungă. Când tastați dvs. în câmpul de intrare, acea solicitare continuă chatul curent.

## Gestionarea chaturilor

- Folosiți comutatorul de chaturi din partea de sus a panoului pentru a trece între conversații.
- Meniul **Șterge ▾** oferă **Șterge acest chat** și **Șterge toate chaturile**, astfel încât puteți curăța totul deodată când lista devine lungă. Chaturile goale sunt curățate automat când închideți panoul.

## Modificările sunt confirmate mai întâi

Pentru orice modifică fișiere — mutare, redenumire, scriere, ștergere — asistentul afișează un **plan și așteaptă confirmarea dvs.** înainte de a acționa. Puteți schimba acest lucru în Setări crescând autonomia asistentului, sau o coborâți la doar citire pentru ca să nu schimbe niciodată nimic.

## Setări

Deschideți **Configurare ▸ Setări ▸ IA** pentru a configura asistentul pe o singură pagină:

- **Model preferat** — Automat (cloud dacă este configurat, altfel pe dispozitiv), Pe dispozitiv (Apple Intelligence) sau Cloud.
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
