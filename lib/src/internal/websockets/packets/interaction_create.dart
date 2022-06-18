import 'dart:convert';
import 'dart:mirrors';

import 'package:mineral/api.dart';
import 'package:mineral/core.dart';
import 'package:mineral/src/internal/entities/command_manager.dart';
import 'package:mineral/src/internal/websockets/websocket_packet.dart';
import 'package:mineral/src/internal/websockets/websocket_response.dart';

class InteractionCreate implements WebsocketPacket {
  @override
  PacketType packetType = PacketType.interactionCreate;

  @override
  Future<void> handle(WebsocketResponse websocketResponse) async {
    CommandManager manager = ioc.singleton(ioc.services.command);
    MineralClient client = ioc.singleton(ioc.services.client);

    dynamic payload = websocketResponse.payload;
    print(jsonEncode(payload));

    Guild? guild = client.guilds.cache.get(payload['guild_id']);
    GuildMember? member = guild?.members.cache.get(payload['member']['user']['id']);

    CommandInteraction commandInteraction = CommandInteraction.from(user: member!.user, payload: payload);
    commandInteraction.guild = guild;

    String identifier = commandInteraction.identifier;

    walk (List<dynamic> objects) {
      for (dynamic object in objects) {
        if (object['type'] == 1 || object['type'] == 2) {
          identifier += ".${object['name']}";
          if (object['options'] != null) {
            walk(object['options']);
          }
        } else {
          commandInteraction.data.putIfAbsent(object['name'], () => object);
        }
      }
    }

    if (payload['data']['options'] != null) {
      walk(payload['data']['options']);
    }

    dynamic handle = manager.getHandler(identifier);
    reflect(handle['commandClass']).invoke(handle['symbol'], [commandInteraction]);
  }
}
