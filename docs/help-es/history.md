---
title: Historial global
slug: history
section: Organizar la vista
order: 47
related: [favorites, navigating]
---

El historial global es una ventana que recuerda tu propio trabajo: carpetas visitadas, archivos abiertos, operaciones realizadas y comandos ejecutados. Pulsa Ctrl+Cmd+H desde cualquier sitio, empieza a escribir y vuelves a la carpeta de ayer en un segundo, sin ratón.

## Abrir el historial

1. Pulsa Ctrl+Cmd+H o elige **Ir > Historial…**. No importa qué panel esté activo.
2. Escribe unas letras. La coincidencia no tiene que ser exacta ni contigua: `proj rep` encuentra `~/Projects/annual-report.txt`.
3. Recorre los resultados con las flechas Arriba y Abajo mientras sigues escribiendo.
4. Retorno actúa sobre la entrada resaltada; Esc cierra la ventana.

Las entradas se ordenan por lo reciente *y* lo frecuente de su uso, así que los sitios donde más trabajas ya están arriba. Las entradas fijadas siempre encabezan la lista.

## Filtrar por tipo

Los botones bajo el campo de búsqueda limitan la lista a todas las entradas, carpetas, archivos, operaciones o favoritos. Option+1 a Option+5 cambian entre ellos con el teclado.

## Actuar sobre una entrada

| Acción | Atajo |
| --- | --- |
| Abrir la entrada resaltada | Return |
| Mostrarla en el panel, con el cursor encima | Option+Return |
| Abrir una de las nueve entradas más relevantes | Cmd+1 … Cmd+9 |
| Cambiar el panel donde se abren | Tab |
| Fijar o soltar la entrada | Cmd+P |
| Quitar la entrada del historial | Cmd+Delete |
| Copiar la ruta de la entrada | Option+Cmd+C |
| Mostrar la entrada en el Finder | Cmd+Shift+R |
| Cerrar el historial | Esc |

Retorno hace lo que corresponde a la entrada: una carpeta se abre en el panel de destino, un archivo se abre como lo haría desde el panel y una línea de comandos se coloca en la línea de comandos para que la revises y la ejecutes. El panel de destino se indica al pie de la ventana y Tab lo cambia.

## Repetir una operación

Una copia o un movimiento aparece en **Operaciones**, y Retorno lo ejecuta de nuevo: los mismos elementos a la misma carpeta, por la cola de transferencia normal y sus preguntas de sobrescritura. Los elementos que ya no existen se omiten, y si no queda ninguno se te avisa.

Las eliminaciones y los cambios de nombre aparecen listados pero nunca se repiten: Retorno muestra dónde ocurrieron. Repetir una eliminación no debería estar a una tecla de distancia en una lista que solo estás ojeando.

## Mantenerlo bajo control

Ajustes ▸ Varios decide si se guarda un historial, cuántas entradas conserva y tras cuántos días las olvida. Las entradas fijadas están exentas y 0 días lo conserva todo; la lista vive en `history.ini` dentro de tu carpeta de configuración y sobrevive a los reinicios.

## Notas

- Abrir algo desde el historial cuenta como usarlo: por eso lo que retomas sigue subiendo.
- También se recuerdan carpetas en servidores y en unidades de complementos; una que ya no esté accesible lo dice al intentarlo.
- No es el historial de carpetas propio del panel en Alt+Abajo, que solo enumera por dónde ha pasado ese panel, en orden.
