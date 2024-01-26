import 'package:mineral/api/server/channels/server_channel.dart';
import 'package:mineral/application/logger/logger.dart';
import 'package:mineral/domains/data/types/listenable_packet.dart';
import 'package:mineral/domains/data/types/packet_type.dart';
import 'package:mineral/domains/marshaller/marshaller.dart';
import 'package:mineral/domains/shared/mineral_event.dart';
import 'package:mineral/domains/wss/shard_message.dart';

final class ChannelUpdatePacket implements ListenablePacket {
  @override
  PacketType get packetType => PacketType.channelCreate;

  final LoggerContract logger;
  final MarshallerContract marshaller;

  const ChannelUpdatePacket(this.logger, this.marshaller);

  @override
  void listen(ShardMessage message, DispatchEvent dispatch) {
    final channel = marshaller.serializers.channels.serialize(message.payload);

    switch (channel) {
      case ServerChannel():
        registerServerChannel(message, channel, dispatch);
    }
  }

  void registerServerChannel(ShardMessage message, ServerChannel channel, DispatchEvent dispatch) {
    final server = marshaller.storage.servers[message.payload['guild_id']];

    if (server != null) {
      channel.server = server;
      server.channels.list[channel.id] = channel;
    }

    marshaller.storage.channels[channel.id] = channel;

    dispatch(event: MineralEvent.serverChannelUpdate, params: [channel]);
  }
}
