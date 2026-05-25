import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_client.dart';
import '../services/call_service.dart';

class InCallScreen extends StatefulWidget {
  final String callId;
  final bool isInitiator;

  const InCallScreen({Key? key, required this.callId, this.isInitiator = false}) : super(key: key);

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final WebRtcClient _client = WebRtcClient();
  bool _muted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.isInitiator) {
      await _client.initAsCaller(widget.callId);
    } else {
      await _client.initAsAnswerer(widget.callId);
    }

    _client.onLocalStream.listen((s) {
      setState(() {});
    });
    _client.onRemoteStream.listen((s) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Widget _videoView(MediaStream? stream, {bool mirror = false}) {
    if (stream == null) return const SizedBox.shrink();
    final renderer = RTCVideoRenderer();
    renderer.initialize().then((_) {
      renderer.srcObject = stream;
    });
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: RTCVideoView(renderer, mirror: mirror),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('In Call')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(child: _videoView(_client.remoteStream)),
                Positioned(
                  right: 12,
                  bottom: 12,
                  width: 160,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
                    child: _videoView(_client.localStream, mirror: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                  onPressed: () async {
                    setState(() => _muted = !_muted);
                    await _client.mute(_muted);
                  },
                ),
                IconButton(
                  icon: Icon(_cameraOff ? Icons.videocam_off : Icons.videocam),
                  onPressed: () async {
                    setState(() => _cameraOff = !_cameraOff);
                    await _client.toggleCamera();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_end),
                  label: const Text('End'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await CallService().endCall(widget.callId);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
