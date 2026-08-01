---
title: Aspecto
slug: appearance
section: Personalización
order: 114
related: [settings]
---

Peach Commander puede adaptarse al aspecto del resto de su Mac o adoptar un estilo propio. Puede seguir el ajuste de aspecto claro u oscuro del sistema (o forzar uno), recolorear los paneles de archivos, resaltar los archivos por tipo y ajustar el tamaño de la fuente de la lista y el formato de fecha para que los paneles se lean exactamente como usted prefiera.

## Elegir un tema de color

Un tema sustituye toda la paleta de los paneles de una sola vez.

1. Abra la ventana de ajustes eligiendo Configuración > Opciones…, o pulse Cmd+,.
2. Seleccione la página **Colores**.
3. Elija en el menú **Tema**:
   - **Sistema (por omisión)** — sin tema. Los paneles siguen el ajuste Aspecto de más abajo, exactamente como siempre. Es el valor por omisión.
   - **Claro** / **Oscuro** — fijar la paleta clara u oscura integrada, independientemente de lo que haga macOS.
   - **Medianoche** — un tema oscuro que no es solo gris: paneles de índigo profundo con texto azul grisáceo suave, línea del cursor blanca y ámbar para los archivos marcados.
   - **Norton Commander** — el aspecto azul y cian del gestor de archivos original de DOS, con sus auténticos colores CGA: paneles azules, texto cian, línea del cursor en cian claro y amarillo para los archivos marcados.

Un tema aporta su propia base clara/oscura, de modo que las hojas, las barras de desplazamiento y los controles estándar concuerden con él; por eso el menú **Aspecto** aparece atenuado mientras hay un tema seleccionado. Los colores personalizados de los paneles (más abajo) siguen teniendo prioridad sobre el tema.

![Peach Commander con la paleta Norton Commander](screenshots/theme-norton.png)
*(Figura: la paleta Norton Commander: el azul, el cian y el amarillo CGA originales.)*

El tema Norton Commander usa los valores CGA auténticos del original de 1986: `#0000AA` azul, `#00AAAA` cian, `#55FFFF` para la línea del cursor y `#FFFF55` para los archivos marcados. La barra del cursor se invierte a texto oscuro sobre cian, tal como la dibujaba el original, mientras que los archivos marcados conservan su amarillo.

![Detalle de la línea del cursor en la paleta Norton](screenshots/theme-norton-cursor-crop.png)
*(Figura: la barra del cursor se invierte; los archivos marcados siguen en amarillo.)*

![La página de ajustes Colores con la paleta Norton Commander](screenshots/theme-norton-settings.png)
*(Figura: las ventanas propias de la aplicación también siguen el tema.)*

Los temas son solo colores. La disposición de los paneles, los marcos y las tipografías no cambian: Norton Commander no devuelve los bordes de doble línea ni la tipografía de mapa de bits de DOS.

## Escribir su propio tema

Los temas son archivos de texto sencillos, uno por tema, en una carpeta `themes` dentro de su carpeta de configuración.

1. En la página **Colores**, pulse **Carpeta de temas…**. La carpeta se crea si no existe y, la primera vez que está vacía, Peach Commander deja en ella un archivo comentado `example-norton.ini` que enumera todos los colores que puede definir.
2. Copie ese archivo, póngale un nombre nuevo y edítelo. El nombre del archivo (sin `.ini`) es el identificador del tema; la línea `Name` es lo que muestra el menú Tema.
3. Guarde. Abra de nuevo el menú **Tema**: su tema está en la lista. No hace falta reiniciar.

Un tema mínimo son tres líneas:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander con un tema escrito por el usuario](screenshots/theme-custom.png)
*(Figura: un tema cargado desde un archivo de la carpeta de temas.)*

`Base` elige la paleta integrada (`light` u `dark`) que aporta todos los colores que usted no indique, así que solo escribe lo que quiere cambiar. Los colores se indican como `#RRGGBB`. Las líneas que empiezan por `;` o `#` son comentarios.

Si algo del archivo está mal, Peach Commander omite esa línea y conserva el resto de su tema: no rechaza el archivo. El motivo se escribe en el registro del sistema, visible en Consola si filtra por `[theme]`.

Los nombres `light`, `dark`, `norton` y `system` pertenecen a los temas integrados; un archivo que use uno de ellos se omite para que no pueda ocultar un tema incluido. Si borra el archivo del tema seleccionado, Peach Commander vuelve a **Sistema (por omisión)**.
## Definir el aspecto claro, oscuro o del sistema

1. Abra la ventana de ajustes eligiendo Configuración > Opciones…, o pulse Cmd+,.
2. Seleccione la página **Colores**.
3. En el menú **Aspecto**, elija una de estas opciones:
   - **Sistema (seguir a macOS)**: se adapta automáticamente al ajuste claro/oscuro actual de su Mac.
   - **Claro**: usa siempre la paleta clara.
   - **Oscuro**: usa siempre la paleta oscura.

![Página de ajustes de Colores mostrando el menú Aspecto y los selectores de color personalizados del panel](screenshots/settings-colors.png)
*(Figura: La página Colores: elija un aspecto e invalide los colores de panel individuales.)*

## Personalizar los colores del panel

En la misma página **Colores**, en **Colores de panel personalizados**, active la casilla situada junto a cualquier elemento y elija un color en el selector contiguo:

- **Texto**: los nombres de archivos y carpetas.
- **Fondo**: el fondo del panel.
- **Texto seleccionado**: el color usado para los archivos marcados.
- **Marco del cursor**: el contorno alrededor del elemento actual.

Deje una casilla desactivada para conservar el color integrado de ese elemento. Haga clic en **Restablecer valores predeterminados** para borrar todas las invalidaciones de una vez.

## Colorear los archivos por tipo

1. Abra Configuración > Opciones… y seleccione la página **Visualización**.
2. Haga clic en **Colores por tipo de archivo…**.
3. Añada una regla con una máscara de nombre como `*.zip` o `*.txt` y, a continuación, elija un color para los archivos que coincidan con ella.
4. Use **Añadir regla** para más máscaras; haga clic en **Aceptar** para guardar o **Cancelar** para descartar.

Los archivos coincidentes aparecerán entonces en el color elegido en ambos paneles.

## Ajustar el tamaño de la fuente y el formato de fecha

En la página **Visualización** también puede:

- Elegir el **tamaño de la fuente** de la lista del panel en puntos.
- Introducir un patrón de **formato de fecha** para controlar cómo se muestran las fechas de modificación; déjelo vacío para usar el formato regional de su Mac. Aparece una vista previa en directo debajo del campo a medida que escribe.
- Activar el **fondo de fila alterno** para conseguir un rayado tipo cebra que facilita examinar las listas largas.

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir ajustes | Cmd+, |

## Notas

- El menú Aspecto solo actúa mientras el tema sea **Sistema (por omisión)**; un tema define su propia base.
- Un tema también colorea las ventanas propias de la aplicación. Las ventanas del sistema —Abrir, Guardar, los selectores de color y tipografía y las alertas— mantienen su aspecto estándar, igual que las ventanas que abren los módulos.
- El ajuste de Aspecto da estilo a los paneles de archivos. Los cuadros de diálogo del sistema, las alertas y los controles estándar siguen siempre a macOS.
- El visor de archivos integrado usa paletas de resaltado de sintaxis claras y oscuras a juego, de modo que el código resaltado sigue siendo legible en cualquiera de los dos aspectos.
- Los colores personalizados y las reglas por tipo de archivo se guardan con sus ajustes y se vuelven a aplicar cada vez que abre la aplicación.
