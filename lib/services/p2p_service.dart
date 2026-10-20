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
  /// A peer that sends nothing (not even a heartbeat) for this long is dead.
  static const Duration heartbeatInterval = Duration(seconds: 4);
  static const Duration heartbeatTimeout = Duration(seconds: 12);

  nsd.Registration? _nsdRegistration;
  nsd.Discovery? _nsdDiscovery;
  ServerSocket? _serverSocket;
  final Map<String, Socket> _connectedSockets = {};
  final Map<String, BytesBuilder> _receiveBuffers = {};
  final Map<String, DateTime> _lastSeen = {};
  Timer? _heartbeatTimer;

  /// Last host we connected to as a client (used for auto-reconnect).
  String? lastHost;
  int? lastPort;

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
  List<String> get connectedEndpoints => _connectedEndpoints.toList();
  int? get hostPort => _serverSocket?.port;
  bool get isServing => _serverSocket != null;

  P2PService();

  /// Adapters that are never the shared Wi-Fi/LAN (PCs often list these first).
  static final RegExp _virtualAdapter = RegExp(
    r'vEthernet|Hyper-V|WSL|VirtualBox|VMware|vmnet|vboxnet|docker|br-|veth|virbr|'
    r'Tailscale|ZeroTier|Hamachi|WireGuard|wg\d|tun\d|TAP-|^tap\d|utun|VPN|Bluetooth|llw|awdl|Loopback',
    caseSensitive: false,
  );

  /// Ranks an IPv4 address/interface: higher is more likely the LAN other players see.
  static int scoreAddress(String interfaceName, String address) {
    if (_virtualAdapter.hasMatch(interfaceName)) return 0;
    final o = address.split('.').map(int.tryParse).toList();
    if (o.length != 4 || o.contains(null)) return 0;
    final a = o[0]!, b = o[1]!;
    var score = 1;
    if (a == 192 && b == 168) {
      score = 40;
      if (o[2] == 56 || o[2] == 99) score = 5; // VirtualBox / Docker defaults
    } else if (a == 10) {
      score = 30;
    } else if (a == 172 && b >= 16 && b <= 31) {
      score = 10; // also used by Docker/WSL
    }
    final n = interfaceName.toLowerCase();
    if (n.contains('wi-fi') || n.contains('wifi') || n.contains('wlan') || n.startsWith('wl') || n == 'en0') {
      score += 6;
    } else if (n.contains('ethernet') || n.startsWith('eth') || n.startsWith('en')) {
      score += 4;
    }
    return score;
  }

  /// All plausible LAN IPv4 addresses of this device, best first.
  static Future<List<String>> getLocalIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final scored = <(int, String)>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.isLoopback || addr.isLinkLocal) continue;
          final score = scoreAddress(interface.name, addr.address);
          if (score > 0) scored.add((score, addr.address));
        }
      }
      scored.sort((x, y) => y.$1.compareTo(x.$1));
      return [for (final e in scored) e.$2];
    } catch (e, s) {
      AppLogger().error('P2P: Error obteniendo IP local: $e', s);
      return const [];
    }
  }

  /// The local IPv4 address other devices on the Wi-Fi/LAN should use.
  static Future<String?> getLocalIpAddress() async {
    final all = await getLocalIpAddresses();
    return all.isEmpty ? null : all.first;
  }

  /// Splits "host:port", accepting IPv6 hosts ("[fe80::1]:5000" or "fe80::1:5000").
  static (String, int)? parseEndpoint(String endpointId) {
    final i = endpointId.lastIndexOf(':');
    if (i <= 0 || i == endpointId.length - 1) return null;
    var host = endpointId.substring(0, i);
    final port = int.tryParse(endpointId.substring(i + 1));
    if (port == null || port <= 0 || port > 65535) return null;
    if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
    return (host, port);
  }

  void _emit<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) controller.add(value);
  }

  /// Registers a freshly opened socket (server side or client side).
  void _registerSocket(String endpointId, Socket socket) {
    // Drop a stale socket with the same id, if any.
    final old = _connectedSockets[endpointId];
    if (old != null && !identical(old, socket)) {
      try {
        old.destroy();
      } catch (_) {}
    }
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    _connectedSockets[endpointId] = socket;
    _connectedEndpoints.add(endpointId);
    _receiveBuffers[endpointId] = BytesBuilder(copy: false);
    _lastSeen[endpointId] = DateTime.now();
    _ensureHeartbeat();
    _emit(_connectionController, endpointId);

    socket.listen(
      (Uint8List data) => _handlePayloadReceived(endpointId, data),
      onDone: () => _handleDisconnected(endpointId, socket),
      onError: (_) => _handleDisconnected(endpointId, socket),
      cancelOnError: true,
    );
    // Broken pipes / resets on write are reported through `done`, not as exceptions.
    socket.done.then<void>((_) {}, onError: (Object _) => _handleDisconnected(endpointId, socket));
  }

  Future<void> startAdvertising(String deviceName) async {
    try {
      // Keep the same port for the whole room lifetime so clients can reconnect.
      if (_serverSocket == null) {
        final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
        _serverSocket = server;
        AppLogger().log('P2P: Servidor escuchando en puerto ${server.port}');

        server.listen(
          (Socket clientSocket) {
            final endpointId =
                '${clientSocket.remoteAddress.address}:${clientSocket.remotePort}';
            _registerSocket(endpointId, clientSocket);
          },
          onError: (e) => AppLogger().log('P2P: Error en servidor: $e'),
        );
      }

      _ensureHeartbeat();
      await updateServiceName(deviceName);
    } catch (e, s) {
      AppLogger().error('P2P: Error al iniciar advertising: $e', s);
    }
  }

  Future<void> _nsdQueue = Future<void>.value();

  /// Re-publishes the mDNS record with a new name WITHOUT touching the TCP
  /// server socket (its port must stay stable). Calls are serialized.
  Future<void> updateServiceName(String name) {
    _nsdQueue = _nsdQueue.then((_) async {
      final server = _serverSocket;
      if (server == null) return;
      if (_nsdRegistration != null) {
        try {
          await nsd.unregister(_nsdRegistration!);
        } catch (_) {}
        _nsdRegistration = null;
      }
      try {
        final service = nsd.Service(name: name, type: '_poker._tcp', port: server.port);
        _nsdRegistration = await nsd.register(service);
        AppLogger().log('P2P: Servicio mDNS registrado con éxito');
      } catch (e) {
        AppLogger().log('P2P: Aviso - mDNS no disponible en esta plataforma (use conexión por IP)');
      }
    }).catchError((Object _) {});
    return _nsdQueue;
  }

  Future<void> startDiscovery(String deviceName) async {
    try {
      // Ask for IPv4 addresses: a ".local" hostname from a PC often does not
      // resolve on Android, and IPv6 link-local needs a scope id.
      _nsdDiscovery = await nsd.startDiscovery('_poker._tcp', autoResolve: true, ipLookupType: nsd.IpLookupType.v4);
      _nsdDiscovery!.addListener(() {
        for (final service in _nsdDiscovery!.services) {
          final v4 = service.addresses?.where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback);
          final host = (v4 != null && v4.isNotEmpty) ? v4.first.address : service.host;
          if (service.name != null && host != null && service.port != null) {
            final endpointId = '$host:${service.port}';
            _emit(
              _devicesController,
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

  Future<bool> connectToDevice(String endpointId) async {
    final parsed = parseEndpoint(endpointId);
    if (parsed == null) {
      AppLogger().log('P2P: Endpoint inválido: $endpointId');
      return false;
    }
    return connectToHost(parsed.$1, parsed.$2);
  }

  /// Connects directly to a host via IPv4 address and port.
  Future<bool> connectToHost(String host, int port) async {
    final endpointId = '$host:$port';
    AppLogger().log('P2P: Intentando conectar a $endpointId');
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 6));
      lastHost = host;
      lastPort = port;
      _registerSocket(endpointId, socket);
      AppLogger().log('P2P: Conectado exitosamente a $endpointId');
      return true;
    } catch (e) {
      AppLogger().log('P2P: Error de conexión a $endpointId: $e');
      return false;
    }
  }

  /// Re-opens the last client connection (same host/port). Returns true on success.
  Future<bool> reconnectToLastHost() async {
    final h = lastHost;
    final p = lastPort;
    if (h == null || p == null) return false;
    return connectToHost(h, p);
  }

  void _handleDisconnected(String endpointId, [Socket? source]) {
    final current = _connectedSockets[endpointId];
    // Ignore callbacks from a socket that was already replaced.
    if (source != null && current != null && !identical(current, source)) return;
    final wasKnown = _connectedEndpoints.contains(endpointId);
    try {
      current?.destroy();
    } catch (_) {}
    _connectedSockets.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    _receiveBuffers.remove(endpointId);
    _lastSeen.remove(endpointId);
    if (_connectedSockets.isEmpty && _serverSocket == null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
    if (wasKnown) {
      AppLogger().log('P2P: Desconectado: $endpointId');
      _emit(_disconnectionController, endpointId);
    }
  }

  void _ensureHeartbeat() {
    if (_heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final now = DateTime.now();
      for (final id in _connectedSockets.keys.toList()) {
        final seen = _lastSeen[id];
        if (seen != null && now.difference(seen) > heartbeatTimeout) {
          AppLogger().log('P2P: Timeout de heartbeat: $id');
          _handleDisconnected(id);
        }
      }
      broadcastMessage({'type': 'HEARTBEAT'});
    });
  }

  /// Buffers incoming bytes per endpoint and parses complete newline-delimited JSON messages.
  /// Works on raw bytes so multi-byte UTF-8 characters split across TCP chunks stay intact.
  void _handlePayloadReceived(String endpointId, Uint8List payload) {
    if (!_connectedSockets.containsKey(endpointId)) return; // late data from a dead peer
    _lastSeen[endpointId] = DateTime.now();
    final buffer = _receiveBuffers.putIfAbsent(endpointId, () => BytesBuilder(copy: false));
    buffer.add(payload);

    final all = buffer.takeBytes();
    var start = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i] != 0x0A) continue;
      if (i > start) {
        _processLine(endpointId, all.sublist(start, i));
      }
      start = i + 1;
    }
    if (start < all.length) {
      buffer.add(all.sublist(start));
    }
  }

  void _processLine(String endpointId, List<int> bytes) {
    try {
      final line = utf8.decode(bytes, allowMalformed: true).trim();
      if (line.isEmpty) return;
      final jsonData = jsonDecode(line) as Map<String, dynamic>;
      if (jsonData['type'] == 'HEARTBEAT') return; // socket is alive
      jsonData['_senderEndpointId'] = endpointId;
      _emit(_messagesController, jsonData);
    } catch (e) {
      AppLogger().error('P2P: Error decodificando mensaje JSON: $e');
    }
  }

  bool _safeWrite(String endpointId, Socket socket, List<int> bytes) {
    try {
      socket.add(bytes);
      return true;
    } catch (e) {
      AppLogger().log('P2P: Error de escritura en $endpointId: $e');
      _handleDisconnected(endpointId, socket);
      return false;
    }
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    final socket = _connectedSockets[endpointId];
    if (socket == null) return;
    _safeWrite(endpointId, socket, utf8.encode('${jsonEncode(data)}\n'));
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    if (_connectedSockets.isEmpty) return;
    final bytes = utf8.encode('${jsonEncode(data)}\n');
    for (final entry in _connectedSockets.entries.toList()) {
      _safeWrite(entry.key, entry.value, bytes);
    }
  }

  /// Closes one peer connection (e.g. a kicked or replaced client).
  void disconnectEndpoint(String endpointId) => _handleDisconnected(endpointId);

  bool isEndpointConnected(String endpointId) => _connectedEndpoints.contains(endpointId);

  Future<void> stopAdvertising() async {
    if (_nsdRegistration != null) {
      try {
        await nsd.unregister(_nsdRegistration!);
      } catch (_) {}
      _nsdRegistration = null;
    }
    await _serverSocket?.close();
    _serverSocket = null;
    if (_connectedSockets.isEmpty) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    for (final socket in _connectedSockets.values.toList()) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _connectedSockets.clear();
    _connectedEndpoints.clear();
    _receiveBuffers.clear();
    _lastSeen.clear();
  }

  Future<void> dispose() async {
    await disconnectAll();
    await _devicesController.close();
    await _messagesController.close();
    await _connectionController.close();
    await _disconnectionController.close();
  }
}
