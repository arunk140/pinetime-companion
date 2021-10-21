import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:http/http.dart' as http;
import 'package:pinetime/ble_actions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PineTime Companion',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        brightness: Brightness.dark,
        canvasColor: const Color.fromRGBO(14, 14, 14, 1.0),
        textTheme: const TextTheme(
          bodyText1: TextStyle(
            color: Color.fromRGBO(91, 91, 91, 1.0),
            fontSize: 20.0
          ),
          bodyText2: TextStyle(
            color: Color.fromRGBO(91, 91, 91, 1.0),
            fontSize: 14.0
          ),
          subtitle1: TextStyle(
            color: Colors.white,
            fontSize: 14.0
          ),
        ),
      ),
      home: const MyHomePage(title: 'PineTime'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
    required this.title
  }) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String currentTime = '';    
  String currentDate = '';
  String currentTimePeriod = '';
  String connState = '';
  String battLevel = '-';
  String latestFirmware = '...';
  String currentFirmware = '...';
  String latestFirmwareUrl = 'https://github.com/InfiniTimeOrg/InfiniTime/releases/latest';
  bool finding = false;
  bool connected = false;
  late BluetoothDevice connectedDevice;
  late List<BluetoothService> services;
  String guidPost = '-0000-1000-8000-00805f9b34fb';

  @override
  void initState() {
    Timer.periodic(const Duration(seconds: 1), (Timer t) => getCurrentTime());
    super.initState();
  }
  
  onStartSearch() {
    setState(() {
      connState = 'Searching...';
      finding = true;
      scanAndConnect('InfiniTime');
    });
  }

  onLatestFirmwareFetch(val) {
    setState(() {
      latestFirmware = val;
    });
  }

  setBatteryLevel(val) {
    setState(() {
      battLevel = "$val%";
    });
  }

  onConnected(device) async {
    services = await device.discoverServices();

    setState(() {
      connectedDevice = device;
      connState = 'Connected';
      finding = false;
      connected = true;
    });
  }

  onDisconnect() {
    setState(() {
      connState = 'Disconnected';
      finding = false;
      connected = false;
    });
  }

  TextStyle getTextStyle(fontSize) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize
    );
  }

  @override
  Widget build(BuildContext context) {
    // getCurrentTime();
    readTimeByteArray();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: ElevatedButton(
                child: const Text('Disconnect'),
                onPressed: () {
                  disconnectDevice();
                },
              ),
            ),
            
            (connected) ? BLETimeSyncButton
              (device: connectedDevice, services: services): Text(widget.title,
                  style: Theme.of(context).textTheme.bodyText1),
            Stack(
              alignment: Alignment.center,
              children:[
                ColorFiltered(
                  colorFilter: (false) ? const ColorFilter.mode(Colors.white, BlendMode.srcATop): const ColorFilter.mode(Colors.transparent, BlendMode.color),
                  child: Image.asset('assets/frameBlank.png', height: 400),
                ),
                !(finding || connected) ? getConnectButtonRichText() : Container(),
                finding ? const CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color.fromRGBO(91, 91, 91, 1.0)
                ):
                connected ? Container(
                  height: 150,
                  width: 150,
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(45, 45, 45, 1.0),
                    borderRadius: BorderRadius.circular(20.0)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(battLevel, style: getTextStyle(14.0))
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 15.0, 0, 0),
                          child: Text(currentTimePeriod, style: getTextStyle(14.0)),
                        )
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(currentTime, style: getTextStyle(50.0))
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Text(currentDate, style: getTextStyle(14.0))
                      ),
                    ],
                  ),
                ): Container(),
                
              ]

            ),
            (!connected) ? Text(connState, style: Theme.of(context).textTheme.bodyText2) : Container(),
            // firmwareRichText(),
            (connected) ? BLEButtonBar(device: connectedDevice, services: services) : Container()
          ]
        ),
      ),
    );
  }

  void scanAndConnect(deviceName) {
    FlutterBlue.instance.startScan(
      withServices: [
        Guid("00001530-1212-efde-1523-785feabcd123")
      ],
      timeout: const Duration(seconds: 10)
    );
    FlutterBlue.instance.scanResults.listen((results) {
      if (results.length == 1) {
        FlutterBlue.instance.stopScan();
        var device = results[0].device;
        device.connect();
        device.state.listen((state) {
          if (state == BluetoothDeviceState.connected) {
            onConnected(device);
          }
        });
      } else {
        for (ScanResult r in results) {
          if (r.device.name == deviceName) {
            r.device.connect();
            r.device.state.listen((state) {
              if (state == BluetoothDeviceState.connected) {
                onConnected(r.device);
              }
            });
            FlutterBlue.instance.stopScan();
          }
        }
      }

    });
    FlutterBlue.instance.stopScan();
  }

  void updateBatteryLevel(device) {
    var batteryServiceGuid = Guid('0000180f'+guidPost);
    var batteryCharGuid = Guid('00002a19'+guidPost);
    List<Guid> charGuids = [batteryCharGuid];
    interactWithDeviceService(device, batteryServiceGuid, charGuids, {})
      .then((value) => {setBatteryLevel(value[batteryCharGuid])});
  }

  void updateCurrentFirmware(device) {
    var serviceGuid = Guid('0000180a'+guidPost);
    var modelnoGuid = Guid('00002a24'+guidPost);
    var serialnoGuid = Guid('00002a25'+guidPost);
    var firmwareGuid = Guid('00002a26'+guidPost);
    var hardwareGuid = Guid('00002a27'+guidPost);
    var softwareGuid = Guid('00002a28'+guidPost);
    var manufactGuid = Guid('00002a29'+guidPost);
    List<Guid> charGuids = [firmwareGuid, hardwareGuid, softwareGuid, serialnoGuid, modelnoGuid, manufactGuid];
    interactWithDeviceService(device, serviceGuid, charGuids, {})
      .then((value) => {
        print(value.toString())
        // setState(() {
        //   currentFirmware = value[firmwareGuid].toString();
        // })
      });
  }

  Future<Map<Guid, List<int>>> interactWithDeviceService(device, serviceGuid, List<Guid> readCharGuids, Map<Guid, List<int>> writeCharGuids) async{
    Map<Guid, Future<List<int>>> futureResults = {};
    Map<Guid, List<int>> results = {};
    services.forEach((service) {
        if (service.uuid == serviceGuid) {
          var characteristics = service.characteristics;
          for(BluetoothCharacteristic c in characteristics) {
            if(readCharGuids.contains(c.uuid)) {
              readCharacteristic(c, (val) => {
                futureResults.putIfAbsent(c.uuid, () => val)
              });
            }
            if (writeCharGuids.keys.contains(c.uuid)) {
              // futureResults.putIfAbsent(c.uuid, () => readCharacteristic(c));
            }
          }
        }
    });
    futureResults.forEach((key, value) { 
      value.then((value) => {
        results.putIfAbsent(key, () => value)
      });
    });
    return results;
  }

  void readCharacteristic(BluetoothCharacteristic c, Function cb) async {
    c.read().then((value) => cb(value));
  }
  Future<String> writeCharacteristic(BluetoothCharacteristic c, Object data) async {
    var value = await c.read();
    Future<String> result = Future.value(value.toString());
    return result;
  }

  void disconnectDevice() {
    FlutterBlue.instance.connectedDevices
        .then((List<BluetoothDevice> devices) {
      for (BluetoothDevice d in devices) {
        d.disconnect();
        onDisconnect();
      }
    });
  }

  void checkForUpdates() {
    var url = 'https://api.github.com/repos/InfiniTimeOrg/InfiniTime/releases';
    Uri uri = Uri.parse(url);
    onLatestFirmwareFetch('...');
    http.get(uri).then((response) {
      var jsonResponse = jsonDecode(response.body);
      var latestVersion = jsonResponse[0]['tag_name'];
      onLatestFirmwareFetch(latestVersion);
    });
  }

  void getCurrentTime() {
    var now = DateTime.now();
    var date = DateFormat('EEE MMM d yyyy').format(now);
    var ampm = DateFormat('a').format(now);
    var time = DateFormat('h:mm').format(now);
    setState(() {
      currentTime = time;
      currentDate = date.toString().toUpperCase();
      currentTimePeriod = ampm.toString().toUpperCase();
    });
  }

  RichText getConnectButtonRichText() {
    return RichText(
      text: TextSpan(
          style: Theme.of(context).textTheme.bodyText2,
          text: 'Connect',
          recognizer: TapGestureRecognizer()..onTap = () => onStartSearch()),
    );
  }

  RichText firmwareRichText() {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyText2,
        children: <TextSpan>[
          const TextSpan(text: 'Current Firmware - '),
          TextSpan(text: currentFirmware),
          const TextSpan(text: '\n'),
          const TextSpan(
              text:'Latest Firmware - ' ),
          TextSpan(
              text: latestFirmware,
              recognizer: TapGestureRecognizer()..onTap = () => checkForUpdates()),
        ],
      ),
    );
  }

  void readTimeByteArray () {
    // E5-07-0A-0F-16-1A-30-00-00
    Uint8List input = Uint8List.fromList([
      0xe5,
      0x07,
      0x0a,
      0x0f,
      0x16,
      0x1d,
      0x0e,
      0x00,
      0x00
    ]);
    var bytes = input.buffer.asByteData();
    var year = bytes.getUint16(0, Endian.little);
    var month = bytes.getUint8(2);
    var day = bytes.getUint8(3);
    var hour = bytes.getUint8(4);
    var min = bytes.getUint8(5);
    var sec = bytes.getUint8(6);
    var dateStr = year.toString()+'-'+month.toString()+'-'+day.toString()+' '+hour.toString()+':'+min.toString()+':'+sec.toString();
    print(dateStr);
  }
}

