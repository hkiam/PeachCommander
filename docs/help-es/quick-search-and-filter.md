---
title: Búsqueda rápida y filtro
slug: quick-search-and-filter
section: Organizar la vista
order: 44
related: [searching, view-modes-and-sorting]
---

Cuando una carpeta contiene cientos de elementos, rara vez necesitas desplazarte. Peach Commander te permite saltar directamente a un archivo escribiendo su nombre (búsqueda rápida), reducir la lista solo a los elementos que te interesan (filtro rápido), y mostrar u ocultar los archivos con punto que macOS normalmente mantiene fuera de la vista. Los tres funcionan dentro del panel activo sin abrir un diálogo.

## Saltar a un archivo escribiendo (búsqueda rápida)

1. Haz clic en un panel de archivos para que esté activo.
2. Empieza a escribir el principio de un nombre. El cursor salta al primer elemento coincidente.
3. Sigue escribiendo para afinar la coincidencia, o pasa de una coincidencia a otra con ↑ y ↓ mientras la búsqueda está visible. Pulsar de nuevo la misma letra también recorre los elementos que empiezan por ella.
4. El texto escrito se borra tras una breve pausa, así que puedes iniciar una nueva búsqueda en cualquier momento.

Por omisión, las letras normales van a la línea de comandos y la búsqueda rápida se activa con Ctrl+Option+letra (el comportamiento clásico). Puedes cambiar la búsqueda rápida para que responda a la escritura normal, o desactivarla, en los ajustes de Configuración.

## Filtrar la lista (filtro rápido)

1. En el panel activo, pulsa Ctrl+S para activar el filtro rápido.
2. Escribe una máscara de filtro. El panel se reduce en vivo a los elementos coincidentes mientras escribes, y el cursor permanece en el elemento que estabas mirando mientras la máscara más estrecha lo conserve.
3. Recorre el resultado con ↑ y ↓. En una lista filtrada las flechas dan la vuelta, así que el último elemento lleva de nuevo al principio y un resultado corto se puede recorrer en ciclo sin chocar con los extremos.
4. Pulsa Enter para conservar el resultado y dejar de filtrar. La máscara sigue en vigor y las letras vuelven al panel, así que después puedes escribir para saltar dentro de lo que queda: el filtro y la búsqueda rápida muestran sus propios indicadores uno al lado del otro.
5. Pulsa Esc para borrar el filtro y volver a mostrar todo. El cursor permanece en lo que habías encontrado, ahora mostrado entre sus vecinos.

El filtro admite varios tipos de máscara:

- **Texto plano** coincide con cualquier nombre que contenga lo que escribiste (por ejemplo, `report` muestra todo elemento con «report» en cualquier parte de su nombre).
- **Comodines** usan `*` (cualquier carácter) y `?` (un carácter). Separa varias máscaras con un punto y coma y añade exclusiones tras una barra vertical, por ejemplo `*.jpg;*.png|*thumb*` para mostrar imágenes pero ocultar miniaturas.
- **Etiquetas del Finder** filtran por color de etiqueta: escribe `tag:red` (o `#red`) para mostrar solo elementos con etiqueta roja, o solo `tag:` para mostrar todo lo que lleve alguna etiqueta.

## Mostrar archivos ocultos

Pulsa Ctrl+H, o elige el comando en el menú Visualización, para alternar los elementos ocultos (nombres que empiezan por un punto y archivos ocultos del sistema). El ajuste se aplica al panel activo y se recuerda entre sesiones.

## Atajos

| Acción | Atajo |
| --- | --- |
| Búsqueda rápida (modo clásico) | Ctrl+Option+letra |
| Coincidencia anterior / siguiente (durante la búsqueda rápida) | ↑ / ↓ |
| Filtro rápido activado/desactivado | Ctrl+S |
| Conservar el resultado, dejar de filtrar | Enter |
| Borrar filtro / cancelar | Esc |
| Mostrar/ocultar archivos ocultos | Ctrl+H |

## Notas

- La búsqueda rápida solo mueve el cursor; el filtro rápido cambia realmente qué elementos se listan. Usa el filtro cuando quieras trabajar sobre un subconjunto (por ejemplo, seleccionar o copiar solo las coincidencias).
- Los ajustes de filtro y de archivos ocultos son por panel, así que los dos lados pueden mostrar cosas distintas a la vez.
- La búsqueda rápida coincide con los nombres desde el principio; el modo de texto plano del filtro rápido coincide en cualquier parte del nombre. Usa un comodín como `*texto*` si quieres que el filtro se comporte igual.
