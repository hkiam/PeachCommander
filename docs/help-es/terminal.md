---
title: La terminal integrada
slug: terminal
section: Complementos
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander puede ejecutar una terminal real dentro de su propia ventana, en una franja inferior llamada el dock. Es tu shell de inicio de sesión —la que indica `$SHELL`, o `/bin/zsh` si esa no sirve—, así que tu `PATH`, tus alias y tus funciones están ahí, igual que en Terminal.

No es lo mismo que **Abrir Terminal aquí**, que lanza la app Terminal de Apple en la carpeta actual y te deja con dos ventanas. La integrada se queda donde están tus archivos, y sabe de ellos.

Es un plugin: si no lo quieres, desactívalo o elimínalo en **Configuración ▸ Plugins…**, y el dock se va con él.

![La terminal integrada, anclada bajo los dos paneles de archivos](screenshots/terminal.png)
*(Figura: el shell se ejecuta en la carpeta que muestra el panel activo.)*

## Abrirla y moverse

Pulsa **Ctrl** junto con la tecla a la izquierda del «1» para mover el teclado entre el panel de archivos y la terminal. Ese atajo está ligado a la *posición* de la tecla, no a su carácter, así que es la misma tecla física la llame como la llame tu distribución: el acento grave en un teclado US, `^` en uno alemán, `@` en uno francés.

Todo lo demás está en el menú **Terminal**:

| Acción | Qué hace |
| --- | --- |
| Mostrar el terminal | Lo pliega y lo vuelve a desplegar; las pestañas y lo que se ejecuta en ellas siguen igual |
| Cambiar entre el panel y la terminal | Mueve el foco del teclado, sin cambiar nada más |
| Nueva pestaña de terminal | Otra shell, en la misma carpeta |
| Cerrar la pestaña de terminal | La cierra —y pregunta antes si algo sigue ejecutándose en ella |
| Dividir la terminal | Dos shells una al lado de otra en la misma pestaña |
| Ir a la carpeta del panel | Hace `cd` en la terminal hasta donde está el panel activo |
| Insertar los nombres de archivo seleccionados | Escribe los nombres seleccionados en el prompt, entrecomillados |
| Ejecutar la línea de comandos en la terminal | Envía lo que escribiste en la línea de comandos a la shell en lugar de ejecutarlo de forma invisible |

Mientras la terminal tiene el foco, las **teclas de función van a ella**, no al panel de archivos: F5 en un editor de texto dentro de la terminal tiene que llegar al editor. La barra de teclas de función lo indica, en vez de mostrar teclas que no van a funcionar.

## Escribir @, ~ y las llaves

En la mayoría de los teclados fuera de los Estados Unidos, `@`, `~`, `|`, `\` y las llaves se escriben con la tecla Opción. Esas pulsaciones llegan al intérprete de órdenes como los caracteres impresos en las teclas.

- La alternativa es tratar Opción como la tecla Meta, que es lo que quieren Alt+B, Alt+F y los atajos de Emacs: el terminal envía entonces Esc antes de la tecla en lugar del carácter. Actívela en **Configuración ▸ Complementos ▸ Terminal** con **Usar Opción como tecla Meta**.
- El cambio se aplica de inmediato, tanto a los terminales ya abiertos como a los nuevos.

## El puente de vuelta al panel

**Cmd-clic en una ruta** de la salida de la terminal y el panel va allí. Un archivo de `ls`, una ruta en un error del compilador, un nombre de `git status`: un clic y lo estás mirando.

Solo actúa cuando la palabra bajo el puntero corresponde de verdad a algo que existe. Un Cmd-clic sobre texto normal no hace nada, en lugar de navegar a un sitio arbitrario, y un clic simple sigue seleccionando texto como siempre.

**Suelta archivos sobre la terminal** y sus rutas aparecen en el prompt, entrecomilladas, listas para un comando que estás escribiendo a medias.

## Dejar que el panel siga a la shell

Desactivado por omisión: cuando haces `cd` en la terminal, el panel se queda donde está. Activa **Que el panel activo siga a la terminal** en la página de ajustes de la terminal y la seguirá.

Esto necesita la ayuda de tu shell, porque una shell no anuncia adónde ha ido. La página de ajustes muestra un fragmento breve para añadir a tu `~/.zshrc` y un botón para copiarlo; hace que zsh informe de su directorio de trabajo (la secuencia de escape OSC 7) antes de cada prompt. Sin el fragmento el ajuste está activado y nada sigue a nada, y por eso el fragmento está justo al lado.

## Búsqueda e historial

**Cmd+F** busca en lo que la terminal ha impreso.

Una terminal guarda **5.000 líneas** de historial por omisión, suficiente para volver atrás por una compilación. Se cambia en la página de ajustes. Los valores muy grandes se limitan, porque un historial de cincuenta millones de líneas es un problema de memoria cuya causa es imposible de ver desde fuera.

## Dónde se coloca

La terminal se abre en el dock inferior porque esa es la forma que necesita: una shell necesita ancho, y el panel lateral, con sus 300 puntos por omisión, cabe unas 44 columnas donde la parte inferior de una ventana de 1200 puntos cabe 176.

Aun así puedes moverla. Arrástrala al panel lateral si te va mejor, o usa los controles de colocación descritos en [Plugins](plugins.md); moverla **reubica la misma shell** en vez de arrancar otra, así que lo que esté ejecutándose sigue ejecutándose. Las órdenes del menú **Terminal** lo siguen: lo muestran donde está, en lugar de abrir el dock.

Las pestañas vuelven al iniciar la app de nuevo, en las carpetas en las que estaban. Lo que *se ejecutaba* en ellas, no: un reinicio termina esos procesos, como en cualquier terminal. También vuelve si estaba abierto al salir.

## Al salir

Cerrar la app cierra las shells. Lo que siga ejecutándose en ellas se termina, igual que cerrar una ventana de Terminal termina lo que hay dentro. Por eso cerrar una pestaña con algo en marcha pregunta antes.
