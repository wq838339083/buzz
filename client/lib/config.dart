class AppConfig {
  static const String serverHost = '129.211.29.13';
  static const int wsPort = 7777;
  static const int httpPort = 7778;
  static const bool useTls = false;

  static String get httpBase =>
      '${useTls ? "https" : "http"}://$serverHost:$httpPort';

  static String wsUrl({
    required String token,
    required String deviceId,
    required String deviceName,
  }) {
    final scheme = useTls ? 'wss' : 'ws';
    final encodedName = Uri.encodeQueryComponent(deviceName);
    return '$scheme://$serverHost:$wsPort/?token=$token&device_id=$deviceId&device_name=$encodedName';
  }
}
