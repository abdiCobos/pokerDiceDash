# Poker Dice Dash - Session Checkpoint

## Estado Actual (13 de Septiembre)
- **Evaluador de Manos**: Se eliminó la dependencia externa (`poker_lib`) ya que contenía bugs lógicos para menos de 7 cartas. Se reescribió todo el motor de evaluación desde cero (`lib/models/hand_evaluator.dart`). El nuevo evaluador soporta de 1 a 7 cartas, identifica las manos correctamente, desempatadores, y es 100% determinista sin errores.
- **Navegación / UI**: Se agregaron botones de "Atrás/Salir" explícitos en las vistas de juego (`game_table_screen.dart` y `blackjack_table_screen.dart`). En Blackjack se arregló un bug de desbordamiento visual (overflow amarillo/negro) y se eliminó información duplicada de fichas/apuestas en el panel inferior.
- **Telemetría**: Se eliminó la pantalla inicial de "Aviso importante" de Sentry.
- **Limpieza**: Se purgó la historia git para borrar a `commandcodebot`, se agregó el archivo de licencia correcto y la app subió limpia a GitHub.

## Próximos Pasos (Next Session)
El usuario quiere implementar soporte para **mesas expandidas (6-9 jugadores)** en Póker y agregar bots (NPCs).
1. **Lógica de Bots (NPCs)**: Agregar IA que pueda tomar decisiones (Fold, Call, Raise) basándose en las probabilidades calculadas por nuestro nuevo `HandEvaluator`.
2. **Expansión de UI (6-9 jugadores)**: Modificar `game_table_screen.dart` para que los asientos soporten hasta 9 jugadores. Actualmente los asientos (`_PlayerSeat`) están posicionados de manera estática (`bottom`, `top`, `left`, `right`). Se requerirá un diseño en óvalo o circular (`Stack` con matemáticas polares como se hizo en Blackjack) o deslizable si la mesa crece demasiado.
3. **Escalabilidad P2P**: Asegurarse de que el servidor P2P (NSD) o `GameProvider` no reviente al sincronizar 9 jugadores, o inyectar a los NPCs como clientes falsos que corren localmente en el dispositivo del Host.

## Archivos Clave
- `lib/models/hand_evaluator.dart`: El motor matemático de evaluación (vital para la IA de NPCs).
- `lib/providers/game_provider.dart`: Motor de estados del Poker. Aquí es donde se conectarán los turnos automáticos de los NPCs.
- `lib/ui/screens/game_table_screen.dart`: UI de Póker (modificar para soportar >4 jugadores).
