---
title: Descompilar Java y .NET
slug: decompilers
section: Plugins
order: 131
related: [plugins, viewing-files, searching]
---

Pulsa **F3** sobre un archivo compilado y verás código fuente en lugar de bytes. Lo hacen dos plugins —uno para Java (`.class`, `.jar`, `.apk`, `.dex`) y otro para .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`)— y se comportan igual, así que esta página cubre ambos. Cada uno se puede desactivar o eliminar por separado en **Configuración ▸ Plugins…**.

Un archivo comprimido aparece como un árbol de sus clases; una clase suelta, como un archivo. **Descompilar a fuentes** en el menú Comandos escribe el resultado y lo pone en un panel, para buscar, comparar y copiar en él como en cualquier otra carpeta de fuentes.

## El motor lo instalas tú

No se incluye ningún descompilador y no se descarga nada por ti. Es deliberado por dos motivos: JD-Core, el descompilador de Java más conocido, es GPLv3 y no podría venir dentro de una app Apache-2.0 —y los motores mejoran, así que cambiarlos no debería exigir una versión nueva de Peach Commander.

**Carpeta de motores…** en el visor abre la carpeta a la que pertenecen. El README que hay allí nombra cada motor y su licencia.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (para `.dex` y `.apk` de Android) y `javap` para bytecode puro |
| .NET | ILSpy, y `monodis` para IL |

**Comprobar motores** ejecuta el comando de versión de cada motor y distingue tres cosas: instalado y funcionando, no instalado, e *instalado pero incapaz de ejecutarse* —una herramienta Java sin JDK está presente y aun así no arranca, y solo ejecutarla de verdad lo revela.

Un motor se describe con datos y no con código, así que puedes añadir uno tú mismo:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Cuando más de un motor puede con un archivo, se usa el primero disponible salvo que elijas uno. Con dos instalados, **Comparar** muestra ambos resultados en paralelo: útil cuando un motor se rinde con un método que el otro sí resuelve.

## Buscar dentro de código compilado

**Buscar en todas las clases** recorre el texto descompilado en lugar de los bytes, de modo que puedes encontrar una cadena literal o un nombre de método dentro de un JAR.

Descompilar durante una *búsqueda de contenido* en muchos archivos es un ajuste aparte, desactivado por omisión: producir el texto puede significar ejecutar el motor una vez por clase, lo que en una máquina lenta no es algo razonable que gastar en una búsqueda. El diálogo de búsqueda principal lo pregunta por separado; aquí también se rechaza.

## Caché y límites

Los resultados se guardan en caché, porque descompilar dos veces la misma clase es pura espera. En los ajustes está cuántos días se conservan los resultados y un **límite de tamaño** para la caché; **Vaciar la caché ahora** la vacía e informa de cuánto ha liberado.

Dos tiempos límite protegen frente a un motor que no termina: uno para una sola clase o tipo, otro para un archivo comprimido entero. Ambos aceptan 0, que significa «usar el valor por omisión del motor».
