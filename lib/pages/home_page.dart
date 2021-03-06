import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Wave/pages/send_text_page.dart';
import 'package:Wave/pages/send_image_page.dart';
import 'package:Wave/widgets/pulsing_button.dart';
import 'package:chirp_flutter/chirp_flutter.dart';
import 'package:Wave/constants.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Wave/widgets/receive_dialog.dart';
import 'package:Wave/wave_response.dart';
import 'package:Wave/get_wave_request.dart';
import 'package:Wave/utils.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:validators/validators.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Logger log = new Logger('HomePage');
  SharedPreferences prefs;

  bool _listening = false;
  List<String> _waveData = new List<String>();

  @override
  initState() {
    super.initState();
    _requestPermissions();
    _initializeSharedPreferences();
    _initChirp();
    _setChirpCallbacks();
    setWaveData();
  }

  @override
  void dispose() {
    _stopAudioProcessing();
    super.dispose();
  }

  void _initializeSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> _requestPermissions() async {
    PermissionStatus status = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.microphone);
    if (status != PermissionStatus.granted) {
      await PermissionHandler()
          .requestPermissions([PermissionGroup.microphone]);
    }
  }

  Future<void> _initChirp() async {
    try {
      await ChirpSDK.init(Constants.APP_KEY, Constants.APP_SECRET);
      await ChirpSDK.setConfig(Constants.APP_CONFIG);
      await ChirpSDK.start();
    } catch (exception) {
      log.severe(exception.toString());
    }
  }

  Future<void> _stopAudioProcessing() async {
    await ChirpSDK.stop();
  }

  void _setChirpCallbacks() {
    ChirpSDK.onReceived.listen((dataEvent) {
      String payload = new String.fromCharCodes(dataEvent.payload);
      log.info("Received payload: " + payload);
      if (_listening) {
        if (payload.startsWith("wv")) {
          GetWaveRequest(payload).get().then((WaveResponse response) {
            showDialog(
                    context: context,
                    builder: ((BuildContext context) {
                      return ReceiveDialog(response);
                    }))
                .then((_) => setWaveData());
          });
        } else {
          WaveResponse response = WaveResponse(null, payload, null, null);
          showDialog(
                  context: context,
                  builder: ((BuildContext context) {
                    return ReceiveDialog(response);
                  }))
              .then((_) => setWaveData());
        }
      }
    });

    ChirpSDK.onReceiving.listen((dataEvent) {
      log.info("Receiving payload");
    });
  }

  void setWaveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.getStringList("waves") != null) {
        _waveData = prefs.getStringList("waves");
      }
    });
  }

  void _startListening(BuildContext context) {
    Utils.showSnackBar(context, "Started listening for Waves");
    setState(() {
      _listening = true;
    });
  }

  Widget _appBar() {
    return AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: Icon(Icons.text_fields),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SendTextPage(title: 'Send Text Wave')),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.image),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      SendImagePage(title: 'Send Image Wave')),
            );
          },
        ),
      ],
    );
  }

  Widget _body() {
    return Builder(
      builder: (BuildContext context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_listeningWidget(context)],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 40, left: 20, right: 20, bottom: 40),
                child: Container(
                  height: 380,
                  decoration: new BoxDecoration(
                      color: Colors.white,
                      //new Color.fromRGBO(255, 0, 0, 0.0),
                      borderRadius: new BorderRadius.all(Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFbfbfbf),
                          blurRadius: 20,
                          // has the effect of softening the shadow
                        )
                      ]),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text("Recent Waves",
                            style: TextStyle(fontSize: 20)),
                      ),
                      Expanded(
                        child: Padding(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, bottom: 8),
                            child: ListView.builder(
                              itemCount: _waveData.length,
                              itemBuilder: (context, position) {
                                return _historyWidget(
                                    _waveData[_waveData.length - 1 - position]);
                              },
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _listeningWidget(BuildContext context) {
    if (_listening) {
      return Column(
        children: [
          SpinKitWave(
            color: Color(0xFFf29891),
            size: 100.0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: RaisedButton(
              color: Color(0xFFfa7268),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onPressed: () {
                setState(() {
                  _listening = false;
                  Utils.showSnackBar(context, "Stopped listening for Waves");
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Stop Listening',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return PulsingButton(() {
        _startListening(context);
      });
    }
  }

  Widget _historyWidget(String item) {
    if (isURL(item) && item.contains('?')) {
      String after = item.substring(item.lastIndexOf('/') + 1);
      String fileName = after.substring(0, after.lastIndexOf('?'));
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.network(item, height: 100, width: 100),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(fileName, style: TextStyle(fontSize: 16.0)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            item,
            style: TextStyle(fontSize: 16.0),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFe8e8e8),
      appBar: _appBar(),
      body: _body(),
    );
  }
}
