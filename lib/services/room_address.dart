/// A room's LAN address as players share it ("192.168.1.50:47474"), and the parser for
/// whatever they paste back (WhatsApp text, "IP: 192.168.1.50 : 47474", just the IP...).
class RoomAddress {
  /// Port the host tries first, so most of the time sharing the IP is enough.
  static const int defaultPort = 47474;

  final String host;
  final int port;
  const RoomAddress(this.host, this.port);

  @override
  String toString() => '$host:$port';

  static final _ipv4 = RegExp(r'\b((?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3})\b');

  /// Finds the first IPv4 address in [text] and the port right after it
  /// (":47474", " : 47474" or " 47474"). Without a port, [defaultPort].
  static RoomAddress? parse(String text) {
    final m = _ipv4.firstMatch(text);
    if (m == null) return null;
    final rest = text.substring(m.end);
    final portMatch = RegExp(r'^\s*[:\s]\s*(\d{2,5})\b').firstMatch(rest);
    final port = portMatch == null ? defaultPort : int.parse(portMatch.group(1)!);
    if (port <= 0 || port > 65535) return null;
    return RoomAddress(m.group(1)!, port);
  }
}
