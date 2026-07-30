---
title: Abrir archivos y carpetas
slug: opening-files
section: Archivos y carpetas
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander abre archivos y carpetas directamente desde cualquier panel, usando las mismas apps y funciones del sistema en las que ya confías en el Finder. Pulsa una tecla para abrir el elemento bajo el cursor en su app predeterminada, o haz clic derecho para llegar a un menú completo de acciones: abrir con otra app, mostrar el elemento en el Finder, compartirlo o abrir una ventana de Terminal justo donde te encuentras.

## Abrir un elemento

1. Haz clic en un archivo o carpeta de un panel para poner el cursor sobre él (la fila resaltada).
2. Pulsa Enter (o haz doble clic).
   - Una carpeta se abre en el mismo panel.
   - Un archivo se abre en su app predeterminada de macOS: la misma que usaría el Finder.
   - Un archivo comprimido (como un .zip) se abre como una carpeta para que puedas explorar su interior.

![La ventana principal de Peach Commander con ambos paneles mostrando archivos y carpetas](screenshots/main-window.png)
*(Figura: Pon el cursor sobre cualquier elemento y pulsa Enter para abrirlo.)*

## Abrir con otra app, mostrar o compartir

Haz clic derecho en un archivo (o pulsa Shift+F10) para abrir el menú del elemento y elige:

- **Abrir** o **Abrir en la app predeterminada** — abre el archivo como lo haría Enter.
- **Abrir con** — elige cualquier app instalada que pueda abrir este archivo, o elige **Otra…** para buscar una.
- **Quick Look** — previsualiza el archivo sin abrir una app.
- **Mostrar en el Finder** — muestra el archivo seleccionado en una ventana del Finder.
- **Compartir…** — envía el archivo mediante la hoja de compartir de macOS.

El menú también integra los **Servicios** estándar de macOS para el archivo seleccionado, y añade **Etiquetas** para que puedas aplicar las etiquetas de color habituales del Finder.

## Abrir una Terminal en la carpeta actual

Elige **Abrir Terminal aquí** en el menú Archivo o Comandos (Cmd+Option+T) para abrir una ventana de Terminal que ya apunta a la carpeta del panel activo.

## Atajos

| Acción | Tecla |
|---|---|
| Abrir elemento bajo el cursor | Enter |
| Ver archivo (visor) | F3 |
| Editar archivo | F4 |
| Vista previa con Quick Look | Cmd+Y |
| Obtener información / propiedades | Option+Enter |
| Abrir menú del elemento | Shift+F10 o clic derecho |
| Abrir Terminal aquí | Cmd+Option+T |

## Notas

- «App predeterminada» significa la app que macOS está configurado para usar con ese tipo de archivo; cámbiala en el panel Obtener información del archivo, exactamente como en el Finder.
- **Mostrar en el Finder**, **Compartir…** y **Abrir con ▸ Otra…** se aplican a elementos del disco de tu Mac. No están disponibles para elementos dentro de un archivo comprimido ni en una conexión remota (FTP/SFTP).
- Hacer clic derecho en un proceso en ejecución (en una vista de procesos) muestra un menú más corto y específico del proceso en lugar de las acciones de archivo.
