# Tap & Go

## Pasos para crear la apk

### Instalar flutter

En tu ordenador ejecuta los siguientes comandos:

``sudo snap install flutter --classic``

``flutter sdk-path``

---

### Construir la APK

Dentro del proyecto de flutter ejecutar el comando:

``flutter build apk``

La apk se encontrara en el directorio: build/app/outputs/flutter-apk

---

## Estructura de archivos 

- lib/config/app_colors.dart: Contiene la clase AppColors con las constantes de color de la aplicación.
- lib/config/app_theme.dart: Contiene la clase TapAndGoApp que define el tema general de la aplicación.
- lib/screens/common/qr_scanner_screen.dart: Contiene la vista para escanear QRs.
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
- lib/screens/admin/views/admin_parking_validator: La vista para que el administrador valide los tickets de parking de los clientes.
- lib/screens/admin/views/admin_stats.dart: La vista para que el administrador visualize las estadisticas de su tienda.
- lib/main.dart: El punto de entrada de la aplicación.
- lib/services: Contiene las conexiones a los servicios de firebase de cada vista.
