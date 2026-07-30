---
title: Transferencias en segundo plano
slug: background-transfers
section: Archivos y carpetas
order: 32
related: [copying-files, downloading-from-url]
---

Las copias, los movimientos, las eliminaciones y las descargas grandes no tienen por qué frenar su trabajo. Peach Commander puede ejecutarlos en segundo plano y reunirlos todos en un mismo lugar: el Gestor de transferencias en segundo plano. Desde ahí puede supervisar el progreso y la velocidad de transferencia de cada tarea, pausarla o reanudarla, cancelarla, o poner tareas en cola para iniciarlas más tarde. Como una tarea en segundo plano se ejecuta por su cuenta, nunca le impide examinar carpetas, abrir archivos o iniciar la siguiente transferencia.

## Cómo hacerlo

1. Inicie una copia, un movimiento, una eliminación o una descarga y elija ejecutarla en segundo plano. La tarea aparece en el Gestor de transferencias en segundo plano.
2. Abra el gestor en cualquier momento desde **Comandos ▸ Gestor de transferencias en segundo plano…** (o pulse Cmd+Shift+B).
3. Cada tarea muestra un título, una barra de progreso y una línea en directo con los archivos completados, los bytes transferidos y la velocidad actual.
4. Use los botones de cada tarea para **Pausar**, **Reanudar** o **Cancelar** mientras una tarea se está ejecutando.
5. Para las tareas que ha añadido pero aún no ha iniciado (tareas retenidas), haga clic en **Iniciar** en la tarea, o en **Iniciar todo** para lanzar de una vez toda la lista de espera.
6. Cuando haya terminado todo lo que le interesa, haga clic en **Borrar finalizadas** para ordenar la lista.

![El Gestor de transferencias en segundo plano con una lista de tareas activas y en espera con barras de progreso y botones de Pausar, Reanudar y Cancelar.](screenshots/transfer-manager.png)

*Cada transferencia es una fila que puede pausar, reanudar o cancelar de forma independiente.*

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir el Gestor de transferencias en segundo plano | Cmd+Shift+B |

## Consejos

- **Limite la velocidad.** Para evitar que una transferencia grande sature su conexión o su disco, establezca un límite de velocidad en el cuadro de diálogo de copia antes de iniciar la tarea. El gestor mostrará entonces la tasa limitada en directo.
- **Ponga en cola para más tarde.** Las tareas retenidas permanecen en la lista sin ejecutarse hasta que pulsa Iniciar (o Iniciar todo), de modo que puede preparar varias transferencias y lanzarlas juntas.
- **Ejecute varias a la vez.** Las tareas se ejecutan de forma independiente, por lo que puede pausar una mientras otra continúa.

## Notas

Como una tarea en segundo plano se ejecuta sin que usted la observe, no puede detenerse para hacer preguntas. Si ya existe un archivo en el destino, la tarea en segundo plano lo sobrescribe; si un elemento concreto no puede transferirse, ese elemento se omite y la tarea continúa. Cuando la tarea finaliza, todos los elementos omitidos se recopilan en un registro de errores para que pueda revisar exactamente qué salió mal.
