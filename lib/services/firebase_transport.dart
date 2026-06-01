import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'p2p_service.dart';

class FirebaseTransport {
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

  String _currentRoomId = '';
  String _myId = '';
  StreamSubscription? _lobbySub;
  StreamSubscription? _roomSub;

  FirebaseTransport() {
    _myId = _randomId();
  }

  String _randomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String get myId => _myId;
  String get currentRoomId => _currentRoomId;

  Future<void> startAdvertising(String deviceName) async {
    _currentRoomId = 'room_${_randomId()}';
    _connectedEndpoints.add(_myId);
    await FirebaseFirestore.instance.collection('lobby').doc(_currentRoomId).set({
      'endpointId': _currentRoomId,
      'endpointName': deviceName,
      'createdAt': FieldValue.serverTimestamp(),
      'hostId': _myId,
    });
    _listenToRoomMessages();
    _connectionController.add(_myId);
  }

  Future<void> startDiscovery(String deviceName) async {
    _lobbySub = FirebaseFirestore.instance.collection('lobby').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        if (change.type == DocumentChangeType.added) {
          if (data['hostId'] != _myId) {
            _devicesController.add(DiscoveredDevice(
              endpointId: data['endpointId'] as String,
              endpointName: data['endpointName'] as String? ?? '',
            ));
          }
        }
      }
    });
  }

  Future<void> connectToDevice(String endpointId) async {
    _currentRoomId = endpointId;
    _connectedEndpoints.add(_myId);
    _listenToRoomMessages();
    _connectionController.add(endpointId);
  }

  void _listenToRoomMessages() {
    _roomSub?.cancel();
    _roomSub = FirebaseFirestore.instance
        .collection('rooms').doc(_currentRoomId).collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final senderId = data['senderId'] as String? ?? '';
          if (senderId == _myId) continue;
          final rawData = data['data'];
          if (rawData == null) continue;
          final msg = Map<String, dynamic>.from(rawData as Map);
          msg['_senderEndpointId'] = senderId;
          _messagesController.add(msg);
        }
      }
    });
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    await _writeMessage(data);
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    await _writeMessage(data);
    if (data['type'] == 'STATE_UPDATE') {
      await FirebaseFirestore.instance
          .collection('rooms').doc(_currentRoomId).collection('state')
          .doc('current').set(data, SetOptions(merge: true));
    }
  }

  Future<void> _writeMessage(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('rooms').doc(_currentRoomId).collection('messages')
        .add({
      'senderId': _myId,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopAdvertising() async {
    if (_currentRoomId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('lobby').doc(_currentRoomId).delete();
    }
  }

  Future<void> stopDiscovery() async {
    _lobbySub?.cancel();
  }

  Future<void> disconnectAll() async {
    _roomSub?.cancel();
    _lobbySub?.cancel();
    await stopAdvertising();
    _connectedEndpoints.clear();
  }

  void dispose() {
    _lobbySub?.cancel();
    _roomSub?.cancel();
    _devicesController.close();
    _messagesController.close();
    _connectionController.close();
    _disconnectionController.close();
  }
}
