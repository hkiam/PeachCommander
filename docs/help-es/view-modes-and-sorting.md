---
title: Modos de vista y ordenación
slug: view-modes-and-sorting
section: Organizar la vista
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Cada panel puede mostrar su carpeta con la disposición que convenga a la tarea: una lista detallada con columnas, una lista compacta de nombres en varias columnas, una cuadrícula de iconos, una galería de miniaturas grandes, o un árbol de carpetas. También puedes ordenar la lista por nombre, extensión, tamaño o fecha, elegir exactamente qué columnas aparecen, y activar la ordenación natural (numérica) para que los nombres con números se alineen como esperas. El modo de vista, el orden y las columnas se ajustan por panel, así que los dos lados pueden verse completamente distintos.

## Cambiar el modo de vista

1. Haz clic en el panel que quieres cambiar para que quede activo.
2. Abre el menú Visualización y elige un modo: **Completa (Detalles)** para la lista de columnas, **Breve (Columnas)** para una lista densa de nombres en varias columnas, **Iconos** para una cuadrícula de iconos, **Miniaturas (Galería)** para vistas previas grandes, o **Árbol** para un árbol de carpetas.
3. Para recorrer rápidamente los modos sin abrir el menú, pulsa Cmd+Shift+M. Cada pulsación pasa al siguiente modo.

![Un panel mostrando los distintos modos de vista: detalles, breve, iconos y galería](screenshots/view-modes.png)
*(Figura: La misma carpeta mostrada como una lista detallada, una lista breve de columnas, una cuadrícula de iconos y una galería de miniaturas.)*

## Ordenar la lista de archivos

1. En la vista de Detalles, haz clic en un encabezado de columna (Nombre, Ext, Tamaño o Fecha) para ordenar por él. Una pequeña flecha en el encabezado muestra la columna y la dirección de orden actuales.
2. Haz clic de nuevo en el mismo encabezado para invertir el orden.
3. También puedes elegir Visualización > Ordenar por y elegir Nombre, Extensión, Tamaño, Fecha o Sin ordenar.

Las carpetas siempre se ordenan juntas al principio, por delante de los archivos, y la entrada `..` que te sube un nivel queda fijada la primera. Ordenar por nombre o extensión es ascendente (A a Z) por omisión; ordenar por tamaño o fecha es primero lo más reciente o lo más grande por omisión.

## Elegir qué columnas aparecen

1. Elige Configuración > Columnas….
2. Activa o desactiva columnas y fija su orden. Las columnas disponibles incluyen Nombre, Ext, Tamaño, Fecha, Attr (atributos), Etiquetas y Comentario.
3. Aplica tus cambios. Las columnas afectan a la vista de Detalles del panel activo.

![La ventana de configuración de columnas con la lista de columnas disponibles](screenshots/columns-config.png)
*(Figura: Elige qué columnas se muestran en la vista de Detalles y fija su orden.)*

## Atajos

| Acción | Atajo |
|---|---|
| Recorrer los modos de vista | Cmd+Shift+M |
| Vista Breve (columnas) | Ctrl+F1 |
| Vista Completa (detalles) | Ctrl+F2 |
| Vista Miniaturas (galería) | Ctrl+Shift+F1 |
| Vista Árbol | Ctrl+F8 |
| Ordenar por nombre | Ctrl+F3 |
| Ordenar por extensión | Ctrl+F4 |
| Ordenar por tamaño | Ctrl+F5 |
| Ordenar por fecha | Ctrl+F6 |

## Consejos

- La ordenación natural (numérica) está activada por omisión, así que `file2` va antes que `file10` en lugar de después. Puedes desactivarla en Configuración > Opciones, en los ajustes de visualización.
- Puedes ensanchar o estrechar una columna en la vista de Detalles arrastrando el divisor entre los encabezados de columna.
- El modo de vista, el orden y la elección de columnas se recuerdan por panel, así que puedes mantener un lado como una lista detallada y el otro como una galería de fotos.
