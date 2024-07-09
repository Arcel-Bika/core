import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:mineral/api/common/commands/command_option_type.dart';
import 'package:mineral/api/common/commands/command_type.dart';
import 'package:mineral/infrastructure/interaction/command/guild_command_context.dart';
import 'package:mineral/infrastructure/interaction/interaction_manager.dart';
import 'package:mineral/infrastructure/interaction/interaction_type.dart';
import 'package:mineral/infrastructure/internals/marshaller/marshaller.dart';

abstract class InteractionDispatcherContract {
  Future<void> dispatch(Map<String, dynamic> data);
}

final class InteractionDispatcher implements InteractionDispatcherContract {
  final InteractionManagerContract _interactionManager;
  final MarshallerContract _marshaller;

  InteractionDispatcher(this._interactionManager, this._marshaller);

  @override
  Future<void> dispatch(Map<String, dynamic> data) async {
    final interactionType = InteractionType.values.firstWhere((e) => e.value == data['type']);

    return switch (interactionType) {
      InteractionType.applicationCommand => await _handleCommand(data),
      _ => throw Exception('Unknown interaction type: ${data['type']}'),
    };
  }

  Future<void> _handleGroups(Map<String, dynamic> data, Map<String, dynamic> group) async {
    data['data']['options'] = group['options'];

    return _handleSubCommand(data, group);
  }

  Future<void> _handleSubCommand(Map<String, dynamic> data, Map<String, dynamic> option) async {
    data['data']['name'] = "${data['data']['name']}.${option['name']}";
    data['data']['options'] = option['options'];

    return _handleCommand(data);
  }

  Future<void> _handleCommand(Map<String, dynamic> data) async {
    for (final option in data['data']['options']) {
      final type = CommandType.values.firstWhereOrNull((e) => e.value == option['type']);

      if(type == null) {
        continue;
      }

      return switch(type) {
        CommandType.subCommand => await _handleSubCommand(data, option),
        CommandType.subCommandGroup => await _handleGroups(data, option),
      };
    }

    final command = _interactionManager.commandsHandler.firstWhere((command) => command.$1 == data['data']['name']);

    final commandContext = switch (data['data']['guild_id']) {
      String() => await _marshaller.serializers.guildCommandContext.serialize(data),
      _ => await _marshaller.serializers.globalCommandContext.serialize(data),
    };

    final Map<Symbol, dynamic> options = {};

    for (final option in data['data']['options']) {
      final type = CommandOptionType.values.firstWhereOrNull((e) => e.value == option['type']);

      if(type == null) {
        _marshaller.logger.warn("Unknown option type: ${option['type']}");
        continue;
      }

      options[Symbol(option['name'])] = switch(type) {
        CommandOptionType.user => switch (commandContext) {
          ServerCommandContext() => await _marshaller.dataStore.member.getMember(guildId: commandContext.server.id, memberId: option['value']),
          _ => _marshaller.serializers.user.serialize(option['value']),
        },
        CommandOptionType.channel => await _marshaller.serializers.channels.serialize(option['value']),
        CommandOptionType.role => await _marshaller.serializers.role.serialize(option['value']),
        // TODO attachement
        _ => option['value'],
      };
    }

    await Function.apply(command.$2, [commandContext], options);
  }
}