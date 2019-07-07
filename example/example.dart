import 'package:homie_dart_on_mqtt_client/homie_dart_on_mqtt_client.dart';
import '../../homie_dart/example/example.dart';


Future<Null> main() async {
  BrokerConnection con=new MqttBrokerConnection(server: 'hpserver',port: 1883);
  await test(con);
}