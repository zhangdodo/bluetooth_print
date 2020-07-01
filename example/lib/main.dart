
import 'dart:async';
import 'dart:convert';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  GlobalKey _globalKey = new GlobalKey();

  Future<Uint8List> _capturePng() async {
    try {
      print('inside');
      RenderRepaintBoundary boundary =
      _globalKey.currentContext.findRenderObject();
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();
      String bs64 = base64Encode(pngBytes);
      print(pngBytes);
      print(bs64);
      return pngBytes;
    } catch (e) {
      print(e);
    }
  }

  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

  bool _connected = false;
  BluetoothDevice _device;
  String tips = 'no device connect';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initBluetooth());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initBluetooth() async {
    bluetoothPrint.startScan(timeout: Duration(seconds: 4));

    bool isConnected=await bluetoothPrint.isConnected;

    bluetoothPrint.state.listen((state) {
      print('cur device status: $state');

      switch (state) {
        case BluetoothPrint.CONNECTED:
          setState(() {
            _connected = true;
            tips = 'connect success';
          });
          break;
        case BluetoothPrint.DISCONNECTED:
          setState(() {
            _connected = false;
            tips = 'disconnect success';
          });
          break;
        default:
          break;
      }
    });

    if (!mounted) return;

    if(isConnected) {
      setState(() {
        _connected=true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('BluetoothPrint example app'),
          ),
          body: RefreshIndicator(
            onRefresh: () =>
                bluetoothPrint.startScan(timeout: Duration(seconds: 4)),
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        child: Text(tips),
                      ),
                    ],
                  ),
                  Divider(),
                  StreamBuilder<List<BluetoothDevice>>(
                    stream: bluetoothPrint.scanResults,
                    initialData: [],
                    builder: (c, snapshot) => Column(
                      children: snapshot.data.map((d) => ListTile(
                        title: Text(d.name??''),
                        subtitle: Text(d.address),
                        onTap: () async {
                          setState(() {
                            _device = d;
                          });
                        },
                        trailing: _device!=null && _device.address == d.address?Icon(
                          Icons.check,
                          color: Colors.green,
                        ):null,
                      )).toList(),
                    ),
                  ),
                  Divider(),
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 5, 20, 10),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            OutlineButton(
                              child: Text('connect'),
                              onPressed:  _connected?null:() async {
                                if(_device!=null && _device.address !=null){
                                  await bluetoothPrint.connect(_device);
                                }else{
                                  setState(() {
                                    tips = 'please select device';
                                  });
                                  print('please select device');
                                }
                              },
                            ),
                            SizedBox(width: 10.0),
                            OutlineButton(
                              child: Text('disconnect'),
                              onPressed:  _connected?() async {
                                await bluetoothPrint.disconnect();
                              }:null,
                            ),
                          ],
                        ),
                        OutlineButton(
                          child: Text('print receipt(esc)'),
                          onPressed:  _connected?() async {
                            Map<String, dynamic> config = Map();
                            List<LineText> list = List();
                            list.add(LineText(type: LineText.TYPE_TEXT, content: 'A Title', weight: 1, align: LineText.ALIGN_CENTER,linefeed: 1));
                            list.add(LineText(type: LineText.TYPE_TEXT, content: 'this is conent left', weight: 0, align: LineText.ALIGN_LEFT,linefeed: 1));
                            list.add(LineText(type: LineText.TYPE_TEXT, content: 'this is conent right', align: LineText.ALIGN_RIGHT,linefeed: 1));
                            list.add(LineText(linefeed: 1));
                            list.add(LineText(type: LineText.TYPE_BARCODE, content: 'A12312112', size:10, align: LineText.ALIGN_CENTER, linefeed: 1));
                            list.add(LineText(linefeed: 1));
                            list.add(LineText(type: LineText.TYPE_QRCODE, content: 'qrcode i', size:10, align: LineText.ALIGN_CENTER, linefeed: 1));
                            list.add(LineText(linefeed: 1));

                            ByteData data = await rootBundle.load("assets/images/guide3.png");
                            List<int> imageBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
                            String base64Image = base64Encode(imageBytes);
                            list.add(LineText(type: LineText.TYPE_IMAGE, content: base64Image, align: LineText.ALIGN_CENTER, linefeed: 0,width: 830));

                            await bluetoothPrint.printReceipt(config, list);
                          }:null,
                        ),
                        OutlineButton(
                          child: Text('print label(tsc)'),
                          onPressed:  _connected?() async {
                            Map<String, dynamic> config = Map();
                            config['width'] = 1100; // 标签宽度，单位mm
                            config['height'] = 70; // 标签高度，单位mm
                            config['gap'] = 2; // 标签间隔，单位mm

                            // x、y坐标位置，单位dpi，1mm=8dpi
                            List<LineText> list = List();
                            list.add(LineText(type: LineText.TYPE_TEXT, x:10, y:10, content: 'A Title'));
                            list.add(LineText(type: LineText.TYPE_TEXT, x:10, y:40, content: 'this is content'));
                            list.add(LineText(type: LineText.TYPE_QRCODE, x:10, y:70, content: 'qrcode i\n'));
                            list.add(LineText(type: LineText.TYPE_BARCODE, x:10, y:190, content: 'qrcode i\n'));

                            List<LineText> list1 = List();
                            ByteData data = await rootBundle.load("assets/images/guide3.png");
                            List<int> imageBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
                            String base64Image = base64Encode(imageBytes);
                            list.add(LineText(type: LineText.TYPE_IMAGE, content: base64Image,weight: 1100));
                            await bluetoothPrint.printLabel(config, list);
                          }:null,
                        ),
                        OutlineButton(
                          child: Text('print selftest'),
                          onPressed:  _connected?() async {
                            await bluetoothPrint.printTest();
                          }:null,
                        ),
                        OutlineButton(
                          child: Text('点击'),
                          onPressed: _capturePng
                        )
                      ],
                    ),
                  ),
                  thisgey()
                ],
              ),
            ),
          ),
        floatingActionButton: StreamBuilder<bool>(
          stream: bluetoothPrint.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data) {
              return FloatingActionButton(
                child: Icon(Icons.stop),
                onPressed: () => bluetoothPrint.stopScan(),
                backgroundColor: Colors.red,
              );
            } else {
              return FloatingActionButton(
                  child: Icon(Icons.search),
                  onPressed: () => bluetoothPrint.startScan(timeout: Duration(seconds: 4)));
            }
          },
        ),
      ),
    );
  }

  Widget thisgey(){
    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 10.0),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF)
        ),
        child: Column(
          children: <Widget>[
            Container(
              child: Text(
                "XXXXXX销售单",
                style: TextStyle(
                  fontSize: 20.0
                ),
              ),
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("订单号:44444444444444"),
                Text("时间:22222")
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("客户:XXX"),
                    SizedBox(width: 20,),
                    Text("电话:15505429447")
                  ],
                ),
              ],
            ),
            SizedBox(height: 10,),
            Text("到了最后了--------------------------")
          ],
        ),
      ),
    );
  }
}
