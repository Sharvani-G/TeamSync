class WebRtcEnvironment {
  static String get socketBackendUrl {
    const dartDefine = String.fromEnvironment('SOCKET_IO_BACKEND_URL', defaultValue: '');
    if (dartDefine.trim().isNotEmpty) {
      return dartDefine.trim();
    }

    return 'http://127.0.0.1:8080';
  }

  static Map<String, dynamic> get peerConnectionConfig {
    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
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