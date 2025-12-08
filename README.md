# Pasos para crear el proyecto

## Instalar flutter

En tu ordenador ejecuta los siguientes comandos:

``sudo snap install flutter --classic``

``flutter sdk-path``

---

## Crear proyecto flutter

Entrar en la carpeta en la que querais tener el proyecto:

``flutter create cola_virtual_app``

---

## Vincular con FireBase (Diria que no teneis que hacerlo)

En tu ordenador ejecuta los siguientes comandos:

``npm install -g firebase-tools``

``firebase login``

``dart pub global activate flutterfire_cli``

En la carpeta del proyecto flutter
``flutterfire configure``

---

## Ejecutar aplicacion

En la carpeta del proyecto flutter:

``flutter run -d web-server``

Abrirlo en el navegador con el puerto que te pone
