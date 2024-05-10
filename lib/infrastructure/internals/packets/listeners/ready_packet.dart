import 'dart:convert';

import 'package:mineral/api/common/bot.dart';
import 'package:mineral/infrastructure/services/logger/logger.dart';
import 'package:mineral/infrastructure/internals/packets/listenable_packet.dart';
import 'package:mineral/infrastructure/internals/packets/packet_type.dart';
import 'package:mineral/infrastructure/internals/marshaller/marshaller.dart';
import 'package:mineral/domains/events/event.dart';
import 'package:mineral/infrastructure/internals/wss/shard_message.dart';

final class ReadyPacket implements ListenablePacket {
  @override
  PacketType get packetType => PacketType.ready;

  final LoggerContract logger;
  final MarshallerContract marshaller;

  const ReadyPacket(this.logger, this.marshaller);

  @override
  void listen(ShardMessage message, DispatchEvent dispatch) {
    final client = Bot.fromJson(message.payload);

    logger.trace(jsonEncode(message.payload));
    dispatch(event: Event.ready, params: [client]);
  }
}
