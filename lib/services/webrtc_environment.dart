import '../config.dart';

class WebRtcEnvironment {
  static String get socketBackendUrl {
    const dartDefine = String.fromEnvironment('SOCKET_IO_BACKEND_URL', defaultValue: '');
    if (dartDefine.trim().isNotEmpty) {
      return dartDefine.trim();
    }

    return AppConfig.apiBaseUrl;
  }

  static Map<String, dynamic> get peerConnectionConfig {
    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
    ];

    const turnServer = String.fromEnvironment('TURN_SERVER_URL', defaultValue: '');
    const turnUsername = String.fromEnvironment('TURN_USERNAME', defaultValue: '');
    const turnCredential = String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

    if (turnServer.trim().isNotEmpty) {
      iceServers.add({
        'urls': turnServer.trim(),
        if (turnUsername.trim().isNotEmpty) 'username': turnUsername.trim(),
        if (turnCredential.trim().isNotEmpty) 'credential': turnCredential.trim(),
      });
    }

    return {'iceServers': iceServers};
  }
}