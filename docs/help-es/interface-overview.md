---
title: La ventana principal
slug: interface-overview
section: Primeros pasos
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander muestra dos listas de archivos una al lado de la otra para que pueda ver al mismo tiempo de dónde vienen los archivos y a dónde van. La mayor parte de su trabajo ocurre en estos dos paneles; las barras que los rodean le permiten cambiar de unidad, saltar a una carpeta y ejecutar los comandos de archivo habituales sin apartar las manos del teclado. Este recorrido nombra cada parte de la ventana para que el resto de la ayuda tenga sentido.

![La ventana principal de Peach Commander con sus dos paneles y las barras que los rodean](screenshots/main-window.png)
*(Figura: La ventana principal: dos paneles con la barra de botones, la barra de unidades y las barras de ruta encima, y la barra de teclas de función debajo.)*

## Los dos paneles y el panel activo

La ventana se divide en un panel izquierdo y un panel derecho, cada uno mostrando el contenido de una carpeta. Solo un panel está activo a la vez: muestra el cursor (una fila resaltada) y su barra de ruta se dibuja con un fondo de color. Los comandos como copiar y mover actúan siempre sobre el panel activo y envían los archivos al otro.

1. Haga clic en cualquier lugar de un panel para activarlo, o pulse Tab para alternar entre ellos.
2. Use las teclas de flecha para mover el cursor arriba y abajo por el panel activo.
3. Pulse Enter sobre una carpeta para abrirla, o sobre `..` en la parte superior de la lista para subir un nivel.

## Barras alrededor de los paneles

- **Barra de botones** (arriba): una fila de botones planos para los comandos frecuentes. Haga clic en un botón para ejecutar su comando; haga clic con el botón derecho en un botón para editar la barra.
- **Barra de unidades**: un botón por disco o volumen disponible, cada uno con su espacio libre. Haz clic en un volumen para llevar ese panel allí; haz clic derecho para expulsarlo, algo que se ofrece para volúmenes extraíbles e imágenes de disco montadas y aparece atenuado para el disco de arranque y los recursos de red. Los plugins pueden aportar sus propias unidades — el Task Manager es una — y se comportan como cualquier otro volumen: el panel cambia a ella, su botón sigue seleccionado y la pestaña toma el nombre de la unidad. Cada botón lleva el icono propio del volumen — el mismo que muestra el Finder —, de modo que un disco duro, una memoria USB, una imagen de disco montada y un recurso de red se distinguen de un vistazo.
- **Barra de ruta**: muestra la carpeta actual como una ruta de navegación en la que se puede hacer clic. Haga clic en un segmento para saltar directamente a esa carpeta, o haga clic en la ruta para escribir una ubicación.
- **Barra de estado** (debajo de cada lista): un resumen dinámico del panel: cuántos archivos y carpetas están seleccionados y su tamaño total.
- **Línea de comandos** (abajo): un campo de texto donde puede escribir un comando estilo shell que se ejecuta en la carpeta actual.
- **Barra de teclas de función** (en la parte inferior): seis botones etiquetados como F3 Ver, F4 Editar, F5 Copiar, F6 Mover, F7 Carpeta nueva y F8 Eliminar. Haga clic en un botón o pulse la tecla correspondiente.

![Primer plano de la barra de unidades mostrando los botones de volumen y el espacio libre](screenshots/drive-bar-crop.png)
*(Figura: la barra de unidades: un botón por volumen, con el espacio libre restante; haz clic derecho en un volumen para expulsarlo.)*

## Atajos

| Acción | Atajo |
|---|---|
| Cambiar el panel activo | Tab |
| Abrir la carpeta / el elemento bajo el cursor | Enter |
| Subir una carpeta | Backspace |
| Ver archivo | F3 |
| Editar archivo | F4 |
| Copiar al otro panel | F5 |
| Mover / renombrar al otro panel | F6 |
| Carpeta nueva | F7 |
| Eliminar (a la Papelera) | F8 |

## Notas

- La barra de teclas de función se vuelve a etiquetar en directo cuando mantiene pulsado un modificador. Mantener pulsado Shift, por ejemplo, cambia F6 por una acción de renombrar sobre la marcha, de modo que los botones siempre muestran lo que harán las teclas en ese momento.
- Casi todas las barras pueden mostrarse u ocultarse. Consulte los menús Vista y Configuración para activar y desactivar la barra de botones, la barra de unidades, la línea de comandos o la barra de teclas de función, o para apilar los dos paneles arriba y abajo en lugar de uno al lado del otro.
- En muchos teclados de Mac, las teclas F actúan de forma predeterminada como controles de medios y de brillo. Mantenga pulsada la tecla Fn junto con F3-F8, o active "Usar las teclas F1, F2, etc. como teclas de función estándar" en Ajustes del Sistema, para usarlas directamente.
