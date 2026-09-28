/// Change this to your real backend host before building.
/// Use https in production — the Sanctum token is a bearer credential and
/// must not travel over plain HTTP.
class AppConfig {
  static const String apiBaseUrl = 'https://lbpaylinker.com/api';
}
