---
title: El visor de registros
slug: log-viewer
section: Plugins
order: 128
related: [plugins, viewing-files, searching]
---

Coloca el cursor sobre un archivo de registro y elige **Ver como registro…** para abrirlo en una ventana pensada para registros y no para texto: una fila por línea, el nivel de cada una reconocido y coloreado, un filtro, y un seguimiento que va al día mientras el archivo se sigue escribiendo.

Es un plugin: puedes desactivarlo o eliminarlo en **Configuración ▸ Plugins…**. Sin él, F3 muestra un registro como cualquier otro archivo de texto.

## Por qué se abre al instante

El archivo se mapea en memoria y solo se construye un índice de dónde empieza cada línea, en segundo plano. Nada se carga como texto antes de estar en pantalla, y solo se descodifican las líneas realmente visibles. Un registro de varios gigabytes se abre tan rápido como uno pequeño, e ir al final no lee el medio.

## Niveles y color

Cada línea se clasifica —**Error**, **Advertencia**, **Info**, **Depuración**, **Traza**, o **Desconocido** cuando el formato no dice nada— y se colorea en consecuencia. Los colores por omisión siguen el aspecto claro u oscuro; define los tuyos en los ajustes del plugin y se usarán esos.

La columna **Nivel** deja ver de un vistazo dónde están los errores, y el campo de filtro reduce la lista a lo que buscas. Activa **Regex** para filtrar con una expresión regular en lugar de texto simple.

## Seguir un archivo que aún crece

Activa **En vivo (desplazamiento automático)** y la ventana sigue el final del archivo a medida que llegan líneas nuevas: el índice se amplía sobre los bytes añadidos en vez de reconstruirse, así que sigue siendo barato por larga que sea la lista. Desplázate hacia arriba y estarás leyendo historial; el seguimiento continúa por debajo.

## Orientarse

| | |
| --- | --- |
| **Buscar…** | Busca en los mensajes; **Buscar (marcar e ir)…** marca cada coincidencia para poder recorrerlas |
| **Ir a la línea…** | Salta a un número de línea físico |
| **Ir a fecha/hora…** | Salta a la primera línea a partir de una marca de tiempo, p. ej. `2024-01-15 10:23:45` |

La copia sabe qué es una línea de registro: **Copiar línea** toma la línea bajo el cursor, **Copiar entrada (todas las líneas)** toma la entrada completa cuando abarca varias líneas —una traza de pila, por ejemplo— y **Copiar líneas seleccionadas** toma exactamente lo que seleccionaste.

## Formatos

**log4j**, **log4net** y **CSV** vienen integrados, y el formato se detecta automáticamente; la ventana muestra por cuál se decidió. Si tus registros no son ninguno de esos, añade el tuyo en **Formatos de registro** dentro de los ajustes: una expresión regular con grupos con nombre para las partes que importan.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Una línea que la expresión no reconoce aparece igualmente: simplemente se clasifica como Desconocido en lugar de descartarse, porque un registro que no se puede leer es peor que un registro sin colores.

## Presentación

**Mostrar números de línea** y **Ajustar líneas largas** están en los ajustes. El área de detalle bajo la lista siempre muestra el texto completo de la entrada seleccionada, ajustado, haga lo que haga la lista.
