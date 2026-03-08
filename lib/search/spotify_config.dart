/// Configuration for the Spotify Web API client credentials flow.
class SpotifyConfig {
  const SpotifyConfig({
    this.clientId = '',
    this.clientSecret = '',
  });

  /// Spotify application client ID.
  ///
  /// Obtain from https://developer.spotify.com/dashboard. Can be set
  /// in app settings; leave empty to disable the Spotify source.
  final String clientId;

  /// Spotify application client secret.
  ///
  /// Obtain from https://developer.spotify.com/dashboard. Can be set
  /// in app settings; leave empty to disable the Spotify source.
  final String clientSecret;

  /// Returns `true` when both [clientId] and [clientSecret] are non-empty.
  bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
