---
title: Seleccionar archivos
slug: selecting-files
section: Archivos y carpetas
order: 22
related: [copying-files, searching]
---

Antes de copiar, mover, eliminar o comprimir algo, primero le dices a Peach Commander sobre qué elementos actuar. El elemento en el que está el cursor es siempre el elemento actual, pero también puedes *marcar* uno o varios archivos y carpetas para que un comando se ejecute sobre todos ellos a la vez. Los elementos marcados destacan con un color de nombre distinto en el panel.

## Marcar archivos y carpetas

1. Haz clic en una fila para mover el cursor a ella. Un solo clic selecciona únicamente ese elemento.
2. Para marcar varios elementos a la vez, mantén pulsada Cmd y haz clic en cada uno, o mantén Shift y haz clic para marcar un rango.
3. Para marcar el elemento bajo el cursor y bajar en un solo movimiento, pulsa Insert. Púlsala repetidamente para marcar rápidamente una serie de elementos consecutivos. La barra espaciadora también alterna la marca del elemento actual (y muestra el tamaño de una carpeta).
4. Para marcar todo en el panel, elige Selección > Seleccionar todo (Ctrl+Num+), o pulsa Cmd+A. Elige Selección > Deseleccionar todo (Ctrl+Num-) para borrar todas las marcas.

## Seleccionar o deseleccionar por un patrón

1. Elige Selección > Seleccionar grupo… (Num+) para añadir elementos cuyos nombres coincidan con un patrón, o Selección > Deseleccionar grupo… (Num-) para quitar los coincidentes de las marcas actuales.
2. Escribe una máscara con comodines. Usa `*` para cualquier carácter y `?` para un solo carácter. Separa varias máscaras con un punto y coma, y enumera las excepciones tras una barra vertical: por ejemplo, `*.jpg;*.png` marca todas las imágenes, y `*.*|*.bak` marca todo excepto los archivos de copia de seguridad.

![El diálogo Seleccionar grupo con una máscara de comodines escrita en el campo de patrón](screenshots/select-by-mask.png)
*(Figura: Marcar archivos con una máscara de comodines.)*

## Invertir, misma extensión y restaurar

- **Invertir selección** (Num*, menú Selección) da la vuelta a cada marca: los elementos marcados se desmarcan y viceversa, útil para «todo excepto estos».
- **Seleccionar todos con la misma extensión** (Alt+Num+, menú Selección) marca cada archivo que comparte la extensión del elemento bajo el cursor, así que una pulsación captura todos los archivos `.pdf`, por ejemplo.
- **Restaurar selección** (Num/, menú Selección) recupera tu conjunto anterior de marcas, útil si un comando las borró o marcaste el grupo equivocado.

## Atajos

| Acción | Tecla |
|---|---|
| Alternar marca, bajar | Insert |
| Alternar marca (elemento actual) | Space |
| Seleccionar todo / deseleccionar todo | Ctrl+Num+ / Ctrl+Num- |
| Seleccionar todo (alternativa) | Cmd+A |
| Seleccionar grupo por máscara | Num+ |
| Deseleccionar grupo por máscara | Num- |
| Invertir selección | Num* |
| Seleccionar todos con la misma extensión | Alt+Num+ |
| Restaurar la selección anterior | Num/ |

## Notas

- Las marcas y el cursor son independientes: mover el cursor con las teclas de flecha no cambia lo que está marcado.
- La entrada de la carpeta principal (`..`) nunca puede marcarse.
- Seleccionar grupo, Deseleccionar grupo e Invertir selección coinciden por el nombre del archivo, así que puedes incluir o dejar fuera las carpetas según las opciones del diálogo.
- Cuando termina una copia, un traslado o una eliminación, los elementos gestionados correctamente se desmarcan automáticamente, mientras que los que fallaron permanecen marcados para que puedas reintentarlos.
