---
title: Asistent AI
slug: ai-assistant
section: Zásuvné moduly
order: 122
related: [plugins, settings, privacy-and-security]
---

Asistent AI je voliteľný zásuvný modul, ktorý možno odstrániť a pomáha vám pracovať so súbormi v prirodzenom jazyku. Dokáže zhrnúť alebo vysvetliť dokument, navrhnúť lepší názov súboru, preložiť alebo skorigovať text, premeniť údaje na tabuľku a dokonca usporiadať priečinok — a môže za vás vykonať operácie so súbormi po tom, ako vám najprv ukáže plán. Tvoria ho dva moduly: **AI On-Device** beží na Apple Intelligence a ponúka akcie, ktoré ukážu návrh a vykonajú ho, zatiaľ čo **AI Assistant** je chat a potrebuje cloudový model. Zapnite jeden z nich alebo oba. Keďže ide o zásuvný modul, môžete ho zakázať alebo úplne odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Otvorenie asistenta

Vyberte **Príkazy ▸ Asistent AI** na zobrazenie asistenta v ukotvenom paneli vpravo v okne. Zadajte požiadavku a stlačte Enter; asistent dokáže čítať súbory, vyhľadávať veci a — s vaším potvrdením — vykonávať zmeny.

![Chat asistenta AI ukotvený vedľa panelov so súbormi](screenshots/ai-chat.png)
*(Obrázok: asistent AI, ukotvený vpravo, pracuje na požiadavke.)*

## Akcie pravého tlačidla (AI ▸)

Najrýchlejší spôsob použitia asistenta je podponuka **AI ▸** v kontextovej ponuke:

- **Na súbore** — Zhrnúť, Vysvetliť, Navrhnúť názov, Navrhnúť komentár, Preložiť do angličtiny, Skorigovať, Zistiť úlohy a Vytvoriť tabuľku.
- **Na pozadí panela** — Hľadať podľa významu, Usporiadať tento priečinok a Nájsť pravdepodobné duplikáty.

**Zhrnúť**, **Vysvetliť**, **Navrhnúť názov**, **Navrhnúť komentár** a **Usporiadať tento priečinok** pochádzajú z modulu **AI On-Device** a svoju prácu urobia úplne bez chatu: ukážu návrh v samostatnom liste, vy odškrtnete všetko, čo má zostať nezmenené, a na disku sa nič nezmení, kým nesúhlasíte. Ostatné akcie patria modulu **AI Assistant** a otvoria vlastný pomenovaný chat, takže rôzne úlohy zostávajú oddelené. Keď do vstupného poľa napíšete niečo sami, táto požiadavka pokračuje v aktuálnom chate.

## Správa chatov

- Použite prepínač chatov v hornej časti panela na prechádzanie medzi konverzáciami.
- Ponuka **Odstrániť ▾** ponúka **Odstrániť tento chat** a **Odstrániť všetky chaty**, takže môžete vyčistiť všetko naraz, keď sa zoznam predĺži. Prázdne chaty sa automaticky vyčistia po zatvorení panela.

## Zmeny sa najprv potvrdia

Pri všetkom, čo mení súbory — presúvanie, premenovanie, zápis, mazanie — asistent zobrazí **plán a čaká na vaše potvrdenie** pred konaním. Toto môžete zmeniť v Nastaveniach zvýšením autonómie asistenta, alebo ju znížiť na iba na čítanie, aby nikdy nič nemenil.

## Nastavenia

Otvorte **Konfigurácia ▸ Nastavenia ▸ AI** na nastavenie asistenta na jednej stránke:

- **Preferovaný model** — aký model používa chat **AI Assistant**. Odkedy sa akcie v zariadení stali vlastným modulom, týka sa to len chatu: *Cloud* aj *Automaticky* používajú koncový bod nižšie a *V zariadení* hovorí chatu, že nie je potrebný.
- **Cloudový koncový bod, model a kľúč API** — na použitie modelu kompatibilného s OpenAI namiesto toho na zariadení. Kľúč je uložený v zväzku kľúčov macOS, nikdy vo vašich konfiguračných súboroch.
- **Autonómia asistenta** — iba na čítanie, potvrdzovať zmeny (predvolené) alebo autonómny.
- **Vlastná systémová výzva** — voliteľné pokyny, ktoré tvarujú, ako asistent odpovedá.
- **Server MCP** — voliteľný, iba lokálny server, ktorý umožňuje externému agentovi ovládať aplikáciu; predvolene vypnutý a chrániteľný tokenom.

![Stránka AI v Nastaveniach s možnosťami autonómie a servera MCP](screenshots/settings-ai.png)
*(Obrázok: všetky možnosti asistenta sa nachádzajú na jednej stránke AI v Nastaveniach.)*

## Súkromie

- S Apple Intelligence asistent beží **na vašom Macu**; nič neopúšťa zariadenie.
- Cloudový model sa použije **iba ak ho nakonfigurujete**, a jeho kľúč API je uchovaný v zväzku kľúčov.
- Akcie meniace súbory sa potvrdzujú pred spustením, pokiaľ zámerne nezvýšite úroveň autonómie.
