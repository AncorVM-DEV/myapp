# PRO TASK

> Aplicación de gestión de proyectos y tareas desarrollada con **Flutter** y **Supabase**, disponible en Web, Windows, Android e iOS.

### 👨‍💻 Autores del Proyecto
* **Ancor Valentín Martín** - [AncorVM-DEV](https://github.com/AncorVM-DEV)
* **David Rodríguez Castellano** - [D4v1drc](https://github.com/D4v1drc)
* **Borja García Betancor** - [UsuarioDeBorja](https://github.com/UsuarioDeBorja)

---

## 📋 Índice

- [🛠️ Guía de Instalación y Configuración](#️-guía-de-instalación-y-configuración)
  - [1. Requisitos Previos](#1-requisitos-previos)
  - [2. Preparación del Entorno](#2-preparación-del-entorno)
  - [3. Instalación del Proyecto](#3-instalación-del-proyecto)
  - [4. Configuración de Seguridad (.env)](#4-configuración-de-seguridad-env)
  - [5. Ejecución](#5-ejecución)
- [📝 Notas de la Versión](#-notas-de-la-versión)

---

## 🛠️ Guía de Instalación y Configuración

Este es un **proyecto intermodular** desarrollado con Flutter y Supabase. Por motivos de seguridad y siguiendo las mejores prácticas de desarrollo, las credenciales de acceso a la base de datos **no están incluidas** en el código fuente ni en el repositorio.

### 1. Requisitos Previos

Antes de comenzar, asegúrate de tener instalado:

| Herramienta | Descripción |
| :--- | :--- |
| **Flutter SDK** | [Guía oficial de instalación](https://docs.flutter.dev/get-started/install) |
| **Visual Studio Code** | Con las extensiones oficiales de **Flutter** y **Dart** instaladas (disponibles en el Marketplace como `Flutter`) |
| **Git** | Para clonar el repositorio |

### 2. Preparación del Entorno

Ejecuta el siguiente comando en tu terminal para verificar que tu entorno de desarrollo está listo:

```bash
flutter doctor
```

Si falta algún componente o SDK, sigue las instrucciones que te indique la terminal para completar la instalación.

### 3. Instalación del Proyecto

**Paso 1 — Clonar el repositorio:**

```bash
git clone https://github.com/AncorVM-DEV/myapp.git
cd myapp
```

**Paso 2 — Instalar dependencias:**

Una vez dentro de la carpeta del proyecto, descarga todas las librerías necesarias:

```bash
flutter pub get
```

### 4. Configuración de Seguridad (.env)

Este proyecto utiliza `flutter_dotenv` para gestionar variables de entorno de forma segura. Para que la aplicación pueda conectarse a la base de datos, sigue estos pasos:

1. Localiza el archivo llamado **`.env.example`** en la raíz del proyecto.
2. Renómbralo a **`.env`** (elimina la extensión `.example`).
3. Abre el nuevo archivo `.env` y sustituye los valores de prueba por las credenciales reales:

```env
# Configuración de Supabase (Requerido)
# Sustituye estos valores por los proporcionados en la entrega del proyecto
SUPABASE_URL=tu_url_de_supabase_aqui
SUPABASE_ANON_KEY=tu_anon_key_aqui
```

> 📌 **Nota:** Las claves reales de acceso a la base de datos se adjuntan en la documentación oficial de la entrega del proyecto.

> ⚠️ **Aviso de Seguridad:** El archivo `.env` está registrado en el `.gitignore` y **nunca debe subirse** al control de versiones. Esto protege la integridad de los datos y previene accesos no autorizados a la infraestructura de Supabase.

### 5. Ejecución

Una vez que el archivo `.env` esté configurado correctamente con las claves proporcionadas, compila y lanza la aplicación:

```bash
flutter run
```

---

## 📝 Notas de la Versión

### Leyenda

**bd = Base de Datos**

---

<details>
<summary><strong>v13.04.2026 (Parte 2)</strong> 🛡️ Seguridad Avanzada y Refinamiento Visual (Click para ver detalles)</summary>
<br>

| 🛡️ Seguridad y Sanitización |
| :--- |
| <ul><li><b>Escudo anti-XSS e Inyecciones:</b> Se ha desarrollado e integrado un sistema de seguridad centralizado (<code>lib/utils/sanitizer.dart</code>) para proteger la base de datos contra scripts maliciosos y código basura.</li><li><b>Limpieza total de Inputs:</b> Absolutamente todos los textos introducidos por el usuario (títulos de proyectos, descripciones de tareas, subtareas, comentarios, nombres de perfil y búsquedas de usuarios) pasan ahora por un filtro estricto antes de realizar cualquier <code>INSERT</code> o <code>UPDATE</code> en Supabase, eliminando etiquetas HTML y colapsando espacios innecesarios.</li></ul> |

| 🎨 Refactorización Visual y UI |
| :--- |
| <ul><li><b>Iconos Nativos (Material Design):</b> Se ha realizado una limpieza profunda de la interfaz, sustituyendo los emojis de texto estáticos (🔴, 🟡, ✅, ▶️, etc.) por widgets <code>Icon</code> nativos de Flutter.</li><li><b>Consistencia Multiplataforma:</b> Al abandonar los emojis del sistema operativo en favor de iconos nativos coloreados con la paleta oficial (<code>AppColores</code>), la aplicación garantiza ahora un aspecto 100% idéntico, coherente y profesional en Web, Windows, Android e iOS.</li></ul> |

</details>

<details>
<summary><strong>v13.04.2026</strong> 🚀 Seguridad, Branding y Corrección Maestra de UI/UX (Click para ver detalles)</summary>
<br>

| ✨ Novedades, Seguridad y Branding |
| :--- |
| <ul><li><b>Identidad Visual (ProTask):</b> La aplicación ha dejado de ser genérica. Se ha renombrado oficialmente como <b>ProTask</b> en todas las plataformas (Android, iOS, Windows y Web) y se ha implementado el logo oficial usando <code>media/proyecto.png</code> como icono nativo.</li><li><b>Seguridad de Credenciales (.env):</b> Se ha implementado un sistema de variables de entorno con <code>flutter_dotenv</code>. La URL y la API Key de Supabase ya no están expuestas en el código fuente; ahora residen en un archivo <code>.env</code> protegido por <code>.gitignore</code> para un despliegue seguro en GitHub.</li><li><b>Sincronización en Tiempo Real (Proyectos):</b> Integración total de Supabase Realtime para la tabla de proyectos. Los cambios (creación, edición, estado) se reflejan instantáneamente en la interfaz de todos los miembros sin necesidad de recargar.</li><li><b>Gestión de Tareas Ágil:</b> Se ha añadido la capacidad de cambiar el estado de las tareas directamente desde la vista de Tabla (vía PopupMenu) y desde el diálogo de información, sincronizando los cambios inmediatamente con la BD.</li></ul> |

| 🐛 Correcciones Críticas de UI/UX |
| :--- |
| <ul><li><b>Solución Definitiva al Teclado (Android):</b> Se ha corregido el error de pérdida de foco y cierre del teclado en el diálogo de invitados. Se reestructuró la jerarquía usando un <code>StatefulWidget</code> dedicado, <code>SingleChildScrollView</code> y <code>shrinkWrap</code> para que el cuadro se adapte perfectamente al espacio del teclado sin errores de <i>overflow</i>.</li><li><b>Tabla Responsive & Captura Completa:</b> Se ha implementado scroll horizontal nativo en la tabla de tareas. Además, se reubicó el <code>RepaintBoundary</code> para permitir descargas de imágenes completas de la tabla, incluso si el contenido desborda la pantalla vertical en móviles.</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Mantenimiento:</b> Recordar generar siempre el archivo <code>.env</code> localmente al clonar el repositorio en máquinas nuevas, ya que está excluido por seguridad.</li></ul> |

</details>

<details>
<summary><strong>v29.03.2026</strong> 👥📧 Notificaciones por Email & Proyectos Compartidos (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Notificaciones por Email:</b> Hemos terminado toda la lógica para que los avisos te lleguen directamente a tu correo electrónico de forma fiable (Quedan hacer test de esto para diferentes situaciones).</li><li><b>Mejoras en la Tabla de Tareas:</b> Se ha pulido el formato visual de la tabla y se ha mejorado su interactividad. Ahora, al hacer click en una tarea desde esta vista, se abrirá el popup completo con toda su información (exactamente igual que en la vista principal), en lugar de solo dejarte cambiar el estado rápidamente.</li><li><b>Roles y Proyectos Compartidos:</b> Hemos desarrollado el sistema de "Compartido conmigo", lo que permite invitar a varios usuarios a un mismo proyecto y asignarles diferentes roles o permisos según lo que necesiten hacer.<ul><li><b>Sistema de Invitaciones:</b> Ahora, al invitar a alguien usando su nombre exacto de usuario, la invitación le aparecerá en estado "Pendiente" dentro de su sección de "Compartido conmigo". Desde ahí, el usuario tendrá la total libertad de aceptar o rechazar unirse al proyecto.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Fase de Pruebas (Full Test):</b> El objetivo principal ahora es realizar un testeo exhaustivo de toda la aplicación de principio a fin para detectar, documentar y arreglar cualquier posible error (bug) antes de dar la versión por finalizada.</li></ul> |

</details>

<details>
<summary><strong>v24.03.2026</strong> 📧📂Correos, Archivos Adjuntos & Mejoras de Carga (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Gestión de Correos y Perfil:</b><ul><li><b>Login y Register:</b> Se ha modificado el Login para detectar si usas un correo de invitado/ficticio o uno real, y se añadió la opción de "Olvidé mi contraseña". En el Register, poner un correo real ahora es opcional.</li><li><b>Nuevo apartado de Perfil:</b> Dentro de la app, ahora puedes actualizar y vincular tu correo real.</li><li><b>El motivo (Notificaciones):</b> Decidimos dar este paso para simplificar las notificaciones. Las notificaciones <i>push</i> dan demasiados dolores de cabeza por las restricciones de cada dispositivo. El correo es una solución más sencilla, cómoda y verdaderamente multiplataforma. <i>(Nota: La lógica de envío de correos se implementará en la próxima actualización)</i>.</li></ul></li><li><b>Corrección visual en Subtareas:</b> Las subtareas ya no se quedan "congeladas" en la caché de la interfaz. Antes, al borrarlas, se eliminaban correctamente de la base de datos, pero el usuario las seguía viendo hasta recargar. Ahora desaparecen visualmente al instante.</li><li><b>Archivos Adjuntos:</b> Se pueden adjuntar, eliminar y seleccionar archivos dentro de las tareas. Si subes una imagen, verás una miniatura y podrás abrirla haciendo click dentro de la misma aplicación (lo mismo con los documentos).</li><li><b>Mejoras en las Pantallas de Carga:</b><ul><li><b>Carga Web (index.html):</b> Adiós a la aburrida pantalla en blanco con la barra de carga por defecto de Flutter. Ahora, al entrar, verás el logo de la app, una animación propia y mensajes dinámicos si la carga tarda más de lo normal.</li><li><b>Splash Screen (Conexión BD):</b> Se añadió una segunda pantalla de carga (Splash) para el momento en que la app se conecta a Supabase. Si tarda, informará al usuario ("Conectando con Supabase...", etc.) para que no piense que la app se ha quedado colgada.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Notificaciones por Email:</b> Terminar de implementar la lógica para que las notificaciones lleguen al correo electrónico en lugar de usar notificaciones push.</li><li><b>Mejoras en la Tabla de Tareas:</b> Cambiar el formato visual de la tabla y hacer que, al interactuar con una tarea desde ahí, se abra el popup completo con toda la información (como en la vista normal), en lugar de solo permitir cambiar el estado rápidamente.</li><li><b>Roles y Proyectos Compartidos:</b> Desarrollar el sistema para que varios usuarios puedan colaborar en un mismo proyecto y se les puedan asignar diferentes roles o permisos.</li></ul> |

</details>

<details>
<summary><strong>v13.03.2026</strong> 📱🔐 Correcciones Móviles & Persistencia de Sesión (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>App Móvil (Android):</b> Arreglados todos los problemas de Gradle, se ha hecho la interfaz responsive y se corrigieron gran parte de los bugs que había en la versión de Android.</li><li><b>Detección de Plataforma:</b> Se implementó una dependencia (gestionada desde la carpeta <code>utils</code>) para detectar exactamente en qué dispositivo estás (Android, PC, iOS, etc.). Esto soluciona de raíz los errores que daba la tabla en distintos dispositivos.</li><li><b>Correcciones Web:</b> Se arreglaron un par de bugs menores en la versión de navegador.</li><li><b>Persistencia de Sesión:</b> Ahora, si recargas la página o cierras la app en el móvil, tu sesión se mantiene de forma persistente. Solo se cerrará si le das tú mismo al botón de "Cerrar sesión".</li><li><b>Notificaciones Push:</b> Avances en el sistema de notificaciones para móvil (aunque hay cosas por pulir, ver detalles en Pendientes).</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Testeo de Notificaciones Programadas:</b> Hay que seguir investigando el sistema push en móviles. Las notificaciones <i>instantáneas</i> funcionan perfecto para pruebas, pero las notificaciones <i>programadas</i> (por ejemplo, a 2 minutos vista) están fallando. Se seguirá testeando para descubrir por qué no llegan (ya sea en primer plano, segundo plano o con la app cerrada).</li><li><b>Archivos Adjuntos:</b> Falta conectar esta sección al almacenamiento (Storage) de Supabase para poder subir archivos. De momento tiene una etiqueta visual de "Próximamente".</li><li><b>Mejoras en la Tabla de Tareas:</b> Más adelante nos gustaría cambiar el formato visual de la tabla y hacer que, al interactuar con una tarea desde ahí, se abra el popup completo con toda la información (igual que en la vista normal), en lugar de solo permitir cambiar el estado.</li></ul> |

</details>

<details>
<summary><strong>v11.03.2026</strong> 🚀🔍 Actualización UX/UI & Búsqueda Avanzada (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>UI / Accesibilidad:</b> Arregladas las "hitboxes" (áreas de click) de los iconos y botones. Ahora son mucho más fáciles de tocar en móvil y en Web el cursor cambia a la "manita" correctamente.</li><li><b>Sistema de Prioridades:</b> Ahora las tareas tienen niveles de urgencia (🔴 Urgente, 🟡 Alta, 🔵 Normal, ⚪ Baja, Sin prioridad). Se ordenan solas y muestran una franja lateral de color muy visual.</li><li><b>Filtros y Búsqueda:</b> Hemos creado barras de búsqueda en tiempo real súper fluidas para proyectos y tareas, junto con un sistema para filtrar por prioridad, estado y orden.</li><li><b>Interactividad en la Tabla:</b> La tabla de tareas ya es es interactiva. Si haces click en una tarea, sale un popup para cambiar su estado.</li><li><b>Subtareas y Comentarios:</b> Le hemos dado vida a las maquetas visuales. Ya puedes añadir, completar y borrar subtareas, además de escribir comentarios reales.</li><li><b>Edición rápida (Mejora UX):</b> Nos hemos deshecho de los pop-ups secundarios. Ahora puedes editar el nombre, la descripción, la fecha límite, la prioridad y el estado directamente desde la tarjeta principal con un solo toque.</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Archivos Adjuntos:</b> Falta conectar esta sección al almacenamiento (Storage) de Supabase para poder subir archivos. De momento sigue con la etiqueta visual de "Próximamente".</li><li><b>App Móvil (Android/iOS):</b> Queda arreglar, pulir y perfeccionar las versiones nativas de la aplicación para que funcionen impecables como APK (Android) y en dispositivos iOS.</li><li><b>Mejoras en la Tabla de Tareas:</b> Más adelante nos gustaría cambiar el formato visual de la tabla y hacer que, al interactuar con una tarea desde ahí, se abra el popup completo con toda la información (igual que en la vista normal), en lugar de solo permitir cambiar el estado.</li></ul> |

</details>

<details>
<summary><strong>v04.03.2026</strong> ♻️🗄️ Refactorización de Código & Migración a Supabase (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Refactorización:</b> Se ha refactorizado y limpiado gran parte del código interno de la aplicación para mejorar su rendimiento y mantenibilidad.</li><li><b>Migración de Base de Datos (Firebase ➡️ Supabase):</b> Se ha migrado toda la infraestructura de la base de datos a Supabase para aprovechar las ventajas de una base de datos relacional.<ul><li><b>Fix de Seguridad Crítico:</b> Existía una brecha enorme en el modelo anterior: si un usuario le ponía a su proyecto el mismo nombre que el proyecto de otro usuario, se vinculaban las tareas ya creadas por ese otro usuario. Gracias a la migración y al nuevo modelo relacional, este problema de cruce de datos ha quedado solucionado.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>UI / Accesibilidad:</b> Arreglar la "hitbox" (área de click) de los iconos, ya que ahora mismo hay que ser demasiado preciso con el ratón/dedo para interactuar con ellos.</li><li><b>Sistema de Prioridades:</b> Falta implementar niveles de urgencia en las tareas (Urgente 🔴, Alta 🟡, Normal 🔵, Baja ⚪, Sin prioridad).<ul><li>Esto ordenará las tareas automáticamente hacia arriba y mostrará una franja lateral de color a la izquierda de la tarea.</li></ul></li><li><b>Filtros Avanzados:</b> Evaluar la implementación de un sistema de filtros (por prioridad, estado, orden, etc.) para que el usuario pueda encontrar tareas específicas fácilmente.</li><li><b>Interactividad en la Tabla:</b> Poder hacer click en las tareas desde la pantalla de gráficos para que salga un popup donde se pueda editar el estado (sincronizándose con la BD y la pantalla principal).</li><li><b>Exportación de Datos:</b> Implementar un botón para descargar la tabla en formato Excel (.xlsx o .csv). Se intentará que en PC/Navegador muestre una previsualización antes de descargar.</li></ul> |

</details>

<details>
<summary><strong>v27.02.2026</strong> 🔔🛡️ Notificaciones, Fechas Límite & Seguridad (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Gráficos y Tablas:</b> Se le ha dado un formato acorde al diseño de la app, añadiendo una TopBar para poder salir correctamente. <i>(Nota: A futuro se planea que desde esta tabla se pueda abrir el popup de la tarea para interactuar y cambiar su estado sin tener que salir).</i></li><li><b>Centro de Notificaciones:</b> <ul><li>Icono de campanita (Web y Móvil) con filtros rápidos (1, 3, 7, 15 días).</li><li>Permite marcar notificaciones como leídas.</li><li><b>Móvil:</b> Implementadas notificaciones Push nativas (pendientes de testeo final para confirmar que saltan fuera de la app).</li></ul></li><li><b>Fechas Límite (Deadlines):</b> Ahora se puede asignar una fecha límite al crear una tarea, y también editarla a posteriori.</li><li><b>Edición y Bugfix Crítico (Base de Datos):</b><ul><li>Ahora se puede editar el nombre y descripción de los proyectos y tareas (en tareas también se puede editar la fecha límite, aunque la UI de edición es temporal).</li><li><b>Fix (Desincronización):</b> Se ha arreglado un bug severo oculto: antes, al editar el nombre de un proyecto, no se actualizaba el argumento <code>padre</code> en la colección de sus tareas. Esto rompía la relación, "borrando/ocultando" las tareas y generando proyectos fantasma.</li></ul></li><li><b>Seguridad:</b> Reforzada la protección en los formularios de Login y Register contra inyección de scripts. Ahora solo admiten caracteres seguros (letras, números y guiones).</li><li><b>UI (Preparación):</b> Se ha maquetado visualmente el espacio para añadir comentarios, subtareas y archivos adjuntos (solo es visual, la lógica se implementará más adelante).</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>UI / Accesibilidad:</b> Arreglar la "hitbox" (área de click) de los iconos, ya que ahora mismo hay que ser demasiado preciso con el ratón/dedo para interactuar con ellos.</li><li><b>Sistema de Prioridades:</b> Falta implementar niveles de prioridad en las tareas (Urgente 🔴, Alta 🟡, Normal 🔵, Baja ⚪, Sin prioridad).<ul><li>Esto ordenará las tareas automáticamente hacia arriba y mostrará una franja lateral de color a la izquierda de la tarea.</li></ul></li><li><b>Filtros Avanzados:</b> Evaluar la implementación de un sistema de filtros (por prioridad, estado, orden, etc.) para que el usuario pueda encontrar tareas específicas fácilmente.</li><li><b>Interactividad en la Tabla:</b> Poder hacer click en las tareas desde la pantalla de gráficos para que salga un popup donde se pueda editar el estado (sincronizándose con la BD y la pantalla principal).</li><li><b>Exportación de Datos:</b> Implementar un botón para descargar la tabla en formato Excel (.xlsx o .csv). Se intentará que en PC/Navegador muestre una previsualización antes de descargar.</li></ul> |

</details>

<details>
<summary><strong>v25.02.2026</strong> 📊 Visualización de la Tabla Gráfica de las Tareas (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Gráficas de Tareas:</b> Hemos implementado un nuevo botón que te lleva a una pantalla dedicada donde se pueden visualizar las tareas de manera gráfica y visual, organizadas según su estado (Pendientes, En Curso, etc.).</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>UI y Navegación de Gráficos:</b> Falta centrar la tabla, darle un formato más pulido y añadir la navegación. Actualmente, al entrar a la pantalla de la gráfica te quedas atrapado porque falta la barra superior (AppBar) para poder ir hacia atrás.</li><li><b>Centro de Notificaciones:</b> Queda pendiente todo el sistema de alertas (asignar fecha y hora límite a las tareas y permitir que el usuario especifique cuándo quiere recibir las notificaciones).</li><li><b>Nuevas Funciones (Maquetación):</b> Tenemos que empezar con la preparación visual (UI) de las nuevas características que queremos añadir, para dejar la interfaz lista antes de meterle la lógica.</li></ul> |

</details>

<details>
<summary><strong>v24.02.2026</strong> ✅ Gestión Completa de Tareas (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Gestión de Tareas:</b> Hemos implementado las funciones clave que teníamos pendientes para las tareas.<ul><li><b>Editar y Eliminar:</b> Ahora ya se puede cambiar el estado de las tareas y eliminarlas completamente.</li><li><b>Modal de Información:</b> Hemos añadido el mismo icono de "Info" que tienen los proyectos a cada tarea. Muestra los detalles de la misma (sin contar el apartado de estadísticas).</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Centro de Notificaciones:</b> Queda pendiente añadir un sistema de notificaciones para la aplicación.</li><li><b>Fechas Límite:</b> Falta implementar la opción de asignar una fecha y hora límite (deadline) a las tareas.</li><li><b>Gráficas:</b> Tenemos en la hoja de ruta añadir una tabla gráfica visual para tener un mejor seguimiento de las tareas.</li></ul> |

</details>

<details>
<summary><strong>v14.02.2026</strong> 📱📊 Diseño Responsive & Informacion de los proyectos (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>UI / Responsive:</b> Hemos adaptado la interfaz de la pantalla de proyectos para que se vea perfecta en móviles (Login y Register ya lo estaban).<ul><li><b>Fix:</b> Esto era necesario para solucionar un problema donde el nombre y la descripción del proyecto colapsaban y se veían mal en pantallas pequeñas.</li></ul></li><li><b>Modal de Información:</b> Añadida la funcionalidad prometida en el update anterior. Al pulsar el icono de información en un proyecto ahora se despliega:<ul><li>Nombre y descripción del proyecto.</li><li><b>Estadísticas:</b> Recuento de Tareas totales, completadas y pendientes presentadas de una manera visualmente atractiva.</li><li><b>Controles:</b> Botón definitivo para <b>Eliminar</b> el proyecto y botón de <b>Cerrar</b> pestaña.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Bug Visual / Responsive:</b> Falta hacer responsive la parte de "Crear Proyecto". En móvil salta un pequeño error visual, aunque afortunadamente no impide el funcionamiento lógico de la app.</li><li><b>Tareas:</b> Sigue pendiente poder editar el estado de las tareas y eliminarlas.</li><li><b>Próximamente (Backlog):</b> Implementar la edición de nombre y descripción para proyectos y tareas (y más funciones planeadas para cuando terminemos el Sprint 6).</li></ul> |

</details>

<details>
<summary><strong>v11.02.2026</strong> 🎨✨ Rediseño Total UI/UX & Mejoras Visuales (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Rediseño Visual (UI):</b> Hemos renovado completamente la interfaz a un "Modo Oscuro" profesional con acentos en naranja.<ul><li>Mejoras en tarjetas, diálogos y tipografías para que todo sea consistente con la marca "Pro Task".</li></ul></li><li><b>Drawer:</b><ul><li>Diseño nuevo con cabecera oscura y logo.</li><li><b>Datos de usuario:</b> Ahora muestra el nombre del usuario debajo del logo.</li><li><b>Navegación:</b> Botón de "Cerrar sesión" movido al final y destacado en rojo.</li></ul></li><li><b>Responsive:</b> La estructura ahora se adapta y centra el contenido en pantallas grandes (Web/Tablet) y respeta los bordes en móvil.</li><li><b>Proyectos:</b><ul><li><b>Iconos de Estado:</b> Ahora cada estado del proyecto tiene un icono visual diferente.</li><li>Sustituido el icono de "Papelera" por uno de "Información" (preparación para futura update).</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li><b>Funcionalidad del botón Info:</b> El icono de información en proyectos actualmente sigue <b>eliminando</b> el proyecto.<ul><li>El objetivo es que ahí se muestren estadísticas (tareas completadas/pendientes) y mover la opción de borrar a un menú secundario.</li></ul></li><li><b>Tareas:</b> Falta que el usuario pueda editar estados, eliminar tareas y ver el estado visualmente en la lista.</li><li><b>Bug Visual (Crear Tarea):</b> De manera inusual, al crear una tarea el popup se queda vacío y el fondo se pone blanco.<ul><li><b>Solución temporal:</b> Se arregla recargando la página o yendo hacia atrás.</li><li><b>Nota:</b> No afecta a la lógica (la tarea <b>sí</b> se guarda en la BD), pero se investigará para arreglarlo.</li></ul></li></ul> |

</details>

<details>
<summary><strong>v10.02.2026 parte 2</strong> 🗑️🛠️ Gestión de Proyectos & Estados (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Gestión de Proyectos:</b><ul><li><b>Botón eliminar:</b> Se ha añadido la opción para borrar proyectos.</li><li><b>Eliminación en cascada:</b> Si eliminas un proyecto, se borran automáticamente todas las tareas que contenía dentro.</li></ul></li><li><b>Estados del Proyecto:</b><ul><li><b>Visualización y Edición:</b> Ahora puedes ver y cambiar el estado mediante un desplegable.</li><li><b>Base de Datos:</b> Nuevo argumento <code>estado</code> añadido a la BD; los cambios se guardan en tiempo real.</li><li><b>Estado Inicial:</b> Al crear un proyecto nuevo, se le asigna un estado <code>Por iniciar</code> .</li></ul></li><li><b>Manejo de Errores:</b><ul><li>La aplicación ya no se bloquea (esto fue durante el proceso de la implementacion de la gestion del estado del proyecto) esto pasaba si un proyecto antiguo no tenia el campo <code>estado</code> definido en la BD esto hacia que saliera un error en una pantalla roja.</li><li>Y ahora se mostrara valores por defecto ("Sin nombre", "Sin descripción", "Anónimo", "Sin estado") en lugar de romper la app.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>Cambiar la parte visual del proyecto, tema colores y demas.</li><li>En el apartado de tareas falta:<ul><li>Que el usuario pueda editar el estado de las tareas (Por Iniciar, En Curso, Pausado y Finalizado).</li><li>Que se pueda eliminar las tareas.</li><li>Que el usuario pueda ver el estado de la tarea en donde sale la descripcion o con algo visual, algo asi ("Descripcion" - Creado por "user" - Estado "estado del tarea") y que esto se guarde en la bd para que en un futuro no haya problemas cuando se puedan hacer tareas compartidas.</li></ul></li></ul> |

</details>

<details>
<summary><strong>v10.02.2026 parte 1</strong> 📝✨ Funcionalidad de tareas & Optimizaciones visuales (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Tareas:</b> Ahora se pueden crear tareas y se pueden visualizar y se registran correctamente en la base de datos (el codigo ya estaba puesto pero por alguna razon no compilaba y no se mostraba/insertaba en la base de datos problemas de Firebase Studio supongo).</li><li><b>UI:</b> Etiqueta Debug de Flutter quitada (tan solo habia que añadir: <code>debugShowCheckedModeBanner: false</code>), la banda verde que no tenia nada que ver en las pantallas ya que no pegaba con la sincronía de colores tambien se elimino, y a la hora de abrirlo en web se puede ver en la pestaña el nombres + el logo de la aplicacion.</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>Seguir cambiando la parte visual del proyecto, tema colores y demas.</li><li>En el apartado de proyectos y tareas falta:<ul><li>Que el usuario pueda editar el estado del proyecto/tarea (Por Iniciar, En Curso, Pausado y Finalizado).</li><li>Que se pueda eliminar en ese mismo desplegable.</li><li>Que el usuario pueda ver el estado del proyecto/tarea en donde sale la descripcion y quien lo creo, algo asi ("Descripcion" - Creado por "user" - Estado "estado del proyecto/tarea") y que esto se guarde en la bd (el estado de las tareas si se guarda en la bd pero de los proyectos todavia no) para que en un futuro no haya problemas cuando se puedan hacer proyectos/tareas compartidas.</li></ul></li></ul> |

</details>

<details>
<summary><strong>v09.02.2026</strong> ✨ Calidad de vida UI, Nav y Funcionalidad (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>UI:</b> Botón de cerrar sesión implementado en <code>proyecto.dart</code>.</li><li><b>Nav:</b> Opción para regresar al Login desde el registro.</li><li><b>Funcionalidad:</b> Ahora en los formularios (Login y Register) puedes logearte y registrarte pulsando la tecla <code>Enter</code>.<ul><li>Cosa que antes no se podia ya que al darle enter te quitaba del campo de texto y tenias obligatoriamente darle al boton.</li></ul></li><li><b>Notas de las versiones:</b> Se ha mejorado el README.md para tener un mayor control de las versiones y a su vez las cosas pendientes y contancia del progreso del proyecto.</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>En el apartado de tareas sigue sin poderse crear bien (No se muestra en la bd y tampoco al usuario).</li><li>En el apartado de proyectos falta:<ul><li>Que al darle a los 3 puntos salga un desplegable y ahi se pueda editar el estado del proyecto (Por Iniciar, En Curso, Pausado y Finalizado).</li><li>Que se pueda eliminar en ese mismo desplegable.</li><li>Que el usuario pueda ver el estado del proyecto en donde sale la descripcion y quien lo creo, algo asi ("Descripcion" - Creado por "user" - Estado "estado del proyecto") y que esto se guarde en la base de datos para que en un futuro no haya problemas cuando se puedan hacer proyectos compartidos.</li></ul></li></ul> |

</details>

<details>
<summary><strong>v04.02.2026</strong> 📝 Creacion del apartado de Tareas (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>UI:</b> Nueva ventana de visualización de tareas añadida.</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>El botón de <b>Cerrar Sesión</b> aún no está disponible en la ventana de <i>Proyectos</i> (actualmente solo accesible desde el drawer de <i>Tareas</i>).</li><li>Al intentar crear una tarea no se registra en la base de datos y tampoco se puede visualizar.</li></ul> |

</details>

<details>
<summary><strong>v02.02.2026</strong> ⚙️ Backend & Configuración (Click para ver detalles)</summary>
<br>

| ✨ Novedades |
| :--- |
| <ul><li><b>Firebase:</b> Importación e integración correcta de las dependencias.</li><li><b>Proyecto en general:</b> Implementada la estructura del proyecto a la base de datos (Login/register (funcionales y con validacion), proyectos (cada usuario tenga su propio proyecto) y tareas).</li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>Falta añadir una pantalla/ventana de tareas.</li></ul> |

</details>

<details>
<summary><strong>v19.01.2026</strong> ⚙️ Creacion base del proyecto (Click para ver detalles)</summary>
<br>

| ✨ Novedades del proyecto en general |
| :--- |
| <ul><li>Creacion de las pantallas login y register (funcional de manera local, no se puede logear sin rellenar los campos).</li><li>Creacion de la pantalla de proyecto.<ul><li>Se pueden crear proyectos dentro de la pantalla de proyectos.</li></ul></li></ul> |

| ⚠️ Pendiente / Known Issues |
| :--- |
| <ul><li>Importar la base de datos para el login y el register que sea funcional y tenga validacion si el usuario y la contraseña no coincide con la bd, salte un error en un mensaje para el usuario.</li><li>Que cada usuario tenga su propio proyecto ya que ahora mismo independientemente del usuario los proyectos se guardan de manera local, esto con la importacion de la bd se arreglaria.</li></ul> |

</details>
