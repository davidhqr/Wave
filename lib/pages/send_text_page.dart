import 'dart:async';
import 'dart:typed_data';

import 'package:Wave/constants.dart';
import 'package:Wave/send_wave_request.dart';
import 'package:Wave/sending_state.dart';
import 'package:Wave/utils.dart';
import 'package:chirp_flutter/chirp_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:logging/logging.dart';

class SendTextPage extends StatefulWidget {
  SendTextPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _SendTextPageState createState() {
    return _SendTextPageState();
  }
}

class _SendTextPageState extends State<SendTextPage> {
  final Logger log = new Logger('WaveRequest');
  final TextEditingController textController = new TextEditingController();

  bool _offline = false;
  bool _sending = false;

  @override
  initState() {
    super.initState();
    _initChirp();
    _configChirp();
    _setChirpCallbacks();
    _startAudioProcessing();
  }

  @override
  void dispose() {
    log.info("STATE DISPOSE");
    _stopAudioProcessing();
    super.dispose();
  }

  Future<void> _initChirp() async {
    var state = await ChirpSDK.state;
    if (state != ChirpState.running)
      await ChirpSDK.init(Constants.APP_KEY, Constants.APP_SECRET);
  }

  Future<void> _configChirp() async {
    var state = await ChirpSDK.state;
    if (state != ChirpState.running)
      await ChirpSDK.setConfig(Constants.APP_CONFIG);
  }

  Future<void> _startAudioProcessing() async {
    var state = await ChirpSDK.state;
    if (state != ChirpState.running) await ChirpSDK.start();
  }

  Future<void> _stopAudioProcessing() async {
    await ChirpSDK.stop();
  }

  Future<void> _sendChirp(Uint8List data) async {
    ChirpSDK.send(data);
  }

  Future<void> _setChirpCallbacks() async {
    ChirpSDK.onSent.listen((sent) {
      SendingState().sending = false;
      setState(() {
        _sending = false;
      });
    });
  }

  void _onSuccess(BuildContext context, Uint8List payload) {
    _sendChirp(payload);
    Utils.showSnackBar(context, "Wave sent successfully");
    log.info("Successfully sent text wave");
  }

  void _sendText(BuildContext context) {
    String text = textController.text;

    if (text == null || text.length == 0) {
      Utils.showSnackBar(context, "Enter some text first");
      log.warning("No text entered");
      return;
    }

    if (_offline && text.length > 32) {
      Utils.showSnackBar(
          context, "Error sending offline text Wave - text too long");
      log.warning(
          "Error saving offline wave request with text > 32 characters");
      return;
    }

    if (!_offline && text.length > 1000) {
      Utils.showSnackBar(
          context, "Error sending online text Wave - text too long");
      log.warning(
          "Error saving online wave request with text > 1000 characters");
      return;
    }

    if (SendingState().sending) {
      Utils.showSnackBar(context, "Another Wave is already being sent");
      log.info("Another wave is already being sent");
      return;
    }

    SendingState().sending = true;
    SendingState().time = DateTime.now();

    setState(() {
      _sending = true;
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (SendingState().sending &&
          DateTime.now()
              .subtract(Duration(seconds: 9))
              .isAfter(SendingState().time)) {
        SendingState().sending = false;
        setState(() {
          _sending = false;
        });
        Utils.showSnackBar(context,
            "Sending Wave timed out. Check your internet connection and try again.");
        log.warning("Sending wave timed out");
      }
    });

    String code = Utils.generateCode();
    SendWaveRequest request =
        new SendWaveRequest(context, code, text, null, _offline, _onSuccess);
    request.getPayload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Switch(
            value: _offline,
            onChanged: (bool isOn) {
              setState(() {
                _offline = isOn;
              });
            },
            activeColor: Colors.greenAccent,
            inactiveTrackColor: Colors.grey,
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: TextField(
                  controller: textController,
                  maxLength: _offline ? 32 : 1000,
                  maxLines: _offline ? 2 : 10,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
              _sending
                  ? SpinKitWave(
                      color: Color(0xFFfa7268),
                    )
                  : RaisedButton(
                      color: Color(0xFFfa7268),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onPressed: () {
                        _sendText(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _offline
                              ? 'Send Offline Text Wave'
                              : 'Send Text Wave',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
