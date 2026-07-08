/// Result of a single OSINT platform probe against a username variation.
class ProfileHit {
  final String platform;
  final String username;
  final String url;
  final bool found;
  final int statusCode;

  ProfileHit({
    required this.platform,
    required this.username,
    required this.url,
    required this.found,
    required this.statusCode,
  });
}
