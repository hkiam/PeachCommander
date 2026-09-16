---
title: Espacios de trabajo
slug: workspaces
section: Personalización
order: 118
related: [settings, panels-and-tabs]
---

Un espacio de trabajo es un contexto con nombre en el que usted trabaja: «Ordenar las copias de seguridad», «Clasificar candidaturas». Cada uno recuerda ambos paneles, todas las pestañas abiertas, qué pestaña está activa en cada lado, el modo de vista, el árbol de carpetas, el historial de atrás/adelante y qué archivos tenía marcados, el filtro rápido y la disposición de la ventana: el panel lateral, el dock, las barras y dónde está el divisor. Cambiar cuesta un clic, y por el camino nunca se pierde nada: un espacio de trabajo nunca se guarda, porque nunca termina.

Hasta que cree un segundo, no hay nada que ver. Ni barra, ni menú, ni atajos.

## Cómo se hace

1. Prepare ambos paneles para la tarea que tiene entre manos: abra las carpetas, añada las pestañas, elija la vista que quiera.
2. Abra el menú **Ir** y elija **Espacios de trabajo…**, luego **Nuevo espacio de trabajo…**. Póngale un nombre.
3. Aparece una franja de fichas de colores en la parte superior de la ventana, y el menú **Espacio de trabajo** aparece en la barra de menús. El nuevo espacio de trabajo empieza como una copia de la disposición en la que estaba.
4. Prepare el nuevo espacio de trabajo para su propia tarea. Aquel del que venía conserva lo que tenía.
5. Haga clic en una ficha para cambiar, o pulse **Ctrl+1** a **Ctrl+9**. Todo cambia con él.

## Volver a un punto de partida

Cada espacio de trabajo recuerda además la disposición con la que se creó. **Espacio de trabajo ▸ Guardar el estado actual en el espacio de trabajo** (Cmd+Ctrl+S) convierte la disposición actual en ese punto de partida, y **Restablecer al estado guardado** lo devuelve allí tras una tarde de rodeos.

Esto es independiente del recuerdo continuo: nunca tiene que guardar para no perder su sitio.

## La bandeja

Cada espacio de trabajo tiene una bandeja — para lo que de verdad ocurre mientras se ordena: tres
carpetas dentro de las copias de seguridad encuentra algo que pertenece a un trabajo completamente
distinto. **Arrastre archivos a la ficha de otro espacio** y caerán en *su* bandeja: no cambia de
espacio, y no se copia ni se mueve nada; el contador de la ficha sube y usted sigue. Mantenga **⌥** al
soltar para copiar en la carpeta de ese espacio, o **⌘** para mover. **Ctrl+Cmd+A** pone la selección
en la bandeja del espacio actual, la página **Bandeja** del panel lateral muestra su contenido, y
**Espacio de trabajo ▸ Copiar la bandeja al otro panel** hace toda la bandeja en una sola operación.

Los archivos eliminados desde entonces, o en un volumen no montado, se muestran como faltantes en lugar
de quitarse, y una operación en bloque ofrece omitirlos o sacarlos antes. Un movimiento vacía la bandeja
de lo movido; una copia la deja como estaba.

| Acción | Atajo |
| --- | --- |
| Cambiar al espacio de trabajo 1 a 9 | Ctrl+1 … Ctrl+9 |
| Hacer de la disposición actual el punto de partida | Cmd+Ctrl+S |

## Consejos

- Haga clic derecho en una ficha para renombrarla, darle un color o eliminarla — o haga clic en la **✕** de su extremo derecho, que elimina ese espacio de trabajo tras preguntar. El color es lo que le permite distinguir los espacios de trabajo de un vistazo cuando la ventana es estrecha y los nombres ya no caben.
- Nueve es el límite, para que cada ficha siga siendo reconocible.
- **Ver ▸ Mostrar la barra de espacios de trabajo** oculta la franja sin desactivar la función, para quien cambia de espacio con el teclado.
- Los espacios de trabajo se pueden desactivar por completo en **Ajustes ▸ Pestañas**. Sus espacios de trabajo se conservan y vuelven sin cambios cuando vuelve a activar la función.

## Limitar un espacio de trabajo a una carpeta

A un espacio de trabajo se le puede decir de qué se ocupa, y entonces comprueba antes de que una
operación salga fuera. Haga clic derecho en su ficha, **Limitar a una carpeta ▸ Establecer en la
carpeta activa**, y elija si las operaciones fuera se permiten, se preguntan o se rechazan.

