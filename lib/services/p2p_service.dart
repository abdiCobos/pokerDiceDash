import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'firebase_transport.dart';

class DiscoveredDevice {
  final String endpointId;
  final String endpointName;

  DiscoveredDevice({required this.endpointId, required this.endpointName});
}

class P2PService {
  final Nearby _nearby = Nearby();
  final Strategy _strategy;
  final bool _useFirebase;
  FirebaseTransport? _firebase;

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

  P2PService({
    Strategy strategy = Strategy.P2P_CLUSTER,
    bool useFirebase = false,
    FirebaseTransport? firebase,
  })  : _strategy = strategy,
        _useFirebase = useFirebase,
        _firebase = firebase {
    if (_useFirebase) {
      _firebase ??= FirebaseTransport();
      _wireFirebase();
    }
  }

  void _wireFirebase() {
    if (_firebase == null) return;
    _firebase!.onDeviceFound.listen((d) => _devicesController.add(d));
    _firebase!.onMessageReceived.listen((m) => _messagesController.add(m));
    _firebase!.onConnected.listen((id) {
      _connectedEndpoints.add(id);
      _connectionController.add(id);
    });
    _firebase!.onDisconnected.listen((id) {
      _connectedEndpoints.remove(id);
      _disconnectionController.add(id);
    });
  }

  Future<void> startAdvertising(String deviceName) async {
    if (_useFirebase) {
      await _firebase!.startAdvertising(deviceName);
      return;
    }
    await _nearby.startAdvertising(
      deviceName,
      _strategy,
      onConnectionInitiated: (endpointId, connectionInfo) {
        _handleConnectionInitiated(endpointId, connectionInfo);
      },
      onConnectionResult: (endpointId, status) {
        _handleConnectionResult(endpointId, status);
      },
      onDisconnected: (endpointId) {
        _handleDisconnected(endpointId);
      },
    );
  }

  Future<void> startDiscovery(String deviceName) async {
    if (_useFirebase) {
      await _firebase!.startDiscovery(deviceName);
      return;
    }
    await _nearby.startDiscovery(
      deviceName,
      _strategy,
      onEndpointFound: (endpointId, endpointName, serviceId) {
        _devicesController.add(
          DiscoveredDevice(
            endpointId: endpointId,
            endpointName: endpointName,
          ),
        );
      },
      onEndpointLost: (endpointId) {},
    );
  }

  Future<void> connectToDevice(String endpointId) async {
    if (_useFirebase) {
      await _firebase!.connectToDevice(endpointId);
      return;
    }
    await _nearby.requestConnection(
      'device',
      endpointId,
      onConnectionInitiated: (id, info) {
        _handleConnectionInitiated(id, info);
      },
      onConnectionResult: (id, status) {
        _handleConnectionResult(id, status);
      },
      onDisconnected: (id) {
        _handleDisconnected(id);
      },
    );
  }

  void _handleConnectionInitiated(String endpointId, ConnectionInfo info) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        _handlePayloadReceived(endpointId, payload);
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
  }

  void _handleConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);
      _connectionController.add(endpointId);
    }
  }

  void _handleDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _disconnectionController.add(endpointId);
  }

  void _handlePayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final message = utf8.decode(payload.bytes!);
      try {
        final jsonData = jsonDecode(message) as Map<String, dynamic>;
        jsonData['_senderEndpointId'] = endpointId;
        _messagesController.add(jsonData);
      } catch (_) {}
    }
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    if (_useFirebase) {
      await _firebase!.sendMessage(endpointId, data);
      return;
    }
    final jsonString = jsonEncode(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    if (_useFirebase) {
      await _firebase!.broadcastMessage(data);
      return;
    }
    for (final endpointId in _connectedEndpoints) {
      await sendMessage(endpointId, data);
    }
  }

  Future<void> stopAdvertising() async {
    if (_useFirebase) {
      await _firebase!.stopAdvertising();
      return;
    }
    await _nearby.stopAdvertising();
  }

  Future<void> stopDiscovery() async {
    if (_useFirebase) {
      await _firebase!.stopDiscovery();
      return;
    }
    await _nearby.stopDiscovery();
  }

  Future<void> disconnectAll() async {
    if (_useFirebase) {
      await _firebase!.disconnectAll();
      return;
    }
    await _nearby.stopAllEndpoints();
    _connectedEndpoints.clear();
  }

  Future<void> dispose() async {
    if (_useFirebase) {
      _firebase!.dispose();
    }
    await disconnectAll();
    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
    await _disconnectionController.close();
  }
}
