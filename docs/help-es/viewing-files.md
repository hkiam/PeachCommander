---
title: Ver archivos
slug: viewing-files
section: Ver y editar
order: 70
related: [editing-files, searching]
---

Peach Commander tiene un visor integrado que te permite mirar dentro de un archivo sin abrir otra app ni modificar el archivo. Pulsa F3 sobre el elemento bajo el cursor y el visor se abre al instante, incluso para archivos muy grandes. Elige automáticamente la mejor forma de mostrar el contenido: texto legible, código con colores de sintaxis, un volcado hexadecimal en bruto, o una imagen a tamaño completo. También puedes previsualizar un archivo dentro de la ventana con Quick View, o pasarlo a Quick Look de macOS.

## Ver un archivo

1. Mueve el cursor sobre un archivo del panel activo.
2. Pulsa F3 (o elige Ver en el menú Archivo). El visor se abre en su propia ventana.
3. Usa la barra de herramientas para cambiar cómo se muestra el contenido: Texto, Código, Hex, Imagen o Renderizado. Déjalo en el ajuste automático para que Peach Commander decida.
4. Desplázate con las teclas de flecha, Page Up/Page Down y la barra de desplazamiento. Para texto largo, activa el botón de minimapa para ver y saltar por todo el archivo de un vistazo.
5. Pulsa N para saltar al siguiente archivo seleccionado, o cierra la ventana con Esc.

![El visor integrado mostrando un archivo de texto con el minimapa a la derecha](screenshots/lister-text.png)
*(Figura: Ver un archivo de texto, con el selector de representación y el minimapa en la barra de herramientas.)*

## Buscar texto y cambiar la codificación

- Pulsa Ctrl+F para buscar dentro del archivo. Pulsa F3 para saltar a la siguiente coincidencia y Shift+F3 para la anterior.
- Si el texto se ve corrupto, haz clic en Codificación en la barra de herramientas (o pulsa E) para recorrer las codificaciones de texto hasta que se lea correctamente; el ajuste automático suele acertar.
- Pulsa W para alternar el ajuste de línea para las líneas largas.

## Quick View y Quick Look

Quick View muestra una vista previa en directo en el panel que *no* estás usando, así puedes seguir explorando en un lado mientras previsualizas en el otro.

1. Pulsa Ctrl+Q. El panel inactivo se convierte en un área de vista previa.
2. Mueve el cursor sobre distintos archivos del panel activo para previsualizar cada uno.
3. Pulsa Ctrl+Q de nuevo, o Esc, para devolver el panel a una lista de archivos normal.

Para una vista previa rápida a pantalla completa gestionada por macOS mismo, pulsa Cmd+Y (Quick Look). Pulsa Cmd+Y o Space de nuevo para cerrarla.

## Atajos

| Acción | Atajo |
| --- | --- |
| Ver el archivo bajo el cursor | F3 |
| Ver solo el archivo bajo el cursor (ignorar archivos marcados) | Shift+F3 |
| Abrir en un visor externo | Option+F3 |
| Buscar dentro del visor | Ctrl+F |
| Coincidencia siguiente / anterior | F3 / Shift+F3 |
| Quick View en el otro panel | Ctrl+Q |
| Quick Look (vista previa de macOS) | Cmd+Y |
| Cerrar el visor o Quick View | Esc |

## Notas

- El visor es de solo lectura. Para modificar un archivo, usa el editor en su lugar (consulta Editar archivos).
- Los archivos muy grandes se abren sin demora: el texto abre una vista rápida y desplazable, y la vista hexadecimal se transmite directamente desde el disco a cualquier tamaño.
- Pulsa F3 sobre una carpeta para ver un resumen de su contenido y su tamaño total en lugar de bytes de archivo.
- El modo Renderizado muestra contenido con formato como páginas web; el modo hexadecimal muestra los bytes en bruto junto a sus caracteres, lo que es útil para inspeccionar archivos binarios.
