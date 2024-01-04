import 'dart:convert';

import 'package:http/http.dart';
import 'package:mineral/core.dart';
import 'package:mineral/core/api.dart';
import 'package:mineral/core/builders.dart';
import 'package:mineral/src/api/builders/component_wrapper.dart';
import 'package:mineral/src/api/managers/message_reaction_manager.dart';
import 'package:mineral/src/api/messages/message_attachment.dart';
import 'package:mineral/src/api/messages/message_author.dart';
import 'package:mineral/src/api/messages/message_mention.dart';
import 'package:mineral/src/api/messages/message_sticker_item.dart';
import 'package:mineral/src/api/messages/partial_message.dart';
import 'package:mineral/src/internal/mixins/mineral_client.dart';
import 'package:mineral/src/internal/services/console/console_service.dart';
import 'package:mineral_ioc/ioc.dart';

import 'message_parser.dart';

class Message extends PartialMessage<TextBasedChannel>  {
  final MessageMention _mentions;
  final MessageAuthor _author;

  Message(
    super._id,
    super._content,
    super._tts,
    super._embeds,
    super._allowMentions,
    super._reference,
    super._components,
    super._stickers,
    super._payload,
    super._attachments,
    super._flags,
    super._pinned,
    super._guildId,
    super._channelId,
    super._reactions,
    super.timestamp,
    super.editedTimestamp,
    this._mentions,
    this._author,
  );

  /// Get author of this
  MessageAuthor get author => _author;

  /// Get channel of this
  @override
  TextBasedChannel get channel => super.channel;

  /// Get all mentions of this
  MessageMention get mentions => _mentions;

  /// Edit this message
  /// ```dart
  /// await message.edit(content: 'Hello world!');
  /// ```
  Future<Message?> edit ({ String? content, List<EmbedBuilder>? embeds, ComponentBuilder? components, List<AttachmentBuilder>? attachments, bool? tts }) async {
    dynamic messagePayload = MessageParser(content, embeds, components, attachments, null).toJson();

    Response response = await ioc.use<DiscordApiHttpService>().patch(url: '/channels/${channel.id}/messages/$id')
      .files(messagePayload['files'])
      .payload({
        ...messagePayload['payload'],
        'flags': flags
      })
      .build();

    return response.statusCode == 200
      ? Message.from(channel: channel, payload: jsonDecode(response.body))
      : null;
  }

  Future<void> crossPost () async {
    if (channel.type != ChannelType.guildNews) {
      ioc.use<ConsoleService>().warn('Message $id cannot be cross-posted as it is not in an announcement channel');
      return;
    }

    await ioc.use<DiscordApiHttpService>().post(url: '/channels/${super.channel.id}/messages/${super.id}/crosspost')
      .build();
  }

  /// Create a thread from this message
  /// ```dart
  /// ThreadChannel? thread = await message.createThread(label: 'My thread');
  /// ```
  Future<ThreadChannel?> createThread ({ required String label, int archiveDuration = 60}) async {
     Response response = await ioc.use<DiscordApiHttpService>().post(url: '/channels/${super.channel.id}/messages/${super.id}/threads')
        .payload({
          'name': label,
          'auto_archive_duration': archiveDuration,
        })
        .build();

    return await channel.guild.channels.resolve(jsonDecode(response.body)['id']) as ThreadChannel?;
  }

  /// Pin this message
  /// ```dart
  /// await message.pin();
  /// ```
  Future<void> pin () async {
    if (isPinned) {
      ioc.use<ConsoleService>().warn('Message $id is already pinned');
      return;
    }

    await ioc.use<DiscordApiHttpService>().put(url: '/channels/${channel.id}/pins/$id')
      .build();
  }

  /// Unpin this message
  /// ```dart
  /// await message.unpin();
  /// ```
  Future<void> unpin () async {
    if (!isPinned) {
      ioc.use<ConsoleService>().warn('Message $id isn\'t pinned');
      return;
    }

    await ioc.use<DiscordApiHttpService>()
      .destroy(url: '/channels/${channel.id}/pins/$id')
      .build();
  }

  /// Reply to this message
  /// ```dart
  /// await message.reply(content: 'Hello world!');
  /// ```
  Future<PartialMessage?> reply ({ String? content, List<EmbedBuilder>? embeds, ComponentBuilder? components, List<AttachmentBuilder>? attachments, bool? tts }) async {
    MineralClient client = ioc.use<MineralClient>();

    Response response = await client.sendMessage(channel,
      content: content,
      embeds: embeds,
      components: components,
      messageReference: {
        'guild_id': channel.guild.id,
        'channel_id': channel.id,
        'message_id': id,
      },
      attachments: attachments
    );

    if (response.statusCode == 200) {
      Message message = Message.from(channel: channel, payload: jsonDecode(response.body));

      channel.messages.cache.putIfAbsent(message.id, () => message);
      return message;
    }

    return null;
  }

  factory Message.from({ required GuildChannel channel, required dynamic payload }) {
    List<EmbedBuilder> embeds = [];
    if (payload['embeds'] != null) {
      for (dynamic element in payload['embeds']) {
         embeds.add(EmbedBuilder.from(element));
      }
    }

    List<MessageStickerItem> stickers = [];
    if (payload['sticker_items'] != null) {
      for (dynamic element in payload['sticker_items']) {
        MessageStickerItem sticker = MessageStickerItem.from(element);
        stickers.add(sticker);
      }
    }

    List<MessageAttachment> messageAttachments = [];
    if (payload['attachments'] != null) {
      for (dynamic element in payload['attachments']) {
        MessageAttachment attachment = MessageAttachment.from(element);
        messageAttachments.add(attachment);
      }
    }

    ComponentBuilder componentBuilder = ComponentBuilder();
    if (payload['components'] != null) {
      for (dynamic element in payload['components']) {
        componentBuilder.rows.add(ComponentWrapper.wrap(element, payload['guild_id']));
      }
    }

    List<Snowflake> memberMentions = [];
    if (payload['mentions'] != null) {
      for (final element in payload['mentions']) {
        memberMentions.add(element['id']);
      }
    }

    List<Snowflake> roleMentions = [];
    if (payload['mention_roles'] != null) {
      for (final element in payload['mention_roles']) {
        roleMentions.add(element);
      }
    }

    List<Snowflake> channelMentions = [];
    if (payload['mention_channels'] != null) {
      for (final element in payload['mention_channels']) {
        channelMentions.add(element['id']);
      }
    }

    final message = Message(
      payload['id'],
      payload['content'] ?? '',
      payload['tts'] ?? false,
      embeds,
      payload['allow_mentions'] ?? false,
      payload['reference'],
      componentBuilder,
      stickers,
      payload['payload'],
      messageAttachments,
      payload['flags'],
      payload['pinned'] ?? false,
      channel.guild.id,
      payload['channel_id'],
      MessageReactionManager<GuildChannel, Message>(channel),
      payload['timestamp'] ?? DateTime.now().toIso8601String(),
      payload['edited_timestamp'],
      MessageMention(channel, channelMentions, memberMentions, roleMentions, payload['mention_everyone'] ?? false),
      MessageAuthor(channel.guild.id, User.from(payload['author']))
    );

    message.reactions.message = message;

    return message;
  }
}
