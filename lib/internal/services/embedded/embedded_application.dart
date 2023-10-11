import 'dart:io';
import 'dart:isolate';

import 'package:mineral/internal/wss/entities/websocket_event_dispatcher.dart';
import 'package:mineral/internal/wss/entities/websocket_response.dart';
import 'package:mineral/services/logger/logger_contract.dart';
import 'package:path/path.dart';

final class EmbeddedApplication {
  final WebsocketEventDispatcher dispatcher = WebsocketEventDispatcher();
  final String isolateDebugName = 'embedded_application';
  final LoggerContract _logger;

  ReceivePort? _port;
  Isolate? isolate;

  EmbeddedApplication(this._logger);

  Future<void> create () async {
    final Uri mainUri = Uri.parse(join(Directory.current.path, 'bin', 'app.dart'));

    _port = ReceivePort();
    isolate = await Isolate.spawnUri(mainUri, [], _port!.sendPort, debugName: isolateDebugName);

    _logger.info('Kernel is ready');
  }

  Future<void> createAndListen () async {
    await create();
    await for (final WebsocketResponse message in _port!) {
      print(message);
    }
  }

  void kill () {
    _port?.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  void restart () {
    kill();
    createAndListen();
  }

  Future<void> sendMessage (dynamic message) async {
    _port?.sendPort.send(message);
  }
}