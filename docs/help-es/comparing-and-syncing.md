---
title: Comparar y sincronizar
slug: comparing-and-syncing
section: Herramientas avanzadas
order: 90
related: [multi-rename]
---

Cuando mantiene dos copias de la misma carpeta —una carpeta de trabajo y una de respaldo, un portátil y un recurso compartido de red, un proyecto y su archivo comprimido—, Peach Commander le ayuda a ver exactamente qué ha cambiado y a poner los dos lados de nuevo en sintonía. Puede sincronizar dos directorios, comparar archivos individuales línea a línea e inspeccionar archivos byte a byte cuando necesita certeza hasta el último carácter.

## Sincronizar dos directorios

1. Abra la carpeta que desea sincronizar en el panel izquierdo y la carpeta con la que compararla en el panel derecho.
2. Elija **Comandos ▸ Sincronizar directorios…**. Las dos rutas de carpeta se rellenan a partir de sus paneles.
3. Defina cuán exhaustiva debe ser la comparación: incluir subcarpetas, comparar **por contenido** (no solo por fecha y tamaño), o ignorar la fecha de modificación.
4. Añada una máscara de filtro (por ejemplo, `*.jpg;*.png`) si solo quiere sincronizar ciertos archivos.
5. Revise la cuadrícula de resultados. Cada fila muestra un archivo a la izquierda, una flecha de dirección en el centro y el archivo correspondiente a la derecha. Las flechas le indican lo que sucederá: **→** copia de izquierda a derecha, **←** copia de derecha a izquierda, y **=** significa que ambos son idénticos.
6. Ajuste filas individuales si no está de acuerdo con una dirección sugerida y, a continuación, haga clic en el botón de sincronizar para llevar a cabo los cambios.

![La ventana de sincronizar directorios con dos rutas de carpeta y una cuadrícula de resultados de archivos con flechas izquierda, igual y derecha](screenshots/sync-dialog.png)
*(Figura: La ventana Sincronizar directorios compara ambos lados y propone una dirección de copia para cada archivo.)*

Haga clic con el botón derecho en una fila para ver los archivos que hay detrás. **Comparar** abre los dos lados uno al lado del otro, mientras que **Ver archivo izquierdo** y **Ver archivo derecho** abren un solo lado en el visor: esa es la respuesta para una fila que solo existe en un lado, donde no hay nada que comparar. Las entradas que no se pueden aplicar a la fila en la que hizo clic aparecen atenuadas en lugar de no hacer nada. Un archivo dentro de un `.zip` o en un servidor se descomprime o descarga primero en una copia temporal de solo lectura, de modo que el original nunca se toca. Lo mismo vale para **Comparar**, de modo que una carpeta puede compararse con un archivo comprimido o con un servidor, y los botones de fusionar y guardar siguen desactivados para ese lado, porque lo que está abierto ahí es la copia.

## Comparar dos archivos por contenido

1. Seleccione un archivo en cada panel (o dos archivos en el mismo panel).
2. Elija **Archivo ▸ Comparar por contenido…**.
3. Los dos archivos se abren uno al lado del otro con sus diferencias resaltadas. Use los controles de siguiente/anterior para saltar entre los bloques modificados.
4. Si activa el modo de edición, puede ajustar cualquiera de los dos archivos directamente y guardar sus cambios.

![La ventana de comparación mostrando dos archivos de texto uno al lado del otro con las líneas diferentes resaltadas](screenshots/diff-window.png)
*(Figura: Comparando dos archivos de texto; las líneas modificadas se resaltan en ambos lados.)*

Cuando los dos archivos no tienen ninguna diferencia, la ventana lo dice en una banda de color en la parte superior, en lugar de dejar que lo deduzca de una tabla en la que no hay nada resaltado. La banda aparece también, en un color de advertencia, cuando un archivo no se pudo leer en absoluto: entonces cualquier veredicto sobre diferencias sería una afirmación sobre una comparación que nunca ocurrió. La comparación byte a byte dice lo mismo por la misma razón: dos archivos que no puede abrir no son dos archivos idénticos.

## Comparar archivos byte a byte

Cuando dos archivos parecen iguales pero necesita demostrar que son realmente idénticos (o encontrar el único byte que difiere), use la comparación binaria. Muestra ambos archivos en una vista hexadecimal con los bytes que no coinciden marcados, lo que resulta ideal para verificar descargas, comprobar datos codificados o confirmar una copia exacta.

## Comparar los listados de directorios

