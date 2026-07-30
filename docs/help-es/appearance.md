---
title: Aspecto
slug: appearance
section: Personalización
order: 114
related: [settings]
---

Peach Commander puede adaptarse al aspecto del resto de su Mac o adoptar un estilo propio. Puede seguir el ajuste de aspecto claro u oscuro del sistema (o forzar uno), recolorear los paneles de archivos, resaltar los archivos por tipo y ajustar el tamaño de la fuente de la lista y el formato de fecha para que los paneles se lean exactamente como usted prefiera.

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

- El ajuste de Aspecto da estilo a los paneles de archivos. Los cuadros de diálogo del sistema, las alertas y los controles estándar siguen siempre a macOS.
- El visor de archivos integrado usa paletas de resaltado de sintaxis claras y oscuras a juego, de modo que el código resaltado sigue siendo legible en cualquiera de los dos aspectos.
- Los colores personalizados y las reglas por tipo de archivo se guardan con sus ajustes y se vuelven a aplicar cada vez que abre la aplicación.
