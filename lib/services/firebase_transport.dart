import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'p2p_service.dart';
import 'logger_service.dart';

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
    try {
      await FirebaseFirestore.instance.collection('lobby').doc(_currentRoomId).set({
        'endpointId': _currentRoomId,
        'endpointName': deviceName,
        'createdAt': FieldValue.serverTimestamp(),
        'hostId': _myId,
      });
      dev.log('FirebaseTransport: lobby doc created: $_currentRoomId', name: 'Firebase');
      AppLogger().error('FB_ADVERTISE_OK: room=$_currentRoomId hostId=$_myId');
    } catch (e, s) {
      dev.log('FirebaseTransport: FAILED to create lobby doc: $e', name: 'Firebase');
      AppLogger().error('FB_ADVERTISE_FAIL: room=$_currentRoomId err=$e', s);
    }
    _listenToRoomMessages();
    _connectionController.add(_myId);
  }

  Future<void> startDiscovery(String deviceName) async {
    _lobbySub?.cancel();
    final Set<String> _seenRooms = {};
    FirebaseCrashlytics.instance.log('FB_DISCOVERY_START: myId=$_myId');
    _lobbySub = FirebaseFirestore.instance.collection('lobby').snapshots().listen((snapshot) {
      FirebaseCrashlytics.instance.log('FB_SNAPSHOT: docs=${snapshot.docs.length} changes=${snapshot.docChanges.length}');
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) {
          dev.log('FirebaseTransport: null data in change type=${change.type}', name: 'Firebase');
          continue;
        }
        final endpointId = data['endpointId'] as String? ?? '';
        final hostId = data['hostId'] as String? ?? '';
        dev.log('FirebaseTransport: found doc endpointId=$endpointId hostId=$hostId myId=$_myId type=${change.type}', name: 'Firebase');
        
        if (hostId == _myId) {
          AppLogger().log('FB_DISCOVERY: skipping own room $endpointId (my hostId=$_myId)');
          continue;
        }

        if (change.type == DocumentChangeType.added) {
          if (!_seenRooms.contains(endpointId)) {
            AppLogger().log('FB_ROOM_FOUND: endpointId=$endpointId hostId=$hostId');
            _seenRooms.add(endpointId);
            AppLogger().error('FB_ROOM_DISCOVERED: endpointId=$endpointId name=${data['endpointName']}');
            _devicesController.add(DiscoveredDevice(
              endpointId: endpointId,
              endpointName: data['endpointName'] as String? ?? '',
            ));
          }
        } else if (change.type == DocumentChangeType.removed) {
          _seenRooms.remove(endpointId);
          _disconnectionController.add(endpointId);
        }
      }
    }, onError: (e, s) {
      AppLogger().error('FB_DISCOVERY_ERROR: $e', s);
    });
  }

  Future<void> connectToDevice(String endpointId) async {
    _currentRoomId = endpointId;
    _listenToRoomMessages();
    _connectionController.add(endpointId);

    debugPrint('FB_CONNECT: room=$endpointId myId=$_myId');
    // Send initial connect message so host knows our myId
    await _writeMessage({
      'type': 'FIREBASE_CONNECT',
      'clientId': _myId,
    });
  }

  void _listenToRoomMessages() {
    _roomSub?.cancel();
    if (_currentRoomId.isEmpty) return;

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

          // Check if this is a point-to-point message
          // In Firebase all messages are broadcast (no real point-to-point),
          // so we ignore targetId filtering — everyone in the room gets everything.
          // targetId filtering would break because endpointIds are room-level, not device-level.

          msg['_senderEndpointId'] = senderId;
          _messagesController.add(msg);
        }
      }
    });
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    // In Firebase, we write targetId so the recipient filters by it,
    // but broadcast messages with no targetId go to everyone.
    await _writeMessage(data, targetId: endpointId);
  }

  Future<void> broadcastMessage(Map<String, dynamic> data) async {
    await _writeMessage(data);
    if (data['type'] == 'STATE_UPDATE') {
      await FirebaseFirestore.instance
          .collection('rooms').doc(_currentRoomId).collection('state')
          .doc('current').set(data, SetOptions(merge: true));
    }
  }

  Future<void> _writeMessage(Map<String, dynamic> data, {String? targetId}) async {
    if (_currentRoomId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('rooms').doc(_currentRoomId).collection('messages')
        .add({
      'senderId': _myId,
      if (targetId != null) 'targetId': targetId,
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
