import 'package:mineral/api.dart';
import 'package:mineral/core.dart';

enum InteractionCallbackType {
  pong(1),
  channelMessageWithSource(4),
  deferredChannelMessageWithSource(5),
  deferredUpdateMessage(6),
  updateMessage(7),
  applicationCommandAutocompleteResult(8),
  modal(9);

  final int value;
  const InteractionCallbackType(this.value);
}

class Interaction {
  Snowflake _id;
  String? _label;
  Snowflake _applicationId;
  int _version;
  int _typeId;
  String _token;
  Snowflake? _userId;
  Snowflake? _guildId;

  Interaction(this._id, this._label, this._applicationId, this._version, this._typeId, this._token, this._userId, this._guildId);

  Snowflake get id => _id;
  String? get label => _label;
  Snowflake get applicationId => _applicationId;
  int get version => _version;
  InteractionType get type => InteractionType.values.firstWhere((element) => element.value == _typeId);
  String get token => _token;
  Guild? get guild => ioc.singleton<MineralClient>(Service.client).guilds.cache.get(_guildId);

  User get user => _guildId != null
    ? guild!.members.cache.getOrFail(_userId).user
    : ioc.singleton<MineralClient>(Service.client).users.cache.getOrFail(_userId);

  GuildMember? get member => guild?.members.cache.get(_userId);

  /// ### Responds to this by an [Message]
  ///
  /// Example :
  /// ```dart
  /// await interaction.reply(content: 'Hello ${interaction.user.username}');
  /// ```
  Future<void> reply ({ String? content, List<EmbedBuilder>? embeds, List<RowBuilder>? components, bool? tts, bool? private }) async {
    Http http = ioc.singleton(Service.http);

    List<dynamic> embedList = [];
    if (embeds != null) {
      for (EmbedBuilder element in embeds) {
        embedList.add(element.toJson());
      }
    }

    List<dynamic> componentList = [];
    if (components != null) {
      for (RowBuilder element in components) {
        componentList.add(element.toJson());
      }
    }

    await http.post(url: "/interactions/$id/$token/callback", payload: {
      'type': InteractionCallbackType.channelMessageWithSource.value,
      'data': {
        'tts': tts ?? false,
        'content': content,
        'embeds': embeds != null ? embedList : [],
        'components': components != null ? componentList : [],
        'flags': private != null && private == true ? 1 << 6 : null,
      }
    });
  }

  /// ### Responds to this by an [ModalBuilder]
  ///
  /// Example :
  /// ```dart
  /// Modal modal = Modal(customId: 'modal', label: 'My modal')
  ///   .addInput(customId: 'my_text', label: 'First text')
  ///   .addParagraph(customId: 'my_paragraph', label: 'Second text');
  ///
  /// await interaction.modal(modal);
  /// ```
  Future<void> modal (ModalBuilder modal) async {
    Http http = ioc.singleton(Service.http);

    await http.post(url: "/interactions/$id/$token/callback", payload: {
      'type': InteractionCallbackType.modal.value,
      'data': modal.toJson(),
    });
  }

  factory Interaction.from({ required dynamic payload }) {
    return Interaction(
      payload['id'],
      null,
      payload['application_id'],
      payload['version'],
      payload['type'],
      payload['token'],
      payload['member']?['user']?['id'],
      payload['guild_id'],
    );
  }
}
