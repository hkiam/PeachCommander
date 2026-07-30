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

## Comparar dos archivos por contenido

1. Seleccione un archivo en cada panel (o dos archivos en el mismo panel).
2. Elija **Archivo ▸ Comparar por contenido…**.
3. Los dos archivos se abren uno al lado del otro con sus diferencias resaltadas. Use los controles de siguiente/anterior para saltar entre los bloques modificados.
4. Si activa el modo de edición, puede ajustar cualquiera de los dos archivos directamente y guardar sus cambios.

![La ventana de comparación mostrando dos archivos de texto uno al lado del otro con las líneas diferentes resaltadas](screenshots/diff-window.png)
*(Figura: Comparando dos archivos de texto; las líneas modificadas se resaltan en ambos lados.)*

## Comparar archivos byte a byte

Cuando dos archivos parecen iguales pero necesita demostrar que son realmente idénticos (o encontrar el único byte que difiere), use la comparación binaria. Muestra ambos archivos en una vista hexadecimal con los bytes que no coinciden marcados, lo que resulta ideal para verificar descargas, comprobar datos codificados o confirmar una copia exacta.

## Comparar los listados de directorios

Para detectar de un vistazo las diferencias entre dos carpetas abiertas, elija **Marcar ▸ Comparar directorios** (Shift+F2). Peach Commander marca los archivos que difieren o que faltan en el otro lado, de modo que pueda actuar sobre ellos con los comandos habituales de copiar, mover y eliminar.

## Atajos

| Acción | Atajo |
| --- | --- |
| Comparar los listados de directorios (marcar archivos diferentes) | Shift+F2 |
| Comparar por contenido | Archivo ▸ Comparar por contenido… |
| Sincronizar directorios | Comandos ▸ Sincronizar directorios… |

## Notas

- **Por contenido frente a por fecha/tamaño.** Una comparación rápida empareja los archivos por tamaño y fecha de modificación, lo cual es veloz pero puede llevar a error cuando las marcas de tiempo difieren en archivos idénticos. Active **por contenido** para obtener un resultado fiable a costa de leer cada archivo.
- **Subcarpetas y filtros.** La ventana de sincronización puede descender por las subcarpetas y puede limitarse con una máscara de filtro, de modo que puede sincronizar solo los tipos de archivo que le interesan.
- **Usted mantiene el control.** La sincronización nunca se ejecuta por su cuenta: usted revisa las direcciones propuestas en la cuadrícula de resultados y puede cambiar cualquiera de ellas antes de que se copie nada.
- **Preajustes.** Las configuraciones de sincronización de uso frecuente pueden guardarse y reutilizarse para no tener que volver a introducir las mismas opciones cada vez.
