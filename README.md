# Tap & Go

## Pasos para crear el proyecto

### Instalar flutter

En tu ordenador ejecuta los siguientes comandos:

``sudo snap install flutter --classic``

``flutter sdk-path``

---

### Crear proyecto flutter

Entrar en la carpeta en la que querais tener el proyecto:

``flutter create cola_virtual_app``

---

### Vincular con FireBase (Diria que no teneis que hacerlo)

En tu ordenador ejecuta los siguientes comandos:

``npm install -g firebase-tools``

``firebase login``

``dart pub global activate flutterfire_cli``

En la carpeta del proyecto flutter
``flutterfire configure``

---

### Ejecutar aplicacion

En la carpeta del proyecto flutter:

``flutter run -d web-server``

Abrirlo en el navegador con el puerto que te pone

---

### Estructura de archivos 


- lib/config/app_colors.dart: Contiene la clase AppColors con las constantes de color de la aplicación.
- lib/config/app_theme.dart: Contiene la clase TapAndGoApp que define el tema general de la aplicación.
- lib/screens/auth/welcome_screen.dart: La pantalla de bienvenida inicial.
- lib/screens/auth/owner_login_screen.dart: La pantalla de inicio de sesión para propietarios.
- lib/screens/client/client_root_screen.dart: La pantalla principal para la vista del cliente.
- lib/screens/client/views/active_queue_view.dart: La vista para cuando el cliente está en una cola.
- lib/screens/client/views/empty_queue_view.dart: La vista para cuando el cliente no está en ninguna cola.
- lib/screens/client/views/offers_list_view.dart: La vista que muestra la lista de ofertas.
- lib/screens/client/views/parking_ticket_view.dart: La vista que muestra el ticket de estacionamiento.
- lib/screens/admin/admin_root_screen.dart: La pantalla principal para la vista del administrador.
- lib/screens/admin/views/admin_queue_control.dart: La vista para que el administrador controle la cola.
- lib/screens/admin/views/admin_offers_manager.dart: La vista para que el administrador gestione las ofertas.
- lib/main.dart: El punto de entrada de la aplicación.
- lib/services: Contiene las conexiones a los servicios de firebase
