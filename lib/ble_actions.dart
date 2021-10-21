import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:pinetime/ble_consts.dart';

class BLEButtonBar extends StatelessWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  const BLEButtonBar({
    required this.device, required this.services,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
         BLEButton(
          icon: MaterialCommunityIcons.cellphone_arrow_down,
          tooltip: "Check for Updates",
          iconColor: const Color.fromRGBO(255, 248, 81, 1.0),
          onTap: (value) {
              if (value != null) {
                String op = const Utf8Decoder(allowMalformed: true).convert(value);
                print("Current Firmware Version - "+op);
              }
            },
          device: device,
          services: services,
          service: Guid('0000180a' + guidPostFix),
          characteristic: Guid('00002a26' + guidPostFix),
          actionType: BLEActionType.readData
        ),
        // BLEButton(
        //   icon: MaterialCommunityIcons.run,
        //   tooltip: "Sync Step Counter",
        //   iconColor: const Color.fromRGBO(255, 255, 255, 1.0),
        //   onTap: () => {},
        //   device: device,
        //   services: services,
        //   service: Guid('0000180f' + guidPostFix),
        //   characteristic: Guid('0000180f' + guidPostFix),
        //   actionType: BLEActionType.readData
        // ),
        BLEButton(
          icon: MaterialCommunityIcons.heart_pulse,
          tooltip: "Fetch Heart Rate Data",
          iconColor: const Color.fromRGBO(255, 70, 70, 1.0),
          onTap: () => {},
          device: device,
          services: services,
          service: Guid('0000180f' + guidPostFix),
          characteristic: Guid('0000180f' + guidPostFix),
          actionType: BLEActionType.streamData,
        ),
        BLEButton(
          icon: MaterialCommunityIcons.battery_60_bluetooth,
          tooltip: "Fetch Battery Level",
          iconColor: const Color.fromRGBO(68, 242, 85, 1.0),
          onTap: (value) {
            if (value != null) {
              print("Current Battery Level - " + value[0].toString() + "%");
            }
          },
          device: device,
          services: services,
          service: Guid('0000180f' + guidPostFix),
          characteristic: Guid('00002a19' + guidPostFix),
          actionType: BLEActionType.readData,
        ),
      ],
    );
  }
}
class BLETimeSyncButton extends StatelessWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  const BLETimeSyncButton({
    required this.device, required this.services,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BLEButton(
      tooltip: "Sync Time",
      icon: MaterialCommunityIcons.sync,
      iconColor: const Color.fromRGBO(2, 164, 255, 1.0),
      onTap: () => {},
      device: device,
      services: services,
      service: Guid('0000180f' + guidPostFix),
      characteristic: Guid('0000180f' + guidPostFix),
      actionType: BLEActionType.writeData,
      newValue: const [],
    );
  }
}

class BLEButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final BLEActionType actionType;
  final BluetoothDevice device;
  final List<BluetoothService> services;
  final Guid service;
  final Guid characteristic;

  final Function onTap;
  final List<int>? newValue;
  final Color? iconColor;

  const BLEButton({
    required this.icon,
    required this.tooltip,
    required this.actionType,
    required this.device,
    required this.services,
    required this.service,
    required this.characteristic,
    required this.onTap,
    Key? key, 
    this.iconColor,
    this.newValue,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        accessServiceCharacteristic(device, services, service, characteristic, actionType, onTap, newValue);
      },
      icon: Icon(icon), 
      color: iconColor,
      tooltip: tooltip,
      iconSize: 30.0,
    );
  }
}

void accessServiceCharacteristic(
  BluetoothDevice deivce, 
  List<BluetoothService> services, 
  Guid service, Guid char, 
  BLEActionType actionType,
  Function cb,
  List<int>? newVal
) {
    services.forEach((s) {
      if (s.uuid == service) {
        List<BluetoothCharacteristic> c = s.characteristics;
        for (BluetoothCharacteristic eachC in c) {
          if (char == eachC.uuid) {
            switch (actionType) {
              case BLEActionType.readData:
                readBLEChar(eachC, cb);
                break;
              case BLEActionType.writeData:
                writeBLEChar(eachC, newVal!, cb);
                break;
              case BLEActionType.streamData:
                subscribeBLEChar(eachC, cb);
                break;
              default:
                cb([]);
            }
          }
        }
      }
    });
}

void readBLEChar(BluetoothCharacteristic c, Function cb) {
  c.read().then((value) {
    Uint8List val = Uint8List.fromList(value);
    cb(val);
  });
}

void writeBLEChar(BluetoothCharacteristic c, List<int> newVal, Function cb) {
  c.write(newVal);
  cb(true);
}

void subscribeBLEChar(BluetoothCharacteristic c, Function cb) {
  c.setNotifyValue(true);
  c.value.listen((value) {
    cb(value);
  });
}
