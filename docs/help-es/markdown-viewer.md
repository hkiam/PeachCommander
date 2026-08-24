---
title: Markdown y HTML en el visor
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Pulse F3 sobre un archivo `.md` o `.html` y aparecerá con formato en lugar de como código fuente: títulos, listas, tablas, enlaces, listas de tareas y bloques de código coloreados según el lenguaje. Los diagramas escritos como bloques ` ```mermaid ` se dibujan, y las matemáticas escritas entre signos de dólar se componen.

Esto es un plugin. Todo lo de esta página proviene de **Markdown and HTML**, que puede desactivar en **Configuración ▸ Plugins…** — más abajo se explica qué cambia si lo hace.

## Dónde aparece la vista con formato

- **El visor (F3).** La página con formato. El menú **Vista** sigue ofreciendo Texto, Código y Hex, así que el código fuente está a un clic, y el nombre del plugin también figura en esa lista.
- **Quick View (Ctrl+Q) y la página de información** del panel lateral muestran el mismo resultado, de modo que una vista previa y una vista completa del mismo archivo nunca se contradicen.
- **La galería** muestra una pequeña imagen del comienzo de un archivo Markdown en lugar de un icono de documento genérico.
- **Quick Look (Cmd+Y)** es la vista previa propia de macOS y *no* se ve afectada — ese panel pertenece al sistema, y ningún plugin puede dibujar en él.

## El esquema de símbolos

Pulse **Símbolos** en el visor para obtener los títulos del documento, anidados tal como están escritos, y haga clic en uno para saltar allí en la página. Funciona en la vista con formato y en el código fuente, y ambas coinciden en dónde está un título.

## Diagramas y matemáticas

Un bloque de código cuyo lenguaje es `mermaid` se convierte en un diagrama; `$…$` y `$$…$$` se convierten en matemáticas compuestas. Ambos se dibujan **en su Mac**, con motores que vienen dentro del plugin — no se descarga nada, y ninguna parte de su documento se envía a ningún sitio. Un signo de dólar dentro de un bloque de código o de código en línea sigue siendo un signo de dólar.

Un documento sin diagramas ni fórmulas no carga ninguno de los dos motores, así que un README normal no cuesta nada adicional. Un diagrama que no se puede leer muestra el error donde estaba el bloque, con el texto del bloque debajo, en lugar de desaparecer.

Ambos se pueden desactivar por separado en **Configuración ▸ Ajustes ▸ Markdown**, donde también se ve qué versión está en uso y de dónde viene.

## Su propia versión

Si necesita una versión más nueva o distinta de Mermaid o KaTeX, colóquela en la carpeta que abre el botón **Engine Folder…** y se usará en lugar de la incluida. Los nombres de archivo son `mermaid.min.js`, `katex.min.js`, `katex.min.css` y `auto-render.min.js`. Nunca se descarga nada de internet en su nombre.

## Lo que la página con formato no hará

La página con formato está deliberadamente aislada, porque un archivo Markdown es contenido que viene de otro sitio:

- **No carga nada por la red.** Una imagen cuya dirección empieza por `http` se queda vacía a propósito: obtenerla le diría a ese servidor cuándo abrió el archivo y desde qué dirección. Una imagen que está junto al documento en el disco se carga con normalidad.
- **Los scripts y el HTML del documento nunca se ejecutan.** El HTML escrito dentro de un archivo Markdown se muestra como texto, y un archivo `.html` se muestra con la ejecución de scripts desactivada.

## Desactivarlo

Desactive el plugin en **Configuración ▸ Plugins…** y los archivos `.md` y `.html` se abrirán como texto. El esquema sigue funcionando, el coloreado de sintaxis sigue funcionando, y nada más cambia — simplemente ya no se ofrece la vista con formato. Lo mismo ocurre si en la página de ajustes del plugin solo desactiva la vista con formato.

## Límites

- Los archivos por encima de un límite de tamaño (8 MB de forma predeterminada, en la página de ajustes) se abren como texto. Convertir un documento generado muy grande en una página con formato es lento, y el visor de texto lo abre de inmediato.
- La página con formato no se puede editar. Use F4 para eso, o la vista Texto para **Formatear**, **Codificación** e **Ir a**, que se aplican al código fuente y no a una página renderizada.
