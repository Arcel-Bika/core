import 'dart:convert';

import 'package:http/http.dart';
import 'package:mineral/api.dart';
import 'package:mineral/core.dart';
import 'package:mineral/src/api/channels/channel.dart';
import 'package:mineral/src/api/managers/channel_manager.dart';
import 'package:mineral/src/api/managers/emoji_manager.dart';
import 'package:mineral/src/api/managers/member_manager.dart';
import 'package:mineral/src/api/managers/moderation_rule_manager.dart';
import 'package:mineral/src/api/managers/role_manager.dart';
import 'package:mineral/src/internal/entities/command_manager.dart';
import 'package:mineral/src/internal/entities/event_manager.dart';
import 'package:mineral/src/internal/websockets/websocket_packet.dart';
import 'package:mineral/src/internal/websockets/websocket_response.dart';

class GuildCreate implements WebsocketPacket {
  @override
  PacketType packetType = PacketType.guildCreate;

  @override
  Future<void> handle(WebsocketResponse websocketResponse) async {
    EventManager manager = ioc.singleton(ioc.services.event);
    CommandManager commandManager = ioc.singleton(ioc.services.command);
    MineralClient client = ioc.singleton(ioc.services.client);

    print(jsonEncode(websocketResponse.payload));

    RoleManager roleManager = RoleManager(guildId: websocketResponse.payload['id']);
    for (dynamic item in websocketResponse.payload['roles']) {
      Role role = Role.from(roleManager: roleManager, payload: item);
      roleManager.cache.putIfAbsent(role.id, () => role);
    }

    MemberManager memberManager = MemberManager(guildId: websocketResponse.payload['id']);
    for (dynamic member in websocketResponse.payload['members']) {
      GuildMember guildMember = GuildMember.from(
        roles: roleManager,
        user: User.from(member['user']),
        member: member,
        guildId: websocketResponse.payload['id']
      );

      memberManager.cache.putIfAbsent(guildMember.user.id, () => guildMember);
    }

    ChannelManager channelManager = ChannelManager(guildId: websocketResponse.payload['id']);
    for(dynamic payload in websocketResponse.payload['channels']) {
      ChannelType channelType = ChannelType.values.firstWhere((type) => type.value == payload['type']);
      if (channels.containsKey(channelType)) {
        Channel Function(dynamic payload) item = channels[channelType] as Channel Function(dynamic payload);
        Channel channel = item(payload);

        channelManager.cache.putIfAbsent(channel.id, () => channel);
      }
    }

    EmojiManager emojiManager = EmojiManager(guildId: websocketResponse.payload['id']);
    for(dynamic payload in websocketResponse.payload['emojis']) {
      Emoji emoji = Emoji.from(
        memberManager: memberManager,
        roleManager: roleManager,
        emojiManager: emojiManager,
        payload: payload
      );

      emojiManager.cache.putIfAbsent(emoji.id, () => emoji);
    }

    ModerationRuleManager moderationManager = ModerationRuleManager(guildId: websocketResponse.payload['id']);

    Guild guild = Guild.from(
      emojiManager: emojiManager,
      memberManager: memberManager,
      roleManager: roleManager,
      channelManager: channelManager,
        moderationRuleManager: moderationManager,
      payload: websocketResponse.payload
    );

    // Assign guild members
    guild.members.cache.forEach((Snowflake id, GuildMember member) {
      member.guild = guild;
      member.voice.member = member;
      member.voice.channel = guild.channels.cache.get(member.voice.channelId);
    });

    // Assign guild channels
    channelManager.guild = guild;
    guild.channels.cache.forEach((Snowflake id, Channel channel) {
      channel.guildId = guild.id;
      channel.guild = guild;
      channel.parent = channel.parentId != null ? guild.channels.cache.get<CategoryChannel>(channel.parentId) : null;
    });

    moderationManager.guild = guild;

    guild.stickers.guild = guild;
    guild.stickers.cache.forEach((_, sticker) {
      sticker.guild = guild;
      sticker.guildMember = guild.channels.cache.get(sticker.guildMemberId);
    });

    guild.afkChannel = guild.channels.cache.get<VoiceChannel>(guild.afkChannelId);
    guild.systemChannel = guild.channels.cache.get<TextChannel>(guild.systemChannelId);
    guild.rulesChannel = guild.channels.cache.get<TextChannel>(guild.rulesChannelId);
    guild.publicUpdatesChannel = guild.channels.cache.get<TextChannel>(guild.publicUpdatesChannelId);
    guild.emojis.guild = guild;
    guild.roles.guild = guild;

    Map<Snowflake, ModerationRule>? autoModerationRules = await getAutoModerationRules(guild);
    if (autoModerationRules != null) {
      guild.moderationRules.cache.addAll(autoModerationRules);
    }

    await client.registerGuildCommands(
      guild: guild,
      commands: commandManager.getFromGuild(guild)
    );

    client.guilds.cache.putIfAbsent(guild.id, () => guild);

    manager.emit(Events.guildCreate, [guild]);
  }

  Future<Map<Snowflake, ModerationRule>?> getAutoModerationRules (Guild guild) async {
    Http http = ioc.singleton(ioc.services.http);
    Response response = await http.get(url: "/guilds/${guild.id}/auto-moderation/rules");

    if (response.statusCode == 200) {
      dynamic payload = jsonDecode(response.body);

      Map<Snowflake, ModerationRule> rules = {};
      for (dynamic element in payload) {
        ModerationRule rule = ModerationRule.from(guild: guild, payload: element);
        rules.putIfAbsent(rule.id, () => rule);
      }

      return rules;
    }

    return null;
  }
}
