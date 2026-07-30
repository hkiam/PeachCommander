---
title: Atributos y permisos
slug: attributes-and-permissions
section: Herramientas avanzadas
order: 96
related: [file-utilities]
---

Peach Commander le permite inspeccionar y modificar los metadatos de bajo nivel de archivos y carpetas que Finder mantiene, en su mayoría, fuera de su alcance: permisos POSIX de lectura/escritura/ejecución, el propietario y el grupo, las fechas de modificación y de creación, indicadores de macOS como oculto y bloqueado, y atributos extendidos. También puede editar la lista de control de acceso (ACL) de un archivo para establecer reglas detalladas por usuario o por grupo, crear enlaces y alias que apunten a otros elementos, y adjuntar sus propios comentarios. Estas herramientas están dirigidas a usuarios avanzados que necesitan un control preciso sobre cómo se comportan los elementos y quién puede tocarlos.

## Cambiar atributos

1. Seleccione uno o varios elementos en el panel activo.
2. Elija **Archivo > Cambiar atributos…**.
3. Ajuste lo que necesite: active o desactive las casillas de lectura/escritura/ejecución para el propietario, el grupo y todos (o escriba un valor octal directamente), cambie el propietario o el grupo, invierta los indicadores de oculto o bloqueado, y establezca la fecha de modificación o de creación. Use **Usar actual** para la hora actual, o copie una fecha de otro archivo.
4. Para aplicar el mismo cambio a través del contenido de una carpeta, active la opción recursiva y elija si afecta a los archivos, a las carpetas o a ambos.
5. Haga clic en Aceptar para ejecutar el cambio. Los cambios recursivos se ejecutan como una tarea en segundo plano con una barra de progreso.

![Cuadro de diálogo Cambiar atributos mostrando la cuadrícula de permisos, los indicadores y los campos de fecha](screenshots/attributes-dialog.png)
*(Figura: El cuadro de diálogo Cambiar atributos. Los valores mixtos en una selección de varios archivos se muestran como un guion hasta que los define.)*

## Editar una ACL

Para reglas que van más allá del modelo básico de propietario/grupo/todos, edite la lista de control de acceso del elemento.

1. Abra **Archivo > Cambiar atributos…** y abra desde ahí el editor de ACL.
2. Cada fila es una regla: el usuario o grupo al que se aplica, si permite o deniega, y qué permisos (lectura, escritura, eliminación, etc.) concede.
3. Añada, elimine o edite filas y, a continuación, guarde para escribir la lista de nuevo en el elemento.

## Crear enlaces, alias y comentarios

- **Archivo > Crear enlace simbólico…** crea un enlace simbólico (symlink) que apunta por ruta al elemento situado bajo el cursor.
- **Archivo > Crear enlace fijo…** crea un enlace fijo a los mismos datos del archivo. Los enlaces fijos solo funcionan con archivos del mismo volumen.
- **Archivo > Crear alias…** crea un alias de macOS que Finder también puede seguir.
- **Archivo > Editar comentario…** (Ctrl+Z) abre un editor de texto para un comentario por archivo. Los comentarios pueden mostrarse en su propia columna y en las sugerencias de estado.

## Atajos

| Acción | Atajo |
| --- | --- |
| Editar comentario | Ctrl+Z |

## Notas

- Cambiar el propietario o el grupo suele requerir privilegios de los que no dispone como usuario normal; cuando eso ocurre, el cambio se notifica como fallido en lugar de aplicarse, y el resto de sus cambios sí se llevan a cabo.
- Los comentarios se almacenan en un archivo `descript.ion` junto a sus elementos y también pueden conservarse como comentarios de Finder, según sus ajustes. Ambos se leen al mostrar un comentario.
- Tanto un enlace simbólico como un alias apuntan a un destino, pero un enlace simbólico almacena una ruta simple mientras que un alias almacena una referencia de macOS que sigue funcionando si el destino se mueve o se renombra. Un enlace fijo es un segundo nombre para los mismos datos del archivo, no un puntero.
