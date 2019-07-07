# homie_dart_on_mqtt_client

This library uses the [mqtt_client](https://pub.dev/packages/mqtt_client) package to implement a BrokerConnection for [homie_dart](https://pub.dev/packages/homie_dart).
Most users want to use this packge instead of homie_dart, since it comes with all necessary mqtt logic.
Users only need a dependency on this package, since it exports the homie_dart api.
The BrokerConnection class added by this packages is [MqttBrokerConnection](https://pub.dev/documentation/homie_dart_on_mqtt_client/latest/homie_dart_on_mqtt_client/MqttBrokerConnection-class.html)