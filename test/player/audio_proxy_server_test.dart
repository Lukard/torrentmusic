import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torrentmusic/player/audio_proxy_server.dart';

void main() {
  group('AudioProxyServer', () {
    late AudioProxyServer proxy;

    setUp(() {
      proxy = AudioProxyServer.forTest();
    });

    tearDown(() async {
      await proxy.stop();
    });

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    test('is not running before start()', () {
      expect(proxy.isRunning, isFalse);
      expect(proxy.port, isNull);
    });

    test('start() binds to a random port', () async {
      await proxy.start();
      expect(proxy.isRunning, isTrue);
      expect(proxy.port, isNotNull);
      expect(proxy.port, greaterThan(0));
    });

    test('start() is idempotent — second call keeps the same port', () async {
      await proxy.start();
      final firstPort = proxy.port;
      await proxy.start();
      expect(proxy.port, firstPort);
    });

    test('stop() stops the server', () async {
      await proxy.start();
      await proxy.stop();
      expect(proxy.isRunning, isFalse);
      expect(proxy.port, isNull);
    });

    test('can be restarted after stop()', () async {
      await proxy.start();
      final firstPort = proxy.port;
      await proxy.stop();
      await proxy.start();
      expect(proxy.isRunning, isTrue);
      // A new random port — may or may not equal firstPort, just check valid.
      expect(proxy.port, isNotNull);
      expect(firstPort, isNotNull); // was valid before stop
    });

    // -------------------------------------------------------------------------
    // proxyUrl()
    // -------------------------------------------------------------------------

    test('proxyUrl() encodes the target URL as a query param', () async {
      await proxy.start();
      const target = 'https://example.com/path?a=1&b=2';
      final url = proxy.proxyUrl(target);
      expect(url, startsWith('http://localhost:${proxy.port}/proxy?url='));
      expect(url, contains(Uri.encodeComponent(target)));
    });

    // -------------------------------------------------------------------------
    // Request forwarding — uses a local mock "YouTube" server
    // -------------------------------------------------------------------------

    /// Start a local target server that captures requests and responds.
    Future<(HttpServer, Future<HttpRequest>)> _startTargetServer({
      int statusCode = 200,
      Map<String, String> responseHeaders = const {},
      List<int> body = const [],
    }) async {
      final server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final completer = Completer<HttpRequest>();
      server.listen((req) async {
        if (!completer.isCompleted) completer.complete(req);
        req.response.statusCode = statusCode;
        for (final entry in responseHeaders.entries) {
          req.response.headers.set(entry.key, entry.value);
        }
        if (body.isNotEmpty) {
          req.response.add(body);
        }
        await req.response.close();
      });
      return (server, completer.future);
    }

    test('forwards request and returns the target response', () async {
      final (targetServer, requestFuture) = await _startTargetServer(
        statusCode: 200,
        responseHeaders: {'content-type': 'audio/webm'},
        body: [1, 2, 3, 4],
      );

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio.webm',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final response = await req.close();
      final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      await requestFuture; // ensure target received the request

      expect(response.statusCode, 200);
      expect(body, [1, 2, 3, 4]);

      client.close();
      await targetServer.close();
    });

    test('injects YouTube User-Agent header', () async {
      final (targetServer, requestFuture) = await _startTargetServer();

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final response = await req.close();
      await response.drain<void>();

      final received = await requestFuture;
      expect(received.headers.value('user-agent'), contains('Android'));

      client.close();
      await targetServer.close();
    });

    test('injects Referer header pointing to youtube.com', () async {
      final (targetServer, requestFuture) = await _startTargetServer();

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final response = await req.close();
      await response.drain<void>();

      final received = await requestFuture;
      expect(received.headers.value('referer'), 'https://www.youtube.com/');

      client.close();
      await targetServer.close();
    });

    test('injects Origin header pointing to youtube.com', () async {
      final (targetServer, requestFuture) = await _startTargetServer();

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final response = await req.close();
      await response.drain<void>();

      final received = await requestFuture;
      expect(received.headers.value('origin'), 'https://www.youtube.com');

      client.close();
      await targetServer.close();
    });

    test('forwards Range header for seek support', () async {
      final (targetServer, requestFuture) = await _startTargetServer(
        statusCode: 206,
        responseHeaders: {'content-range': 'bytes 100-199/1000'},
      );

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      req.headers.set('range', 'bytes=100-199');
      final response = await req.close();
      await response.drain<void>();

      final received = await requestFuture;
      expect(received.headers.value('range'), 'bytes=100-199');
      expect(response.statusCode, 206);

      client.close();
      await targetServer.close();
    });

    test('forwards content-type response header', () async {
      final (targetServer, _) = await _startTargetServer(
        responseHeaders: {'content-type': 'audio/mp4'},
      );

      await proxy.start();
      final proxyUrl = proxy.proxyUrl(
        'http://localhost:${targetServer.port}/audio',
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final response = await req.close();
      await response.drain<void>();

      expect(
        response.headers.value(HttpHeaders.contentTypeHeader),
        contains('audio/mp4'),
      );

      client.close();
      await targetServer.close();
    });

    test('returns 400 when url query param is missing', () async {
      await proxy.start();

      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://localhost:${proxy.port}/proxy'),
      );
      final response = await req.close();
      await response.drain<void>();

      expect(response.statusCode, HttpStatus.badRequest);

      client.close();
    });

    test('returns 400 when url query param is empty', () async {
      await proxy.start();

      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://localhost:${proxy.port}/proxy?url='),
      );
      final response = await req.close();
      await response.drain<void>();

      expect(response.statusCode, HttpStatus.badRequest);

      client.close();
    });

    test('singleton factory returns the same instance', () {
      final a = AudioProxyServer();
      final b = AudioProxyServer();
      expect(identical(a, b), isTrue);
    });

    test('forTest() creates independent instances', () {
      final a = AudioProxyServer.forTest();
      final b = AudioProxyServer.forTest();
      expect(identical(a, b), isFalse);
    });
  });
}