Se comprueba antes de que un borrado tome archivos de fuera, antes de que una copia o un movimiento
aterrice fuera, y antes de que un renombrado o una carpeta nueva escriba fuera. **La navegación nunca
se restringe**: un gestor de archivos que se niega a mostrar una carpeta está roto, y todo el valor está
en el instante anterior a F8. Los guardados del editor tampoco están cubiertos; ocurren en su propia
ventana.

## El registro

Cada espacio de trabajo lleva cuenta de lo que se hizo en él: carpetas visitadas, operaciones
realizadas, líneas de shell escritas y todo lo que un límite de carpeta haya rechazado. **Espacio de
trabajo ▸ Registro…** lo muestra, el día más reciente primero, con un filtro **Problemas** para todo lo
que falló o fue detenido.

Retorno repite la fila seleccionada, bajo la misma regla que el historial: solo una copia o un
movimiento se repiten con una pulsación, y una línea de shell se rellena en la línea de órdenes en
lugar de ejecutarse. El registro está deliberadamente separado del historial global: aquel responde a
«dónde suelo ir» y ordena por frecuencia; este responde a «qué pasó aquí» y conserva el orden. Se
elimina con su espacio de trabajo, se conserva sin límite en otro caso, y puede desactivarse en
**Ajustes ▸ Pestañas**.

## Pasar un espacio de trabajo a otra persona

**Espacio de trabajo ▸ Exportar espacio de trabajo…** escribe el espacio de trabajo actual en un
archivo `.pcworkspace` que puede enviar a alguien o guardar en una carpeta de proyecto. **Importar
espacio de trabajo…** lo vuelve a leer, y un doble clic en el Finder también.

Lo que viaja es el **punto de partida guardado** del espacio de trabajo — pulse antes ⌘⌃S si quiere
la disposición que tiene delante — junto con su nombre, su color, su límite de carpeta y su bandeja.
Las carpetas dentro de su carpeta personal se escriben abreviadas, para que el archivo se abra en la
carpeta personal de la *otra* persona y no en una carpeta con su nombre.

Lo que deliberadamente no viaja:

- **Cualquier cosa que pudiera ser una credencial.** Las pestañas que apuntan a una conexión o a una unidad de complemento montada se eliminan al exportar, y el informe dice cuántas. No hay nada que perder, porque no se escribe nada sobre una conexión.
- **El registro.** Anota lo que ha hecho usted y nombra carpetas de su equipo. Se queda aquí.
- Las posiciones del cursor, el historial de deshacer, el tamaño de la ventana y las ventanas abiertas de visor, editor, búsqueda o sincronización.
- Las pestañas del terminal y las conversaciones con el asistente. Pertenecen a este Mac; un archivo de espacio de trabajo lleva *dónde* trabajar, no lo que está en marcha.

Una importación siempre **añade** un espacio de trabajo; nunca sustituye aquel en el que está ni
cambia por su cuenta — un archivo que le han enviado no debe mover su ventana. Las carpetas que no
están en este Mac se abren en la más cercana que sí existe, los elementos de la bandeja conservan sus
rutas y se muestran atenuados, y un límite de carpeta cuya carpeta falta se conserva pero pasa a
preguntar en lugar de rechazar. Un informe enumera todo ello.

## Notas

- Cambiar nunca pregunta si hay que guardar y nunca cierra nada. Las operaciones de archivo en curso continúan, y también todo lo que corra en un terminal: las pestañas del espacio que abandona se apartan con sus shells vivos, no se cierran. Las conversaciones del asistente también siguen al espacio de trabajo.
- Deshacer sigue a un espacio de trabajo solo mientras la aplicación está en marcha: un paso de deshacer lleva consigo la acción que lo revierte, y esa no se puede escribir en el disco.
- Un espacio de trabajo registra ubicaciones de carpetas, no los archivos que contienen. Si una carpeta guardada se ha movido o eliminado, esa pestaña se abre en la carpeta más cercana que aún exista.
- Al actualizar desde una versión anterior: los espacios de trabajo que hubiera guardado se convierten en fichas, y la sesión en la que estaba pasa a ser el primero. No se pierde nada, y el antiguo `workspaces.ini` se conserva como `workspaces.ini.migrated`.
