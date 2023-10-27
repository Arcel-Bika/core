import 'dart:async';

import 'package:mineral/api/common/snowflake.dart';
import 'package:mineral/api/server/contracts/guild_contracts.dart';
import 'package:mineral/api/common/client/client.dart';
import 'package:mineral/api/server/caches/guild_cache.dart';
import 'package:mineral/api/server/guild.dart';
import 'package:mineral/internal/factories/events/contracts/guilds/guild_update_event_contract.dart';
import 'package:mineral/internal/factories/events/event_factory.dart';
import 'package:mineral/internal/fold/container.dart';
import 'package:mineral/internal/wss/contracts/packet_contract.dart';
import 'package:mineral/internal/wss/entities/websocket_response.dart';

final class GuildUpdatePacket implements PacketContract {
  @override
  final EventFactory eventFactory;

  GuildUpdatePacket(this.eventFactory);

  @override
  Future<void> handle(WebsocketResponse response) async {
    final Client client = container.use<Client>('client');
    final GuildCache guilds = client.guilds as GuildCache;
    final GuildContract beforeGuild = guilds.cache.getOrFail(Snowflake(response.payload['id']));
    final GuildContract guild = Guild.fromWss(response.payload);

    guild.channels.cache.addAll(beforeGuild.channels.cache);
    guild.roles.cache.addAll(beforeGuild.roles.cache);
    guild.members.cache.addAll(beforeGuild.members.cache);
    guild.emojis.cache.addAll(beforeGuild.emojis.cache);

    guilds.cache[guild.id] = guild;

    eventFactory.dispatch<GuildUpdateEventContract>(
      (event) => event.handle(beforeGuild, guild)
    );
  }
}