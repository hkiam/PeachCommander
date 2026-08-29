---
title: El menú Inicio y los comandos personalizados
slug: start-menu
section: Personalización
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

El menú **Inicio** es tu propio menú personal, situado en la barra de menús junto a Archivo, Edición y los demás. Contiene comandos que defines tú mismo, de modo que las acciones que más usas están siempre a un clic. Siguiendo la tradición de los gestores de archivos clásicos de dos paneles, cada entrada puede ejecutar un comando integrado, iniciar un programa o app externos, o saltar directamente a una carpeta. Peach Commander se entrega con el menú Inicio vacío y listo para que lo llenes.

## Cómo añadir tus propios comandos

1. Elige **Inicio > Cambiar el menú Inicio…**. Peach Commander abre tu archivo de comandos de usuario (creándolo con un ejemplo comentado la primera vez).
2. Añade una sección por comando. Cada sección empieza con un nombre entre corchetes, seguido de unas pocas claves sencillas:
   - **cmd** — qué ejecutar: la ruta de un programa, una app, un comando integrado `cm_`, u otro de tus propios comandos.
   - **param** — parámetros que se pasan a un programa. Los marcadores se rellenan al ejecutar el comando: `%P` (carpeta de origen), `%N` (archivo actual), `%T` (carpeta del otro panel), `%M` (archivo del otro panel), `%S` (archivos seleccionados).
   - **path** — la carpeta en la que empezar (por omisión, la carpeta actual).
   - **menu** — el título mostrado en el menú Inicio.
   - **key** — un atajo opcional, p. ej. `C+S+B`.
3. Guarda el archivo. El menú Inicio se actualiza por sí solo la próxima vez que Peach Commander pase a estar activo, así que tus nuevas entradas aparecen de inmediato.

## Consejos

- Para abrir la carpeta actual en Terminal, pon **cmd** en `open`, **param** en `-a Terminal %P` y **menu** en `Abrir Terminal aquí`.
- Apunta **cmd** a un comando `cm_` para dar a una acción integrada su propia entrada de menú Inicio y su atajo.
- El orden en el archivo es el orden en el menú, así que pon tus comandos más usados arriba.

## Notas

- También puedes reemplazar toda la barra de menús por la tuya. Elige **Configuración > Editar archivo de menú…** para abrir un archivo de menú generado a partir del menú integrado actual, totalmente localizado; edítalo libremente y tus cambios se aplican la próxima vez que se active la app. Elimina el archivo para restaurar la barra de menús estándar.
