import 'package:mineral/api.dart';
import 'package:mineral/core.dart';
import 'package:mineral/src/api/managers/command_manager.dart';
import 'package:mineral/src/api/managers/dm_channel_manager.dart';
import 'package:mineral/src/api/managers/guild_manager.dart';
import 'package:mineral/src/api/managers/user_manager.dart';
import 'package:mineral/src/internal/websockets/sharding/shard_manager.dart';

enum ClientStatus {
  online('online'),
  doNotDisturb('dnd'),
  idle('idle'),
  invisible('invisible'),
  offline('offline');

  final String _value;
  const ClientStatus(this._value);

  @override
  String toString () => _value;
}

class ClientActivity {
 String name;
 GamePresence type;

 ClientActivity({ required this.name, required this.type });

 Object toJson () => { 'name': name, 'type': type.value };
}

class MineralClient {
  User _user;
  GuildManager _guilds;
  DmChannelManager _dmChannels;
  UserManager _users;
  String _sessionId;
  Application _application;
  List<Intent> _intents;
  CommandManager _commands;
  late DateTime uptime;

  MineralClient(
    this._user,
    this._guilds,
    this._dmChannels,
    this._users,
    this._sessionId,
    this._application,
    this._intents,
    this._commands,
  );

  User get user => _user;
  GuildManager get guilds => _guilds;
  DmChannelManager get dmChannels => _dmChannels;
  UserManager get users => _users;
  String get sessionId => _sessionId;
  Application get application => _application;
  List<Intent> get intents => _intents;
  ShardManager get _shards => ioc.singleton(Service.shards);

  /// ### Returns the time the [MineralClient] is online
  Duration get uptimeDuration => DateTime.now().difference(uptime);

  CommandManager get commands => _commands;

  /// ### Defines the presence that this should adopt
  ///
  /// Example :
  /// ```dart
  /// client.setPresence(
  ///   activity: ClientActivity(name: 'My activity', type: GamePresence.listening),
  ///   status: ClientStatus.doNotDisturb
  /// );
  /// ```
  void setPresence ({ ClientActivity? activity, ClientStatus? status, bool? afk }) {
    _shards.send(OpCode.statusUpdate, {
      'since': DateTime.now().millisecond,
      'activities': activity != null ? [activity.toJson()] : [],
      'status': status != null ? status.toString() : ClientStatus.online.toString(),
      'afk': afk ?? false,
    });
  }

  /// Define activities of this
  void setActivities (List<ClientActivity> activities) {
    _shards.send(OpCode.statusUpdate, {
      'activities': activities.map((activity) => activity.toJson()),
    });
  }

  /// Define status of this
  void setStatus (ClientStatus status) {
    _shards.send(OpCode.statusUpdate, {
      'status': status._value,
    });
  }


  /// Define afk of this
  void setAfk (bool afk) {
    _shards.send(OpCode.statusUpdate, {
      'afk': afk,
    });
  }

  /// Sends a ping/pong to the APi websocket of discord and returns the latency
  ///
  /// Example :
  /// ```dart
  /// final int latency = client.getLatency();
  /// ```
  int getLatency () {
    ShardManager manager = ioc.singleton(Service.shards);
    return manager.getLatency();
  }

  Future<void> registerGlobalCommands ({ required List<CommandBuilder> commands }) async {
    Http http = ioc.singleton(Service.http);

    await http.put(
      url: "/applications/${_application.id}/commands",
      payload: commands.map((command) => command.toJson).toList()
    );
  }

  Future<void> registerGuildCommands ({ required Guild guild, required List<CommandBuilder> commands, required List<MineralContextMenu> contextMenus }) async {
    Http http = ioc.singleton(Service.http);

    await http.put(
      url: "/applications/${_application.id}/guilds/${guild.id}/commands",
      payload: [
        ...commands.map((command) => command.toJson).toList(),
        ...contextMenus.map((contextMenus) => contextMenus.builder.toJson).toList()
      ]
    );
  }

  factory MineralClient.from({ required dynamic payload }) {
    ShardManager manager = ioc.singleton(Service.shards);

    return MineralClient(
      User.from(payload['user']),
      GuildManager(),
      DmChannelManager(),
      UserManager(),
      payload['session_id'],
      Application.from(payload['application']),
      manager.intents,
      CommandManager(null),
    );
  }
}