Para detectar de un vistazo las diferencias entre dos carpetas abiertas, elija **Marcar ▸ Comparar directorios** (Shift+F2). Peach Commander marca los archivos que difieren o que faltan en el otro lado, de modo que pueda actuar sobre ellos con los comandos habituales de copiar, mover y eliminar.

## Limitar lo que abarca una sincronización

El campo de máscara contiene una lista de inclusión sobre los nombres de archivo. Para lo que no puede expresar, **Filtro…** al lado abre una hoja con tres pestañas. Lo que se defina allí se aplica a la *siguiente* comparación, y el botón indica entonces cuántos criterios están activos: un filtro que no se ve es la forma en que una copia de seguridad acaba incompleta mientras la ventana informa de que ha terminado.

- **Excluir** admite patrones separados por `;` o `|`. Un nombre sin barra coincide a cualquier profundidad (`*.tmp`), una barra final designa una carpeta y todo lo que contiene (`node_modules/`), y un patrón con barra coincide con la ruta relativa (`src/*/generated`). No se distinguen mayúsculas y minúsculas.
- El **tamaño** y la **fecha** juzgan una pareja en conjunto: si uno de los lados queda fuera del intervalo, la pareja entera queda fuera. Es intencionado. Aplicada a un solo lado, una exclusión haría que la pareja pareciera unilateral y se convertiría en una copia en el sentido equivocado.
- **En los últimos N días** se mide desde cada comparación, no desde que se guardó un ajuste, de modo que una tarea guardada sigue significando «el último mes».
- La pestaña **Plugins** pregunta a un plugin de contenido por el lado desde el que se copiaría un archivo. Necesita un archivo real, así que solo se ofrece cuando ambos lados son carpetas de este Mac.

Una carpeta excluida tampoco se elimina en modo espejo: un espejo solo retira lo que realmente ha comparado. La línea de estado indica cuántas entradas ha retenido el filtro, junto a lo que hará la ejecución. Un filtro se guarda y se carga con el ajuste de sincronización al que pertenece.

## Mantener dos carpetas iguales, en ambos sentidos

Los dos modos originales no distinguen una cosa: un archivo que está en un solo lado es **nuevo aquí**
o **eliminado allí**, y ambos casos se ven igual. El modo simétrico lo copia —elimine algo en el
portátil, sincronice, y vuelve desde la copia de seguridad— y el modo espejo elimina, pero solo en un
sentido.

**Ambos sentidos (con memoria)** recuerda cómo estaban las dos carpetas la última vez que coincidían.
Con ese registro, una eliminación en un lado puede trasladarse al otro.

- La **primera** ejecución de un par no tiene registro: se comporta como antes y no elimina nada.
  Escribe el registro. El modo actúa a partir de la segunda.
- Una eliminación trasladada se muestra en su propio color con `⇒🗑` y **no** está marcada: es la única
  fila que proviene de la memoria de la aplicación. Al hacer clic en la flecha se ofrecen las otras
  respuestas: copiar el archivo de vuelta, o dejar ambos lados como están.
- Modificado en un lado y eliminado en el otro es un **conflicto**, nunca una eliminación. Igual que
  un archivo modificado en ambos lados.
- Nada se elimina por una ausencia que la comparación no pudo confirmar — una carpeta ilegible, o
  una que el filtro retuvo, no demuestra nada sobre lo que hay dentro.
- Solo dos carpetas de este Mac. Ni un servidor ni un archivo comprimido: un borrado en un archivo
  comprimido lo reescribe, un borrado en un servidor es permanente, y este modo no es aquel con el
  que probar eso.

**Una eliminación no se puede deshacer.** En este Mac el archivo va a la Papelera y puede recuperarse
desde el Finder; eso es toda la red. **Memoria…** en la ventana enumera cada par que la aplicación recuerda, señala el que está viendo y permite olvidar cualquiera de ellos; después, la siguiente comparación de esas carpetas vuelve a comportarse como una primera. Nunca se olvida nada por su cuenta: una carpeta en un disco desmontado no ha desaparecido, solo está desconectada.

El registro vive con los ajustes: mover una de las carpetas deja
al par sin historial — y una ejecución sin historial no elimina nada.

## Qué hizo una ejecución, y qué de ello se puede recuperar

Cada sincronización queda anotada. **Ejecuciones…** en la ventana las enumera, las más recientes primero — cuándo, qué dos carpetas, qué modo y cuántos archivos se copiaron, borraron o se dejaron fuera — y muestra qué le pasó a cada archivo de la ejecución que seleccione.

Esa lista es lo que hace útil la Papelera. Un archivo que este Mac borró fue a la Papelera, y la ejecución anotó *dónde*, lo cual importa más de lo que parece: la Papelera renombra al haber colisión, así que un segundo `notes.txt` aterriza como `notes.txt 11-17-15-028.txt`, y buscarlo por el nombre da con el equivocado. **Mostrar en la Papelera** lleva al Finder directo al elemento.

