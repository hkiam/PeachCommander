---
title: Ver archivos
slug: viewing-files
section: Ver y editar
order: 70
related: [editing-files, searching]
---

Peach Commander tiene un visor integrado que te permite mirar dentro de un archivo sin abrir otra app ni modificar el archivo. Pulsa F3 sobre el elemento bajo el cursor y el visor se abre al instante, incluso para archivos muy grandes. Elige automáticamente la mejor forma de mostrar el contenido: texto legible, código con colores de sintaxis, un volcado hexadecimal en bruto, o una imagen a tamaño completo. También puedes previsualizar un archivo dentro de la ventana con Quick View, o pasarlo a Quick Look de macOS.

## Ver un archivo

1. Mueve el cursor sobre un archivo del panel activo.
2. Pulsa F3 (o elige Ver en el menú Archivo). El visor se abre en su propia ventana.
3. Usa la barra de herramientas para cambiar cómo se muestra el contenido: Texto, Código, Hex, Imagen o Renderizado. Déjalo en el ajuste automático para que Peach Commander decida.
4. Desplázate con las teclas de flecha, Page Up/Page Down y la barra de desplazamiento. Para texto largo, activa el botón de minimapa para ver y saltar por todo el archivo de un vistazo.
5. Pulsa N para saltar al siguiente archivo seleccionado, o cierra la ventana con Esc.

![El visor integrado mostrando un archivo de texto con el minimapa a la derecha](screenshots/lister-text.png)
*(Figura: Ver un archivo de texto, con el selector de representación y el minimapa en la barra de herramientas.)*

## Buscar texto y cambiar la codificación

- Pulsa Ctrl+F para buscar dentro del archivo. Pulsa F3 para saltar a la siguiente coincidencia y Shift+F3 para la anterior.
- Si el texto se ve corrupto, haz clic en Codificación en la barra de herramientas (o pulsa E) para recorrer las codificaciones de texto hasta que se lea correctamente; el ajuste automático suele acertar.
- Pulsa W para alternar el ajuste de línea para las líneas largas.

## Quick View y Quick Look

Quick View muestra una vista previa en directo en el panel que *no* estás usando, así puedes seguir explorando en un lado mientras previsualizas en el otro.

1. Pulsa Ctrl+Q. El panel inactivo se convierte en un área de vista previa.
2. Mueve el cursor sobre distintos archivos del panel activo para previsualizar cada uno.
3. Pulsa Ctrl+Q de nuevo, o Esc, para devolver el panel a una lista de archivos normal.

Para una vista previa rápida a pantalla completa gestionada por macOS mismo, pulsa Cmd+Y (Quick Look). Pulsa Cmd+Y o Space de nuevo para cerrarla.

## La página de información del panel lateral

El panel lateral (**Visualización > Panel de previsualización**, o Cmd+Mayús+P) tiene una página **Información** que muestra el elemento bajo el cursor igual que la barra lateral de información del Finder.

- La previsualización ocupa todo el ancho del panel: al ensanchar el panel, la previsualización crece con él. Arrastre el borde izquierdo del panel para ensancharlo o estrecharlo; la anchura se recuerda.
- Es una previsualización real de macOS, no una miniatura pequeña: funciona cualquier formato que Vista Rápida pueda mostrar, y un documento de varias páginas se recorre página a página dentro de la previsualización.
- Debajo están el nombre, el tipo y el tamaño, y después cuándo se creó y se modificó el elemento y en qué carpeta está.

Al mover el cursor, el nombre y los datos se actualizan de inmediato; la previsualización llega un momento después, de modo que mantener pulsada una flecha a lo largo de una carpeta larga no inicia una previsualización por cada fila.

## Descompilar archivos .class de Java

Con el módulo **Java Decompiler** activado, F3 sobre un archivo `.class` muestra código legible en lugar de datos binarios — también para clases dentro de un JAR o un ZIP, en el que puede entrar y leer sin descomprimirlo.

El módulo no contiene ningún descompilador propio. Maneja un motor que usted instala, y puede cambiarlo en cualquier momento:

- **CFR** (licencia MIT) y **Vineflower** (Apache 2.0) producen código fuente Java. Coloque `cfr.jar` o `vineflower.jar` en la carpeta de motores.
- **Procyon** (Apache 2.0) es un tercer descompilador a código fuente.
- **javap** no requiere ninguna descarga: viene con cualquier JDK y muestra bytecode en lugar de código fuente Java.

No se descarga nada por usted: son programas de terceros con sus propias licencias, y Peach Commander ni los obtiene ni los actualiza. El botón **Carpeta de motores…** del visor abre la carpeta a la que pertenecen y deja allí una nota con el nombre de cada motor y dónde conseguirlo. Todos salvo javap necesitan Java instalado.

Cambie de motor con el menú en la parte superior del visor; el elegido se usa de inmediato y el resultado se conserva, así que comparar dos motores sobre el mismo archivo es instantáneo.

El módulo está **desactivado hasta que usted lo active**, en Ajustes ▸ Módulos: casi nadie abre un archivo .class, y sin un motor no sirve de nada.

Para añadir un motor propio, cree `decompilers.ini` en la carpeta de motores:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args   = -jar {engine} {input}
engine = ~/tools/my-decompiler.jar
output = stdout
```

`{input}`, `{engine}` y `{outdir}` se sustituyen al ejecutar. Sus entradas tienen prioridad sobre las incorporadas, y reutilizar un nombre incorporado (`cfr`, `vineflower`, `procyon`, `javap`) lo sustituye en vez de añadir una segunda entrada.

## Atajos

| Acción | Atajo |
| --- | --- |
| Ver el archivo bajo el cursor | F3 |
| Ver solo el archivo bajo el cursor (ignorar archivos marcados) | Shift+F3 |
| Abrir en un visor externo | Option+F3 |
| Buscar dentro del visor | Ctrl+F |
| Coincidencia siguiente / anterior | F3 / Shift+F3 |
| Quick View en el otro panel | Ctrl+Q |
| Quick Look (vista previa de macOS) | Cmd+Y |
| Cerrar el visor o Quick View | Esc |

## Notas

- El visor es de solo lectura. Para modificar un archivo, usa el editor en su lugar (consulta Editar archivos).
- Los archivos muy grandes se abren sin demora: el texto abre una vista rápida y desplazable, y la vista hexadecimal se transmite directamente desde el disco a cualquier tamaño.
- Pulsa F3 sobre una carpeta para ver un resumen de su contenido y su tamaño total en lugar de bytes de archivo.
- El modo Renderizado muestra contenido con formato como páginas web; el modo hexadecimal muestra los bytes en bruto junto a sus caracteres, lo que es útil para inspeccionar archivos binarios.
- En el modo Renderizado puede seleccionar y copiar texto, y Buscar recorre la página renderizada. Los botones que no se aplican a una página renderizada —Formatear, Codificación, Seleccionar todo, Selecciones e Ir a— aparecen atenuados en lugar de no hacer nada.
- El botón Formatear vuelve a sangrar los archivos estructurados (JSON, XML, HTML, INI, YAML y más si tiene instalada la herramienta de línea de órdenes correspondiente). Se describe por completo en [Editar archivos](editing-files.md#formatting-a-file) y funciona igual aquí.
