import 'package:mineral/api/server/managers/channel_manager.dart';
import 'package:mineral/api/server/managers/emoji_manager.dart';
import 'package:mineral/api/server/managers/member_manager.dart';
import 'package:mineral/api/server/managers/role_manager.dart';
import 'package:mineral/api/server/managers/sticker_manager.dart';
import 'package:mineral/api/server/member.dart';
import 'package:mineral/api/server/role.dart';
import 'package:mineral/api/server/server_assets.dart';
import 'package:mineral/api/server/server_settings.dart';

final class Server {
  final String id;
  final String name;
  final String? description;
  final GuildMember owner;
  final MemberManager members;
  final MemberManager bots;
  final ServerSettings settings;
  final RoleManager roles;
  final EmojiManager emojis;
  final StickerManager stickers;
  final ChannelManager channels;
  final String? applicationId;
  final ServerAsset assets;

  Server({
    required this.id,
    required this.name,
    required this.members,
    required this.bots,
    required this.settings,
    required this.roles,
    required this.emojis,
    required this.stickers,
    required this.channels,
    required this.description,
    required this.applicationId,
    required this.assets,
    required this.owner,
  });

  factory Server.fromJson(Map<String, dynamic> json) {
    final roles = RoleManager(Map<String, Role>.from(json['roles'].fold({}, (value, element) {
      final role = Role.fromJson(element);
      return {...value, role.id: role};
    })));

    List<Map<String, dynamic>> filterMember(bool isBot) {
      return List<Map<String, dynamic>>.from(
          json['members'].where((element) => element['user']['bot'] == isBot));
    }

    final members =
        MemberManager.fromJson(guildId: json['id'], roles: roles, json: filterMember(false))
          ..maxInGuild = json['max_members'];

    final bots =
        MemberManager.fromJson(guildId: json['id'], roles: roles, json: filterMember(true));

    final emojis = EmojiManager.fromJson(roles: roles, json: json['emojis']);

    final channels = ChannelManager.fromJson(guildId: json['id'], json: json);

    final server = Server(
        id: json['id'],
        name: json['name'],
        members: members,
        bots: bots,
        settings: ServerSettings.fromJson(json),
        roles: roles,
        emojis: emojis,
        stickers: StickerManager.fromJson(json['stickers']),
        channels: channels,
        description: json['description'],
        applicationId: json['application_id'],
        assets: ServerAsset.fromJson(json),
        owner: members.getOrFail(json['owner_id']));

    for (final channel in server.channels.list.values) {
      channel.guild = server;
    }

    return server;
  }
}
