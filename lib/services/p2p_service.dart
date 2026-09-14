import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nsd/nsd.dart' as nsd;

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

  P2PService();

  Future<void> startAdvertising(String deviceName) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _serverSocket!.listen((Socket clientSocket) {
      final endpointId = '${clientSocket.remoteAddress.address}:${clientSocket.remotePort}';
      _connectedSockets[endpointId] = clientSocket;
      _connectedEndpoints.add(endpointId);
      _connectionController.add(endpointId);
      
      clientSocket.listen(
        (Uint8List data) => _handlePayloadReceived(endpointId, data),
        onDone: () => _handleDisconnected(endpointId),
        onError: (_) => _handleDisconnected(endpointId),
      );
    });

    final service = nsd.Service(name: deviceName, type: '_poker._tcp', port: _serverSocket!.port);
    _nsdRegistration = await nsd.register(service);
  }

  Future<void> startDiscovery(String deviceName) async {
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
  }

  Future<void> connectToDevice(String endpointId) async {
    final parts = endpointId.split(':');
    if (parts.length != 2) return;
    
    final host = parts[0];
    final port = int.tryParse(parts[1]) ?? 0;
    
    try {
      final socket = await Socket.connect(host, port);
      _connectedSockets[endpointId] = socket;
      _connectedEndpoints.add(endpointId);
      _connectionController.add(endpointId);
      
      socket.listen(
        (Uint8List data) => _handlePayloadReceived(endpointId, data),
        onDone: () => _handleDisconnected(endpointId),
        onError: (_) => _handleDisconnected(endpointId),
      );
    } catch (e) {
      _handleDisconnected(endpointId);
    }
  }

  void _handleDisconnected(String endpointId) {
    _connectedSockets[endpointId]?.destroy();
    _connectedSockets.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    _disconnectionController.add(endpointId);
  }

  void _handlePayloadReceived(String endpointId, Uint8List payload) {
    final message = utf8.decode(payload);
    
    // Split by newlines in case multiple JSON objects were sent in one TCP packet
    final parts = message.split('\n');
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      try {
        final jsonData = jsonDecode(part) as Map<String, dynamic>;
        jsonData['_senderEndpointId'] = endpointId;
        _messagesController.add(jsonData);
      } catch (_) {}
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
    if (_nsdRegistration != null) {
      await nsd.unregister(_nsdRegistration!);
      _nsdRegistration = null;
    }
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> stopDiscovery() async {
    if (_nsdDiscovery != null) {
      await nsd.stopDiscovery(_nsdDiscovery!);
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
  }

  Future<void> dispose() async {
    await disconnectAll();
    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
    await _disconnectionController.close();
  }
}
