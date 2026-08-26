---
title: Asistente de IA
slug: ai-assistant
section: Complementos
order: 122
related: [plugins, settings, privacy-and-security]
---

El asistente de IA es un complemento opcional y desinstalable que le ayuda a trabajar con sus archivos en lenguaje natural. Puede resumir o explicar un documento, sugerir un mejor nombre de archivo, traducir o corregir un texto, convertir datos en una tabla e incluso organizar una carpeta; además, puede realizar acciones sobre los archivos por usted tras mostrarle primero un plan. Consta de dos complementos: **AI On-Device** funciona con Apple Intelligence y ofrece las acciones que muestran una propuesta y la aplican, mientras que **AI Assistant** es el chat y necesita un modelo en la nube. Active uno de los dos, o ambos. Al ser un complemento, puede desactivarlo o eliminarlo por completo desde **Configuración ▸ Complementos…**.

## Abrir el asistente

Elija **Comandos ▸ Asistente de IA** para mostrar el asistente en un panel acoplado a la derecha de la ventana. Escriba una petición y pulse Return; el asistente puede leer archivos, buscar información y, con su confirmación, realizar cambios.

![El chat del asistente de IA acoplado junto a los paneles de archivos](screenshots/ai-chat.png)
*(Figura: El asistente de IA, acoplado a la derecha, trabajando en una petición.)*

## Acciones del menú contextual (IA ▸)

La forma más rápida de usar el asistente es el submenú **IA ▸** del menú contextual:

- **Sobre un archivo**: Resumir, Explicar, Sugerir un nombre, Sugerir un comentario, Traducir al inglés, Corregir, Detectar tareas y Crear una tabla.
- **Sobre el fondo del panel**: Organizar esta carpeta y Buscar posibles duplicados.

**Resumir**, **Explicar**, **Sugerir un nombre**, **Sugerir un comentario** y **Organizar esta carpeta** provienen del complemento **AI On-Device** y hacen su trabajo sin abrir ningún chat: muestran su propuesta en una hoja, usted desmarca lo que quiera dejar como está y nada cambia en el disco hasta que lo aprueba. Las demás acciones pertenecen al complemento **AI Assistant** y abren su propio chat con nombre, de modo que las distintas tareas se mantienen separadas. Cuando escribe usted mismo en el campo de entrada, esa petición continúa el chat actual.

## Gestionar los chats

- Use el selector de chats de la parte superior del panel para moverse entre conversaciones.
- El menú **Eliminar ▾** ofrece **Eliminar este chat** y **Eliminar todos los chats**, para que pueda vaciarlo todo de una vez cuando la lista se alargue. Los chats vacíos se limpian automáticamente al cerrar el panel.

## Los cambios se confirman primero

Para todo lo que modifique archivos —mover, renombrar, escribir, eliminar—, el asistente muestra un **plan y espera su confirmación** antes de actuar. Puede cambiar esto en Ajustes elevando la autonomía del asistente, o reducirla a solo lectura para que nunca modifique nada.

## Ajustes

Abra **Configuración ▸ Ajustes ▸ IA** para configurar el asistente en una sola página:

- **Modelo preferido**: Automático (nube si está configurada; en caso contrario, en el dispositivo), En el dispositivo (Apple Intelligence) o Nube.
- **Extremo, modelo y clave de API de la nube**: para usar un modelo compatible con OpenAI en lugar del que se ejecuta en el dispositivo. La clave se almacena en el Llavero de macOS, nunca en sus archivos de configuración.
- **Autonomía del asistente**: solo lectura, confirmar cambios (el valor predeterminado) o autónomo.
- **Indicación de sistema personalizada**: instrucciones opcionales que determinan cómo responde el asistente.
- **Servidor MCP**: un servidor opcional exclusivamente local que permite a un agente externo controlar la aplicación; está desactivado de forma predeterminada y puede protegerse con un token.

![La página de IA en Ajustes con las opciones de autonomía y del servidor MCP](screenshots/settings-ai.png)
*(Figura: Todas las opciones del asistente se encuentran en una sola página de IA en Ajustes.)*

## Privacidad

- Con Apple Intelligence, el asistente se ejecuta **en su Mac**; nada sale del dispositivo.
- Solo se usa un modelo en la nube **si usted configura uno**, y su clave de API se guarda en el Llavero.
- Las acciones que modifican archivos se confirman antes de ejecutarse, salvo que eleve deliberadamente el nivel de autonomía.
