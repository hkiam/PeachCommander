---
title: System Monitor
slug: system-monitor
section: Complementos
order: 124
related: [plugins, settings]
---

El complemento System Monitor coloca una lectura en tiempo real de la actividad de su Mac directamente en la barra de título de la ventana: pequeñas fichas para CPU, memoria, disco, red y —donde el hardware las expone— GPU, batería y sensores. Cada ficha se actualiza una vez por segundo; haga clic en una para obtener una ventana emergente con un gráfico de historial y un desglose detallado. Al ser un complemento, puede activarlo, configurarlo o eliminarlo desde **Configuración ▸ Complementos…**.

## Las fichas de la barra de título

Cuando el complemento está activado, una fila de fichas compactas se sitúa en la barra de título. Cada ficha es un punto de color, una etiqueta breve y un valor en vivo (algunas con una minigráfica en línea):

| Ficha | Muestra |
| --- | --- |
| **CPU** | Carga del procesador, con detalle por núcleo |
| **RAM** | Memoria usada / total (más fija, comprimida, swap) |
| **HDD** | Espacio del volumen de arranque y rendimiento de lectura/escritura |
| **Net** | Tasas y totales de descarga / subida |
| **GPU** · **Batt** · **Sens** | Uso de GPU · carga y estado de la batería · velocidades de ventilador y temperaturas |

Haga clic en una ficha para abrir una ventana emergente con el valor actual en grande, una minigráfica **HISTORY**, una lista clave/valor **DETAILS** y —para la CPU— una lista **CORE LOAD** con barras por núcleo.

## Configurarlo

Elija **Comandos ▸ System Monitor…** (o abra **Configuración ▸ Ajustes ▸ System Monitor**) para configurar la lectura:

- **Mostrar el monitor del sistema en la barra de título** — el interruptor principal de las fichas.
- **Perfil** — los preajustes *Mínimo*, *Medio* o *Máximo*, que eligen un conjunto sensato de módulos.
- **La tabla de módulos** — active o desactive cada módulo (CPU, GPU, RAM, HDD, Net, Batt, Sens), elija su color y arrastre las filas para fijar el orden en que aparecen en la barra de título. Los módulos que su hardware no puede informar se muestran como *(n/a)*.

![Los ajustes de System Monitor con su tabla de módulos, perfiles y colores por módulo](screenshots/system-monitor.png)
*(Figura: elija qué módulos aparecen, sus colores y su orden.)*

## Notas

- Todo se mide, nunca se inventa: los módulos cuyos datos el hardware no expone (a menudo GPU o sensores en algunos Mac) permanecen no disponibles en lugar de mostrar cifras inventadas. La batería no está disponible en equipos de escritorio.
- El muestreo se ejecuta en un temporizador en segundo plano solo mientras la lectura está visible, y conserva unos 30 minutos de historial para los gráficos.
- Su selección de módulos, colores y orden se guardan con la configuración de la app.