**Devolver…** saca de la Papelera los archivos que una ejecución borró y los lleva a las rutas de las que se borraron. Cada uno se comprueba antes, y lo que no se sostiene se rechaza con su motivo en lugar de forzarse:

- Hay algo de nuevo en esa ruta. Se deja en paz — una devolución nunca puede sobrescribir.
- El elemento ya no está en la Papelera, o se eliminó de forma permanente en vez de enviarse allí.
- El lado era un archivo comprimido o un servidor. Un archivo comprimido se reescribe entero, y un
  servidor no tiene Papelera, así que no se guardó nada.
- La carpeta en la que escribió la ejecución ya no está, o ya no es la misma carpeta — un punto de
  montaje reutilizado, por ejemplo. Entonces se rechaza la ejecución entera en lugar de actuar sobre
  una parte de ella.
- Ya se devolvió. El registro lo conserva, así que un segundo intento no hace nada.
- O el registro mismo es uno sobre el que esta versión no puede actuar — escrito por una versión más
  nueva de la aplicación, o nombrando una ruta fuera de ambas carpetas. Raro, y rechazado en vez de
  adivinado.

**Una copia no se puede recuperar.** Quitarla significaría borrar un archivo que quizá haya editado desde entonces, que es el intercambio opuesto al de devolver un borrado, así que la aplicación no lo ofrece — la ejecución le dice qué archivos copió y puede borrarlos usted mismo. Un archivo que fue *sobrescrito* es el único hueco real, y ahora es pequeño: en este Mac la versión reemplazada va a la Papelera como un archivo borrado, así que **Mostrar en la Papelera** la encuentra. Hacia un archivo comprimido, hacia un servidor o hacia un volumen sin Papelera no puede, y la confirmación lo dice antes de la ejecución.

Se conservan las últimas 200 ejecuciones, o 64 MB de ellas, lo que ocurra primero; pasado eso las más antiguas van cayendo de una en una según llegan nuevas, y **Olvidar** y **Olvidar todo** las borran al momento. Una ejecución muy grande — más de 20.000 archivos — conserva cada problema y todo lo que puso en la Papelera, pero no las copias que salieron bien, y lo dice en vez de dejar que usted lo note. Sus borrados se pueden seguir devolviendo: lo que quedó fuera son las copias, y una copia no se habría podido recuperar de todos modos.

Olvidar no cambia nada en las carpetas; lo que se va es el registro de lo que se hizo, y con él la oferta de devolver algo. A diferencia de la memoria bidireccional, esto se tira automáticamente — perder la memoria de un *par* cambiaría lo que hace la siguiente ejecución, mientras que perder el registro de una ejecución solo quita una oferta.

## Atajos

| Acción | Atajo |
| --- | --- |
| Comparar los listados de directorios (marcar archivos diferentes) | Shift+F2 |
| Comparar por contenido | Archivo ▸ Comparar por contenido… |
| Sincronizar directorios | Comandos ▸ Sincronizar directorios… |
| Ver un lado de una fila de sincronización | Clic derecho en la fila ▸ Ver archivo izquierdo / Ver archivo derecho |

## Notas

- **Por contenido frente a por fecha/tamaño.** Una comparación rápida empareja los archivos por tamaño y fecha de modificación, lo cual es veloz pero puede llevar a error cuando las marcas de tiempo difieren en archivos idénticos. Active **por contenido** para obtener un resultado fiable a costa de leer cada archivo.
- **Subcarpetas y filtros.** La ventana de sincronización puede descender por las subcarpetas y puede limitarse con una máscara de filtro, de modo que puede sincronizar solo los tipos de archivo que le interesan.
- **Usted mantiene el control.** La sincronización nunca se ejecuta por su cuenta: usted revisa las direcciones propuestas en la cuadrícula de resultados y puede cambiar cualquiera de ellas antes de que se copie nada. **Esc** detiene una comparación en curso y cierra la ventana cuando no hay ninguna.
- **Preajustes.** Las configuraciones de sincronización de uso frecuente pueden guardarse y reutilizarse para no tener que volver a introducir las mismas opciones cada vez. Un preajuste recuerda también lo que muestra la cuadrícula de resultados —el filtro de dirección y **Ocultar los idénticos**— y la ventana se abre con el preajuste que usó por última vez. Un preajuste **Predeterminado** está disponible desde la primera vez que abre la ventana; guarde sobre él para hacerlo suyo.

