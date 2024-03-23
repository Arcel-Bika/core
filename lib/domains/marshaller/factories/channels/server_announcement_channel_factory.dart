import 'package:mineral/api/common/channel_properties.dart';
import 'package:mineral/api/common/types/channel_type.dart';
import 'package:mineral/api/server/channels/server_announcement_channel.dart';
import 'package:mineral/api/server/channels/server_category_channel.dart';
import 'package:mineral/domains/marshaller/marshaller.dart';
import 'package:mineral/domains/marshaller/types/channel_factory.dart';
import 'package:mineral/domains/shared/helper.dart';

final class ServerAnnouncementChannelFactory
    implements ChannelFactoryContract<ServerAnnouncementChannel> {
  @override
  ChannelType get type => ChannelType.guildAnnouncement;

  @override
  Future<ServerAnnouncementChannel> make(MarshallerContract marshaller, String guildId,
      Map<String, dynamic> json) async {
    final properties = await ChannelProperties.make(marshaller, json);
    final categoryChannel = await Helper.createOrNullAsync(
        field: json['parent_id'],
        fn: () async {
          final rawCategory = await marshaller.cache.get(json['parent_id']);
          return marshaller.serializers.channels.serialize(rawCategory) as ServerCategoryChannel;
        }
    );

    return ServerAnnouncementChannel(properties,
      category: categoryChannel,
    );
  }

  @override
  Future<Map<String, dynamic>> deserialize(MarshallerContract marshaller,
      ServerAnnouncementChannel channel) async {
    final permissionOverwrites = await Future.wait(
      channel.permissions
          .map((json) async => marshaller.serializers.channelPermissionOverwrite.deserialize(json))
          .toList(),
    );

    final permissions = await Future.wait(channel.permissions.map((element) async =>
        marshaller.serializers.channelPermissionOverwrite.deserialize(element)));

    return {
      'id': channel.id.value,
      'type': channel.type.value,
      'position': channel.position,
      'permission_overwrites': permissionOverwrites,
      'name': channel.name,
      'topic': channel.description,
      'nsfw': channel.isNsfw,
      'parent_id': channel.category?.id,
      'permissions': permissions,
    };
  }
}
