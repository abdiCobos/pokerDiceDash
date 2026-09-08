# Poker Dice Dash 🎲🃏

**Poker Dice Dash** es un juego para dispositivos móviles desarrollado en Flutter que reúne la emoción del casino y los juegos de mesa clásicos en un solo lugar. Disfruta de múltiples modos de juego, tanto en solitario como en multijugador.

## 🎮 Modos de Juego

1. **21 Black Jack**
   - El clásico juego de casino donde debes vencer al crupier (Dealer) acercándote lo más posible a 21 sin pasarte.
   - **Reglas especiales:** Implementación de la regla "5-Card Charlie" (si consigues 5 cartas en una mano sin pasarte de 21, ¡ganas automáticamente 1 a 1!).
   - Opciones para Pedir, Plantarse, Doblar y Dividir (Split).
   - Bots inteligentes en modo solitario y opciones multijugador.

2. **Texas Hold'em Poker**
   - Reta a tus amigos o a los bots en el modo de póker más famoso del mundo.
   - Apuestas, rondas de Flop, Turn y River con gestión avanzada de botes y combinaciones.

3. **Dice Dash**
   - Un modo rápido y divertido basado en lanzamiento de dados.

## 🌐 Modos Multijugador

- **Práctica (Solitario):** Juega sin conexión contra el Crupier o contra bots integrados en la aplicación.
- **Local (Nearby):** Crea salas locales y conecta con amigos en la misma red o por Bluetooth utilizando la tecnología de *Nearby Connections*.
- **Global:** Crea salas globales y juega con oponentes a través de internet (Sincronización en tiempo real con Firebase).

## 🚀 Características Técnicas

- Construido con **Flutter** para lograr rendimiento nativo en Android.
- Acomodo de interfaz adaptable (`_s` responsive factor) y animaciones fluidas (slide-in cards).
- Arquitectura basada en **Provider** para la gestión de estados (`GameProvider`, `BlackjackProvider`).
- Rendering nativo avanzado mediante **Impeller (Vulkan)**.

## 🛠 Instalación y Ejecución Local

Para compilar y ejecutar este proyecto en tu entorno local:

1. Asegúrate de tener instalado [Flutter](https://flutter.dev/docs/get-started/install).
2. Clona el repositorio:
   ```bash
   git clone https://github.com/abdiCobos/pokerDiceDash.git
   ```
3. Instala las dependencias:
   ```bash
   cd poker_dice_dash
   flutter pub get
   ```
4. Conecta tu dispositivo Android (vía USB o depuración inalámbrica) y ejecuta:
   ```bash
   flutter run
   ```

## 📝 Contribuciones
¡Toda contribución es bienvenida! Si deseas mejorar la inteligencia de los bots, agregar nuevos modos de juego o refinar el código, siéntete libre de hacer un Fork y enviar un Pull Request.

---
*Desarrollado con ❤️ para los amantes del Poker, el Blackjack y los Dados.*
