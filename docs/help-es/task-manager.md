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
3. El botón **TaskManager** sigue seleccionado mientras estás dentro y la pestaña toma el nombre de la unidad. Cambia a otra pestaña y vuelve — o cierra y vuelve a abrir la app — y la pestaña recupera la lista de procesos. Para salir, sube un nivel o haz clic en otro volumen de la barra de unidades.

![El Task Manager listando procesos en ejecución con las columnas PID, CPU, memoria y comando](screenshots/task-manager.png)
*(Figura: procesos en ejecución mostrados como una lista de archivos que puede ordenar y sobre la que puede actuar.)*

## Qué significa cada columna

Junto a la columna Fecha (hora de inicio), Task Manager añade columnas de proceso. El Tamaño de una fila de proceso muestra `DIR`, porque un proceso es una carpeta que puedes abrir (ver más abajo): la memoria tiene columnas propias:

| Columna | Significado |
| --- | --- |
| **PID** | Identificador del proceso |
| **CPU %** | Uso reciente del procesador (necesita una segunda actualización para aparecer) |
| **Memory** | Huella de memoria: de lo que responde este proceso (la cifra que muestra el Monitor de Actividad) |
| **Resident** | Tamaño residente, páginas compartidas incluidas; se rellena para todos los procesos |
| **Threads** | Número de hilos |
| **State** | R en ejecución · S durmiendo · T detenido · Z zombi · I inactivo, más los sufijos que añade `ps` (s = líder de sesión, + = primer plano, N = prioridad baja) |
| **User** | Propietario |
| **PPID** | Identificador del proceso padre |
| **Read** | Bytes leídos del disco desde que arrancó el proceso |
| **Written** | Bytes escritos en el disco desde que arrancó el proceso |
| **Wakeups** | Reactivaciones por interrupción desde que arrancó el proceso |
| **Signed** | Quién firmó el programa: Apple, un equipo con Developer ID, ad-hoc o sin firmar |
| **Command** | Línea de comandos completa |

Ordene por cualquier columna (por ejemplo CPU % o Tamaño/memoria) igual que lo haría en una carpeta normal.

## Inspeccionar o finalizar un proceso

- **Ver (F3)** muestra un informe de *Información del proceso*: nombre, PID, padre, usuario, estado, hilos, memoria, CPU, hora de inicio, ruta del ejecutable y la línea de comandos completa.
- **Eliminar (F8)** finaliza el proceso. La primera eliminación envía una **salida** ordenada (SIGTERM); eliminar por segunda vez un proceso que sigue en ejecución escala a una **salida forzada** (SIGKILL). El complemento nunca actúa sobre el PID 1.

## Encontrar los procesos que usan un archivo

Haz clic derecho en cualquier fila y elige **Buscar procesos por archivo…**, luego introduce la ruta de un archivo. Se resalta cada proceso que tiene ese archivo abierto en ese momento, y el cursor salta al primero que puede modificarlo:

- **Azul** — el proceso solo lee el archivo.
- **Naranja** — el proceso solo escribe en él.
- **Morado** — el proceso hace ambas cosas.

La ruta se rellena a partir del cursor del otro panel, así que puedes señalar un archivo allí y preguntar sin escribir. **Buscar proceso por puerto…**, en el mismo menú, responde a la pregunta hermana: qué proceso está escuchando en un puerto TCP/UDP. Elige **Quitar resaltado de archivo** para eliminar los colores; salir de la lista de procesos también los elimina.

## Abre un proceso para ver sus archivos

Pulsa Intro sobre un proceso — o haz doble clic — y el panel lista los archivos que ese proceso tiene abiertos en ese momento, como filas de archivo normales con su tamaño y su fecha reales. Desde ahí:

- **Ver (F3)** abre el archivo en sí.
- **Ir al archivo** lo muestra en el otro panel, donde puedes trabajar con él.
- **Mostrar en el Finder** se lo entrega al Finder.

Solo cuentan los archivos abiertos: una biblioteca que el proceso solo ha mapeado en memoria, y su directorio de trabajo, no son archivos abiertos. El proceso de otro usuario muestra una carpeta vacía.

## Notas

- Los datos básicos (PID, padre, usuario, estado, firma) se pueden leer para todos los procesos. La huella de memoria, los hilos, la E/S de disco y la lista de archivos abiertos se pueden leer para **tus propios** procesos, que en un Mac normal son la mayor parte de la lista. Para los procesos de otros usuarios, CPU y Resident se rellenan desde `ps` — una media de toda la vida del proceso en lugar de la diferencia entre dos medidas que llevan las demás filas — y los hilos y la huella quedan en blanco.
- CPU % es un cambio entre dos muestras, por lo que aparece en blanco hasta que el panel se actualiza por segunda vez (el panel se actualiza aproximadamente cada dos segundos).
- La lista es de solo lectura salvo por la finalización de un proceso: no puede copiar archivos dentro de ella.
- Los colores del resaltado siguen tu tema de color: la paleta Norton usa verde, rojo y magenta en su lugar.
- Solo se encuentran los descriptores que tu cuenta puede inspeccionar, lo que en la práctica significa tus propios procesos. Una biblioteca que un proceso solo ha mapeado en memoria, o su directorio de trabajo, no es un descriptor abierto y no se informa.
- La columna **Signed** se va rellenando durante los primeros segundos: leer una firma lleva alrededor de un milisegundo y hay cientos de programas distintos, así que se leen unos pocos por actualización y luego se recuerdan. Una celda vacía significa «aún no leída», no «sin firmar».
- **Signed** dice quién firmó el programa, no si está notarizado: comprobar la notarización implica calcular el hash del programa entero, lo que tardaría segundos en cada uno.
- Aquí el filtro rápido (Ctrl+S) también coincide con las columnas y no solo con el nombre, y un término puede nombrar la columna a la que se aplica: `user:root state:R` pregunta qué está ejecutando root en este momento. Los términos se separan con espacios y todos deben coincidir; el texto que no nombra ninguna columna sigue siendo una única subcadena, espacios incluidos.
