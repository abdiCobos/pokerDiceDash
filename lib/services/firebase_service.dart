import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nearby_connections/nearby_connections.dart';

class DiscoveredDevice {
  final String endpointId;
  final String endpointName;
  DiscoveredDevice({required this.endpointId, required this.endpointName});
}

class FirebaseService {
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
  StreamSubscription? _stateSub;
  StreamSubscription? _playerSub;

  FirebaseService() {
    _myId = _randomId();
  }

  String _randomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> startAdvertising(String deviceName) async {
    _currentRoomId = 'room_${_randomId()}';
    _connectedEndpoints.add(_myId);
    final doc = FirebaseFirestore.instance.collection('lobby').doc(_currentRoomId);
    await doc.set({
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
    _sendJoinRequest();
  }

  void _listenToRoomMessages() {
    _roomSub = FirebaseFirestore.instance
        .collection('rooms').doc(_currentRoomId).collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final senderId = data['senderId'] as String? ?? '';
          if (senderId == _myId) continue;
          final msg = Map<String, dynamic>.from(data['data'] as Map);
          msg['_senderEndpointId'] = senderId;
          _messagesController.add(msg);
        }
      }
    });
  }

  void _sendJoinRequest() {
    final msg = {
      'type': 'JOIN_REQUEST',
      'password': '',
      'playerName': 'Jugador',
    };
    _writeMessage(msg);
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

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    await _writeMessage(data);
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    await _writeMessage(data);
    // Also update state doc for STATE_UPDATE
    if (data['type'] == 'STATE_UPDATE') {
      await FirebaseFirestore.instance
          .collection('rooms').doc(_currentRoomId).collection('state')
          .doc('current').set(data, SetOptions(merge: true));
    }
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
    _stateSub?.cancel();
    _playerSub?.cancel();
    await stopAdvertising();
    _connectedEndpoints.clear();
  }

  void dispose() {
    disconnectAll();
    _devicesController.close();
    _messagesController.close();
    _connectionController.close();
    _disconnectionController.close();
  }
}
