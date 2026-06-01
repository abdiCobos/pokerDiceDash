import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoveredDevice {
  final String endpointId;
  final String endpointName;
  DiscoveredDevice({required this.endpointId, required this.endpointName});
}

abstract class TransportService {
  Stream<DiscoveredDevice> get onDeviceFound;
  Stream<Map<String, dynamic>> get onMessageReceived;
  Stream<String> get onConnected;
  Stream<String> get onDisconnected;
  int get connectedEndpointCount;

  Future<void> startAdvertising(String deviceName);
  Future<void> startDiscovery(String deviceName);
  Future<void> connectToDevice(String endpointId);
  Future<void> sendMessage(String endpointId, Map<String, dynamic> data);
  Future<void> broadcastMessage(Map<String, dynamic> data);
  Future<void> stopAdvertising();
  Future<void> stopDiscovery();
  Future<void> disconnectAll();
  void dispose();
}
