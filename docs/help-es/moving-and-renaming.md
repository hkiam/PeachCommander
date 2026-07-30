---
title: Mover y cambiar de nombre
slug: moving-and-renaming
section: Archivos y carpetas
order: 26
related: [copying-files, multi-rename]
---

Mover reubica archivos y carpetas en lugar de duplicarlos, y cambiar de nombre modifica sus nombres sin tocar su contenido. Como Peach Commander muestra dos paneles uno al lado del otro, mover es simplemente cuestión de elegir lo que quieres en un panel y enviarlo a la carpeta abierta en el otro. También puedes cambiar el nombre de un elemento in situ, o dar nuevos nombres a los elementos movidos sobre la marcha mediante una máscara con comodines.

## Mover archivos al otro panel

1. En el panel de origen, abre la carpeta que contiene los elementos que quieres mover, y abre la carpeta de destino en el otro panel.
2. Selecciona el archivo o carpeta que vas a mover. Para mover varios a la vez, selecciónalos todos primero (consulta *Seleccionar archivos*).
3. Pulsa F6, o elige **Archivo > Mover**.
4. Comprueba la carpeta de destino que se muestra en el diálogo y haz clic en **Aceptar** (o pulsa Return) para iniciar el traslado.

![El diálogo de mover con el campo de ruta de destino, opciones y una casilla de cola](screenshots/copy-dialog.png)
*(Figura: El diálogo de mover usa el mismo campo de destino que copiar: escribe una ruta o añade una máscara con comodines para renombrar al mover.)*

Los traslados dentro de la misma unidad son casi instantáneos. Cuando el destino está en otra unidad, Peach Commander copia los elementos y elimina los originales solo después de que cada archivo haya llegado sin problemas.

## Cambiar el nombre in situ

1. Selecciona un único archivo o carpeta.
2. Pulsa Shift+F6, o elige **Archivo > Cambiar nombre**.
3. Edita el nombre directamente en el panel y pulsa Return para confirmar o Esc para cancelar.

## Cambiar el nombre al mover

El campo de destino del diálogo de mover admite una máscara con comodines, de modo que puedes renombrar los elementos a medida que se mueven:

1. Selecciona los elementos y pulsa F6.
2. En el campo de destino, añade una máscara de nombre tras la carpeta de destino, por ejemplo `/Users/tu/Archivo/*_backup.*`.
3. `*` representa el nombre original y `.*` la extensión original. Confirma para mover y renombrar en un solo paso.

## Atajos

| Acción | Atajo |
| --- | --- |
| Mover al otro panel | F6 |
| Cambiar el nombre in situ | Shift+F6 |

## Consejos

- El diálogo de mover ofrece el mismo botón de opciones y la misma casilla de cola en segundo plano que copiar, así que puedes poner en cola traslados grandes y dejarlos ejecutarse en segundo plano.
- Mover dentro de la misma unidad es una operación rápida in situ, por lo que es seguro para carpetas muy grandes. Un traslado entre unidades tarda más porque los datos se copian primero y luego se elimina el origen.
- Para renombrar muchos archivos a la vez con numeración, buscar y reemplazar o patrones, usa en su lugar la Herramienta de cambio de nombre múltiple (consulta *Cambiar el nombre de muchos archivos*).
