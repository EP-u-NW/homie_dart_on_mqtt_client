///An implementation for a [BrokerConnection] based on mqtt_client for homie_dart.
library homie_dart_on_mqtt_client;

import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

import 'package:typed_data/typed_buffers.dart';
import 'package:meta/meta.dart';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:homie_dart/homie_dart.dart';

export 'package:homie_dart/homie_dart.dart';

class MqttBrokerConnection implements BrokerConnection {
  static const String _defaultClientIdentifier = 'homie_dart_on_mqtt_client';

  final MqttClient _client;
  final Map<int, Completer<Null>> _publishing;
  final Map<String, Completer<Stream<Uint8List>>> _pendingSubscriptions;
  final Map<String, StreamController<Uint8List>> _subscriptions;
  final String _password, _username;

  bool _connectAlreadyCalled;

  MqttBrokerConnection(
      {@required String server,
      @required int port,
      String clientIdentifier,
      String username,
      String password})
      : assert(server != null),
        assert(port != null),
        assert((username == null && password == null) ||
            (username != null && password != null)),
        this._client = new MqttClient.withPort(
            server, clientIdentifier ?? _defaultClientIdentifier, port),
        this._publishing = new Map<int, Completer<Null>>(),
        this._pendingSubscriptions =
            new Map<String, Completer<Stream<Uint8List>>>(),
        this._subscriptions = new Map<String, StreamController<Uint8List>>(),
        this._password = password,
        this._username = username,
        this._connectAlreadyCalled = false;

  @override
  Future<Null> connect(String lastWillTopic, Uint8List lastWillData,
      bool lastWillRetained, int lastWillQos) async {
    if (_connectAlreadyCalled) {
      throw new StateError('It is not allowed to call connect a second time on the same instance.');
    } else {
      _connectAlreadyCalled=true;
      MqttConnectMessage connMess = new MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier)
          .withWillTopic(lastWillTopic)
          .withWillMessage(utf8.decode(lastWillData))
          .withWillQos(MqttUtilities.getQosLevel(lastWillQos));
      if (lastWillRetained) {
        connMess.withWillRetain();
      }
      _client.connectionMessage = connMess;
      MqttClientConnectionStatus status =
          await _client.connect(_username, _password);
      assert(status.state == MqttConnectionState.connected);

      _client.published.listen((MqttPublishMessage message) {
        _publishing
            .remove(message.variableHeader.messageIdentifier)
            ?.complete(null);
      });

      _client.onSubscribed = (String topic) => _onSubscription(topic, true);
      _client.onSubscribeFail = (String topic) => _onSubscription(topic, false);

      _client.updates
          .expand((List<MqttReceivedMessage<MqttMessage>> messages) => messages)
          .listen((MqttReceivedMessage<MqttMessage> message) =>
              _onMessage(message.topic, message.payload as MqttPublishMessage));
    }
  }

  void _onMessage(String topic, MqttPublishMessage message) {
    StreamController<Uint8List> controller = _subscriptions[topic];
    Uint8List event = new Uint8List.view(message.payload.message.buffer);
    controller?.add(event);
  }

  void _onSubscription(String topic, bool success) {
    Completer<Stream<Uint8List>> completer =
        _pendingSubscriptions.remove(topic);
    if (success) {
      StreamController<Uint8List> controller =
          new StreamController<Uint8List>();
      _subscriptions[topic] = controller;
      completer.complete(controller.stream);
    } else {
      completer.completeError(
          new Exception('Could not subscribe to topic \'$topic\''));
    }
  }

  @override
  Future<Null> disconnect() {
    assert(_client.onDisconnected == null);
    if (_client.connectionStatus.state == MqttConnectionState.connected) {
      _subscriptions.values.forEach(
          (StreamController<Uint8List> controller) => controller.close());
      _publishing.values.forEach((Completer<Null> completer) =>
          completer.completeError(new DisconnectingException()));
      _pendingSubscriptions.values.forEach(
          (Completer<Stream<Uint8List>> completer) =>
              completer.completeError(new DisconnectingException()));
      Completer<Null> completer = new Completer<Null>();
      _client.onDisconnected = () {
        completer.complete(null);
      };
      _client.disconnect();
      return completer.future;
    } else {
      return new Future.value(null);
    }
  }

  @override
  Future<Null> publish(String topic, Uint8List data, bool retained, int qos) {
    Uint8Buffer buffer = new Uint8Buffer();
    buffer.addAll(data);
    int id = _client.publishMessage(
        topic, MqttUtilities.getQosLevel(qos), buffer,
        retain: retained);
    if (qos == 2) {
      Completer<Null> c = new Completer<Null>();
      _publishing[id] = c;
      return c.future;
    } else {
      return new Future.value(null);
    }
  }

  @override
  Future<Stream<Uint8List>> subscribe(String topic, int qos) {
    assert(!_pendingSubscriptions.containsKey(topic));
    assert(!_subscriptions.containsKey(topic));
    Completer<Stream<Uint8List>> completer = new Completer<Stream<Uint8List>>();
    _pendingSubscriptions[topic] = completer;
    _client.subscribe(topic, MqttUtilities.getQosLevel(qos));
    return completer.future;
  }
}
