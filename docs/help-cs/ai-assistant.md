---
title: AI asistent
slug: ai-assistant
section: Zásuvné moduly
order: 122
related: [plugins, settings, privacy-and-security]
---

AI asistent je volitelný, odstranitelný zásuvný modul, který vám pomáhá pracovat se soubory pomocí přirozeného jazyka. Umí shrnout nebo vysvětlit dokument, navrhnout lepší název souboru, přeložit nebo zkorigovat text, převést data do tabulky a dokonce uspořádat složku — a po předchozím zobrazení plánu za vás dokáže provést i operace se soubory. Pokud je k dispozici, běží přímo v zařízení s Apple Intelligence, nebo jej můžete nasměrovat na cloudový model. Protože se jedná o zásuvný modul, můžete jej zcela vypnout nebo odstranit v nabídce **Konfigurace ▸ Zásuvné moduly…**.

## Otevření asistenta

Volbou **Příkazy ▸ AI asistent** zobrazíte asistenta v ukotveném panelu na pravé straně okna. Napište požadavek a stiskněte Return; asistent umí číst soubory, vyhledávat informace a — s vaším potvrzením — provádět změny.

![Chat AI asistenta ukotvený vedle panelů souborů](screenshots/ai-chat.png)
*(Obrázek: AI asistent ukotvený vpravo pracuje na požadavku.)*

## Akce z místní nabídky (AI ▸)

Nejrychlejším způsobem použití asistenta je podnabídka **AI ▸** v místní nabídce (po kliknutí pravým tlačítkem):

- **Na souboru** — Shrnout, Vysvětlit, Navrhnout název, Navrhnout komentář, Přeložit do angličtiny, Zkorigovat, Rozpoznat úkoly a Vytvořit tabulku.
- **Na pozadí panelu** — Uspořádat tuto složku a Najít pravděpodobné duplikáty.

Každá akce **AI ▸** otevře **vlastní pojmenovaný chat** (například *Shrnout – report.txt*), takže různé úlohy zůstávají oddělené, místo aby se hromadily do jedné dlouhé konverzace. Když do vstupního pole napíšete něco sami, tento požadavek pokračuje v aktuálním chatu.

## Správa chatů

- K přepínání mezi konverzacemi použijte přepínač chatů v horní části panelu.
- Nabídka **Smazat ▾** nabízí **Smazat tento chat** a **Smazat všechny chaty**, takže když se seznam prodlouží, můžete vše naráz vymazat. Prázdné chaty se při zavření panelu automaticky uklidí.

## Změny jsou nejprve potvrzeny

U čehokoli, co upravuje soubory — přesouvání, přejmenování, zápis, mazání — asistent zobrazí **plán a před provedením čeká na vaše potvrzení**. To můžete změnit v Nastavení zvýšením autonomie asistenta nebo ji snížit na režim jen pro čtení, aby nikdy nic neměnil.

## Nastavení

Otevřete **Konfigurace ▸ Nastavení ▸ AI** ke konfiguraci asistenta na jediné stránce:

- **Preferovaný model** — Automaticky (cloud, pokud je nakonfigurován, jinak v zařízení), V zařízení (Apple Intelligence) nebo Cloud.
- **Cloudový koncový bod, model a klíč API** — pro použití modelu kompatibilního s OpenAI namísto modelu v zařízení. Klíč se ukládá do klíčenky macOS, nikdy do vašich konfiguračních souborů.
- **Autonomie asistenta** — jen pro čtení, potvrzovat změny (výchozí) nebo autonomní.
- **Vlastní systémový prompt** — volitelné instrukce, které formují způsob, jakým asistent odpovídá.
- **Server MCP** — volitelný pouze lokální server, který umožňuje externímu agentovi řídit aplikaci; ve výchozím stavu vypnutý a chránitelný tokenem.

![Stránka AI v Nastavení s autonomií a možnostmi serveru MCP](screenshots/settings-ai.png)
*(Obrázek: Všechny možnosti asistenta jsou na jedné stránce AI v Nastavení.)*

## Soukromí

- S Apple Intelligence běží asistent **na vašem Macu**; ze zařízení nic neodchází.
- Cloudový model se použije **pouze pokud jej nakonfigurujete** a jeho klíč API je uložen v klíčence.
- Akce měnící soubory jsou před spuštěním potvrzeny, pokud záměrně nezvýšíte úroveň autonomie.
