---
title: Carpetas y archivos nuevos
slug: creating-items
section: Archivos y carpetas
order: 30
related: [opening-files]
---

Cuando organiza archivos, a menudo necesita un lugar nuevo donde ponerlos o un documento en blanco desde el que empezar. Peach Commander le permite crear una carpeta nueva o un archivo de texto nuevo directamente en el panel en el que está trabajando, sin cambiar a Finder. Los elementos nuevos se crean en la carpeta que se muestra actualmente en el panel activo.

## Crear una carpeta nueva

1. Haga clic en el panel donde quiera que aparezca la nueva carpeta para que se convierta en el panel activo.
2. Pulse F7.
3. Escriba un nombre en el cuadro que aparece.
4. Pulse Return (o haga clic en Aceptar). La nueva carpeta aparece en el panel, lista para usarse.

Puede hacer algo más que crear una única carpeta en un solo paso:

- **Carpetas anidadas de una vez.** Escriba una ruta con barras, como `a/b/c`, para crear una carpeta `a` que contiene `b`, que contiene `c`. Cualquier nivel que aún no exista se crea automáticamente.
- **Varias carpetas a la vez.** Separe los nombres con una barra vertical, como `d1|d2`, para crear `d1` y `d2` una junto a otra. Puede combinar ambos estilos, por ejemplo `reports/2026|archive`.

## Crear un archivo de texto nuevo

1. Haga clic en el panel donde quiera que aparezca el nuevo archivo.
2. Pulse Shift+F4.
3. Escriba un nombre para el archivo, incluida su extensión (por ejemplo, `notes.txt`).
4. Pulse Return. El archivo vacío se crea y se abre en el editor para que pueda empezar a escribir de inmediato.

El archivo se abre en el editor que Peach Commander tenga configurado para ese tipo de archivo. Consulte **Abrir y ver archivos** para saber cómo funciona la edición.

## Atajos

| Acción | Tecla |
| --- | --- |
| Carpeta nueva | F7 |
| Archivo de texto nuevo | Shift+F4 |

## Notas

- En macOS, el nombre de una carpeta o un archivo puede contener casi cualquier carácter. Solo la barra `/` (que se usa como separador de ruta para las carpetas anidadas) y algunos caracteres reservados no se permiten en un nombre único.
- Usar dos puntos `:` en un nombre es posible, pero puede resultar confuso en Finder, así que es mejor evitarlo.
- Si ya existe una carpeta con el mismo nombre, Peach Commander simplemente conserva la existente: no se sobrescribe nada.
