import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nsd/nsd.dart' as nsd;
import 'logger_service.dart';

class DiscoveredDevice {
  final String endpointId;
  final String endpointName;
  final String? host;
  final int? port;

  DiscoveredDevice({
    required this.endpointId,
    required this.endpointName,
    this.host,
    this.port,
  });
}

class P2PService {
  nsd.Registration? _nsdRegistration;
  nsd.Discovery? _nsdDiscovery;
  ServerSocket? _serverSocket;
  final Map<String, Socket> _connectedSockets = {};
  final Map<String, StringBuffer> _receiveBuffers = {};
  Timer? _heartbeatTimer;

  final _devicesController = StreamController<DiscoveredDevice>.broadcast();
  final _messagesController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<String>.broadcast();
  final _disconnectionController = StreamController<String>.broadcast();

  Stream<DiscoveredDevice> get onDeviceFound => _devicesController.stream;
  Stream<Map<String, dynamic>> get onMessageReceived => _messagesController.stream;
  Stream<String> get onConnected => _connectionController.stream;
  Stream<String> get onDisconnected => _disconnectionController.stream;

  final Set<String> _connectedEndpoints = {};
  int get connectedEndpointCount => _connectedEndpoints.length;
  int? get hostPort => _serverSocket?.port;

  P2PService();

  /// Obtains the current device's local IPv4 address on the Wi-Fi or LAN.
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (e, s) {
      AppLogger().error('P2P: Error obteniendo IP local: $e', s);
    }
    return null;
  }

  Future<void> startAdvertising(String deviceName) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      AppLogger().log('P2P: Servidor escuchando en puerto ${_serverSocket!.port}');

      _serverSocket!.listen((Socket clientSocket) {
        final endpointId = '${clientSocket.remoteAddress.address}:${clientSocket.remotePort}';
        _connectedSockets[endpointId] = clientSocket;
        _connectedEndpoints.add(endpointId);
        _receiveBuffers[endpointId] = StringBuffer();
        _connectionController.add(endpointId);

        clientSocket.listen(
          (Uint8List data) => _handlePayloadReceived(endpointId, data),
          onDone: () => _handleDisconnected(endpointId),
          onError: (_) => _handleDisconnected(endpointId),
        );
      });

      // Start periodic heartbeat to keep connections alive and detect drops
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        broadcastMessage({'type': 'HEARTBEAT'});
      });

      // Register mDNS service for local auto-discovery
      try {
        final service = nsd.Service(name: deviceName, type: '_poker._tcp', port: _serverSocket!.port);
        _nsdRegistration = await nsd.register(service);
        AppLogger().log('P2P: Servicio mDNS registrado con éxito');
      } catch (e) {
        AppLogger().log('P2P: Aviso - mDNS no disponible en esta plataforma (use conexión por IP)');
      }
    } catch (e, s) {
      AppLogger().error('P2P: Error al iniciar advertising: $e', s);
    }
  }

  Future<void> startDiscovery(String deviceName) async {
    try {
      _nsdDiscovery = await nsd.startDiscovery('_poker._tcp', autoResolve: true);
      _nsdDiscovery!.addListener(() {
        for (final service in _nsdDiscovery!.services) {
          if (service.name != null && service.host != null && service.port != null) {
            final host = service.host!;
            final endpointId = '$host:${service.port}';
            _devicesController.add(
              DiscoveredDevice(
                endpointId: endpointId,
                endpointName: service.name!,
                host: host,
                port: service.port!,
              ),
            );
          }
        }
      });
    } catch (e) {
      AppLogger().log('P2P: Aviso - Descubrimiento mDNS no disponible');
    }
  }

  Future<void> connectToDevice(String endpointId) async {
    final parts = endpointId.split(':');
    if (parts.length != 2) return;

    final host = parts[0];
    final port = int.tryParse(parts[1]) ?? 0;
    await connectToHost(host, port);
  }

  /// Connects directly to a host via IPv4 address and port.
  Future<bool> connectToHost(String host, int port) async {
    final endpointId = '$host:$port';
    AppLogger().log('P2P: Intentando conectar a $endpointId');
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 6));
      _connectedSockets[endpointId] = socket;
      _connectedEndpoints.add(endpointId);
      _receiveBuffers[endpointId] = StringBuffer();
      _connectionController.add(endpointId);

      socket.listen(
        (Uint8List data) => _handlePayloadReceived(endpointId, data),
        onDone: () => _handleDisconnected(endpointId),
        onError: (_) => _handleDisconnected(endpointId),
      );
      AppLogger().log('P2P: Conectado exitosamente a $endpointId');
      return true;
    } catch (e) {
      AppLogger().log('P2P: Error de conexión a $endpointId: $e');
      _handleDisconnected(endpointId);
      return false;
    }
  }

  void _handleDisconnected(String endpointId) {
    AppLogger().log('P2P: Desconectado: $endpointId');
    _connectedSockets[endpointId]?.destroy();
    _connectedSockets.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    _receiveBuffers.remove(endpointId);
    _disconnectionController.add(endpointId);
  }

  /// Buffers incoming stream data per endpoint and parses complete newline-delimited JSON messages.
  void _handlePayloadReceived(String endpointId, Uint8List payload) {
    final buffer = _receiveBuffers.putIfAbsent(endpointId, () => StringBuffer());
    final text = utf8.decode(payload, allowMalformed: true);
    buffer.write(text);

    final content = buffer.toString();
    final parts = content.split('\n');

    // Keep the trailing incomplete part in the buffer
    buffer.clear();
    buffer.write(parts.last);

    // Process all fully arrived messages
    for (var i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isEmpty) continue;
      try {
        final jsonData = jsonDecode(line) as Map<String, dynamic>;
        if (jsonData['type'] == 'HEARTBEAT') {
          // Heartbeat received - socket is alive
          continue;
        }
        jsonData['_senderEndpointId'] = endpointId;
        _messagesController.add(jsonData);
      } catch (e) {
        AppLogger().error('P2P: Error decodificando mensaje JSON: $e');
      }
    }
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    final socket = _connectedSockets[endpointId];
    if (socket != null) {
      final jsonString = jsonEncode(data) + '\n';
      socket.add(utf8.encode(jsonString));
    }
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data) + '\n';
    final bytes = utf8.encode(jsonString);

    for (final socket in _connectedSockets.values) {
      socket.add(bytes);
    }
  }

  Future<void> stopAdvertising() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_nsdRegistration != null) {
      try {
        await nsd.unregister(_nsdRegistration!);
      } catch (_) {}
      _nsdRegistration = null;
    }
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> stopDiscovery() async {
    if (_nsdDiscovery != null) {
      try {
        await nsd.stopDiscovery(_nsdDiscovery!);
      } catch (_) {}
      _nsdDiscovery = null;
    }
  }

  Future<void> disconnectAll() async {
    await stopAdvertising();
    await stopDiscovery();
    for (final socket in _connectedSockets.values) {
      socket.destroy();
    }
    _connectedSockets.clear();
    _connectedEndpoints.clear();
    _receiveBuffers.clear();
  }

  Future<void> dispose() async {
    await disconnectAll();
    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
    await _disconnectionController.close();
  }
}
