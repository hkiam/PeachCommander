---
title: Utilidades de archivos
slug: file-utilities
section: Herramientas avanzadas
order: 94
related: [comparing-and-syncing]
---

Más allá de copiar y mover, Peach Commander incluye un conjunto de utilidades de archivos cotidianas para verificar que los archivos están intactos, recuperar espacio en disco, dividir archivos grandes en fragmentos más pequeños y convertir archivos a formatos seguros para texto y viceversa. Puede acceder a todas ellas desde el menú **Archivo**, y actúan sobre lo que tenga seleccionado en el panel activo (o sobre el elemento situado bajo el cursor cuando no hay nada seleccionado). Este tema abarca las sumas de comprobación, el buscador de duplicados, dividir/combinar, codificar/descodificar y el cálculo del espacio ocupado.

## Crear o verificar sumas de comprobación

Las sumas de comprobación permiten confirmar que un archivo se descargó o se copió sin corrupción, o dar a un destinatario una forma de comprobar la copia que ha recibido.

1. Seleccione los archivos de los que quiera obtener una huella.
2. Elija **Archivo ▸ Crear sumas de comprobación…**, elija un algoritmo (CRC32, MD5, SHA-1, SHA-256 o SHA-512) y guarde el archivo de sumas de comprobación.
3. Para comprobar los archivos más tarde, seleccione el archivo de sumas de comprobación y elija **Archivo ▸ Verificar sumas de comprobación…**. Peach Commander recalcula cada hash e informa de cualquier archivo que no coincida.

Las sumas de comprobación se transmiten directamente sobre la ubicación actual, de modo que puede crearlas o verificarlas incluso para archivos dentro de archivos comprimidos o en un servidor FTP.

## Buscar archivos duplicados

El buscador de duplicados localiza archivos idénticos repartidos por varias carpetas para que pueda eliminar las copias sobrantes.

1. Seleccione las carpetas (o los archivos) que desea analizar.
2. Elija **Archivo ▸ Buscar duplicados…**. Peach Commander compara los candidatos y agrupa los archivos que son idénticos byte a byte.
3. Revise cada grupo, marque las copias que ya no necesite y elimínelas.

![El buscador de duplicados con una lista de grupos de archivos idénticos](screenshots/duplicate-finder.png)
*(Figura: El buscador de duplicados agrupa los archivos idénticos para que pueda conservar uno y eliminar el resto.)*

## Dividir y combinar archivos

Dividir descompone un archivo grande en una serie numerada de partes más pequeñas, práctico para límites de almacenamiento o de transferencia. Combinar las vuelve a ensamblar.

1. Para dividir, seleccione un archivo y elija **Archivo ▸ Dividir archivo…** y, a continuación, defina el tamaño de las partes. Las partes se escriben en la carpeta del otro panel.
2. Para reensamblar, seleccione la primera parte y elija **Archivo ▸ Combinar archivos…**. El archivo original se reconstruye a partir de los fragmentos numerados.

## Codificar y descodificar

Codificar convierte un archivo binario en texto sin formato para que sobreviva a los canales que solo transportan texto (por ejemplo, correos electrónicos antiguos o cuadros de pegado). Descodificar lo revierte.

1. Seleccione un archivo y elija **Archivo ▸ Codificar…** y, a continuación, elija un formato: MIME (Base64), UUE (uuencode) o XXE.
2. Para restaurar el original, seleccione el archivo codificado y elija **Archivo ▸ Descodificar…**. El formato se detecta automáticamente.

## Calcular el espacio ocupado

Para ver cuánto espacio ocupa realmente una carpeta o una selección en el disco, seleccione los elementos y pulse **Ctrl+L** (**Archivo ▸ Calcular espacio ocupado…**). Peach Commander suma todos los archivos que contiene, incluidas las subcarpetas, y muestra el total.

## Atajos

| Acción | Tecla |
| --- | --- |
| Calcular el espacio ocupado | Ctrl+L |

## Notas

- Las sumas de comprobación, dividir/combinar y codificar/descodificar están orientadas a tareas más avanzadas, pero cada una es un único cuadro de diálogo con valores predeterminados sensatos.
- Cuando una utilidad produce archivos nuevos (partes de una división, un archivo codificado, una lista de sumas de comprobación), se escriben en la carpeta que se muestra en el otro panel: configure primero ese panel con el destino previsto.
- Eliminar duplicados es permanente según sus ajustes de eliminación; revise cada grupo con cuidado y conserve al menos una copia de todo lo que aún necesite.
