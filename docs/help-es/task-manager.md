---
title: Task Manager
slug: task-manager
section: Complementos
order: 125
related: [plugins, viewing-files, deleting-files]
---

El complemento Task Manager convierte los procesos en ejecución de su Mac en una carpeta que puede explorar. Aparece como una unidad **TaskManager** en la barra de unidades; ábrala y cada proceso es una fila que puede ordenar, inspeccionar como un archivo o finalizar, usando las mismas teclas que ya utiliza para los archivos. Al ser un complemento, puede desactivarlo o eliminarlo desde **Configuración ▸ Complementos…**.

## Abrirlo

1. Haga clic en la entrada **📊 TaskManager** de la barra de unidades (está justo después de su unidad de arranque).
2. El panel se llena con una fila por cada proceso en ejecución. El nombre de cada fila es el nombre del proceso seguido de su PID, por ejemplo `Finder (462)`.

![El Task Manager listando procesos en ejecución con las columnas PID, CPU, memoria y comando](screenshots/task-manager.png)
*(Figura: procesos en ejecución mostrados como una lista de archivos que puede ordenar y sobre la que puede actuar.)*

## Qué significa cada columna

Junto a las columnas habituales de Tamaño (memoria) y Fecha (hora de inicio), Task Manager añade columnas de proceso:

| Columna | Significado |
| --- | --- |
| **PID** | Identificador del proceso |
| **CPU %** | Uso reciente del procesador (necesita una segunda actualización para aparecer) |
| **Threads** | Número de hilos |
| **State** | R en ejecución · S durmiendo · T detenido · Z zombi · I inactivo |
| **User** | Propietario |
| **PPID** | Identificador del proceso padre |
| **Command** | Línea de comandos completa |

Ordene por cualquier columna (por ejemplo CPU % o Tamaño/memoria) igual que lo haría en una carpeta normal.

## Inspeccionar o finalizar un proceso

- **Ver (F3)** muestra un informe de *Información del proceso*: nombre, PID, padre, usuario, estado, hilos, memoria, CPU, hora de inicio, ruta del ejecutable y la línea de comandos completa.
- **Eliminar (F8)** finaliza el proceso. La primera eliminación envía una **salida** ordenada (SIGTERM); eliminar por segunda vez un proceso que sigue en ejecución escala a una **salida forzada** (SIGKILL). El complemento nunca actúa sobre el PID 1.

## Notas

- Los detalles básicos (PID, padre, usuario, estado) se pueden leer para cualquier proceso, como con `ps`. La memoria, los hilos y la CPU solo se pueden leer para **sus propios** procesos; los demás procesos muestran esas columnas en blanco (requieren privilegios elevados, una ampliación posterior).
- CPU % es un cambio entre dos muestras, por lo que aparece en blanco hasta que el panel se actualiza por segunda vez (el panel se actualiza aproximadamente cada dos segundos).
- La lista es de solo lectura salvo por la finalización de un proceso: no puede copiar archivos dentro de ella.
