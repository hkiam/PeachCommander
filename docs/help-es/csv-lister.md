---
title: Archivos CSV como tabla
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Pulsa **F3** sobre un archivo `.csv` o `.tsv` y se abrirá como una tabla de verdad —columnas, encabezados, ordenación y filtro— en lugar de como líneas de texto con comas.

Es un plugin: puedes desactivarlo o eliminarlo en **Configuración ▸ Plugins…**. Sin él, F3 muestra el archivo como texto plano, lo que sigue siendo perfectamente legible en uno pequeño.

## El delimitador se deduce, no se supone

Coma, punto y coma, tabulador, barra vertical y dos puntos son todos candidatos. El plugin cuenta cada uno en las primeras veinte líneas y elige el que aparece el mismo número de veces en más líneas: un archivo en el que cada fila tiene cuatro puntos y coma es un archivo de puntos y coma, diga lo que diga su extensión. Esto importa en la práctica: un `.csv` exportado por una hoja de cálculo en un sistema español suele estar separado por puntos y coma, y un `.tsv` no siempre está separado por tabuladores.

La primera línea se trata como fila de encabezado y pasa a ser los títulos de las columnas.

## Ordenar y filtrar

Haz clic en un encabezado de columna para ordenar por él, y otra vez para invertirlo. La ordenación es **numérica cuando ambos valores son números** y alfabética en caso contrario, de modo que una columna de tamaños ordena 9 antes que 10 y no después.

El campo de búsqueda filtra mientras escribes, sin distinguir mayúsculas. Por omisión mira en todas las columnas; elige una columna en el menú de al lado para mirar solo ahí.

## Lo que no hace

El analizador es deliberadamente pequeño, y conviene conocer un límite antes de que te sorprenda: **un delimitador dentro de un campo entrecomillado sigue tratándose como delimitador.** Una fila como

```
"Smith, John",42
```

da tres celdas en lugar de dos. Las comillas envolventes se quitan cuando rodean un campo entero, pero el entrecomillado no se interpreta más allá. Para un archivo donde eso importe, el visor integrado o una hoja de cálculo es la herramienta adecuada.

Las líneas vacías se omiten, y no se admite un campo que abarque varias líneas.
