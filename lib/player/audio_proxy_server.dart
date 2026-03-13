import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Local HTTP proxy that forwards requests to YouTube audio stream URLs with
/// the headers required to avoid HTTP 403 from YouTube's CDN.
///
/// ExoPlayer (used by just_audio) does not reliably forward custom headers
/// when set via [AudioSource.uri]. Running a localhost proxy lets us inject
/// the correct headers at the TCP level before the request reaches YouTube.
///
/// ## Usage
///
/// ```dart
/// final proxy = AudioProxyServer();
/// await proxy.start();
/// final url = proxy.proxyUrl('https://rr1.googlevideo.com/...');
/// await player.setUrl(url); // ExoPlayer talks to localhost, not YouTube
/// ```
///
/// Singleton — one server per app lifetime. Use [AudioProxyServer.forTest]
/// in unit tests to get an isolated instance.
class AudioProxyServer {
  static final AudioProxyServer _instance = AudioProxyServer._internal();

  AudioProxyServer._internal();

  /// Returns the singleton proxy server.
  factory AudioProxyServer() => _instance;

  /// Creates a fresh, non-singleton instance for use in tests.
  @visibleForTesting
  AudioProxyServer.forTest();

  HttpServer? _server;

  /// The port the server is currently listening on, or `null` if not started.
  int? get port => _server?.port;

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _referer = 'https://www.youtube.com/';
  static const _origin = 'https://www.youtube.com';

  /// Start the proxy. Does nothing if already running.
  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest, onError: (_) {});
  }

  /// Convert [targetUrl] into a proxy URL that routes through this server.
  ///
  /// The server must be started before calling this method.
  String proxyUrl(String targetUrl) {
    assert(_server != null, 'AudioProxyServer must be started before use');
    return 'http://localhost:${_server!.port}'
        '/proxy?url=${Uri.encodeComponent(targetUrl)}';
  }

  /// Stop the server and release the port.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ---------------------------------------------------------------------------
  // Request handling
  // ---------------------------------------------------------------------------

  Future<void> _handleRequest(HttpRequest request) async {
    final urlParam = request.uri.queryParameters['url'];
    if (urlParam == null || urlParam.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing url parameter');
      await request.response.close();
      return;
    }

    final Uri targetUri;
    try {
      targetUri = Uri.parse(urlParam);
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Invalid url parameter');
      await request.response.close();
      return;
    }

    final client = HttpClient();
    try {
      final outgoing = await client.openUrl(request.method, targetUri);

      // Forward Range header so seek/resume works.
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null) {
        outgoing.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      // Inject YouTube-required headers.
      outgoing.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      outgoing.headers.set('referer', _referer);
      outgoing.headers.set('origin', _origin);

      final incoming = await outgoing.close();

      request.response.statusCode = incoming.statusCode;

      // Forward the headers that matter for media playback.
      _copyHeader(
        incoming.headers,
        request.response.headers,
        HttpHeaders.contentTypeHeader,
      );
      _copyHeader(
        incoming.headers,
        request.response.headers,
        HttpHeaders.contentLengthHeader,
      );
      _copyHeader(
        incoming.headers,
        request.response.headers,
        HttpHeaders.contentRangeHeader,
      );
      _copyHeader(
        incoming.headers,
        request.response.headers,
        HttpHeaders.acceptRangesHeader,
      );

      await request.response.addStream(incoming);
      await request.response.close();
    } catch (e) {
      // ignore: avoid_print
      print('AudioProxyServer error for $urlParam: $e');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        request.response.write('Proxy error: $e');
        await request.response.close();
      } catch (_) {
        // Response already partially sent — nothing we can do.
      }
    } finally {
      client.close();
    }
  }

  void _copyHeader(
    HttpHeaders source,
    HttpHeaders target,
    String headerName,
  ) {
    final value = source.value(headerName);
    if (value != null) {
      try {
        target.set(headerName, value);
      } catch (_) {
        // Some headers (e.g. content-length) are managed by the framework
        // and throw if set after the response has started writing.
      }
    }
  }
}
