import 'dart:async';

import 'package:mineral/api.dart';
import 'package:mineral/core.dart';
import 'package:mineral/src/api/interactions/context_menu_interaction.dart';

class ContextMenuManager {
  final Map<String, MineralContextMenu> _contextMenus = {};
  Map<String, MineralContextMenu> get contextMenus => _contextMenus;

  final StreamController<ContextMenuInteraction> controller = StreamController();

  ContextMenuManager() {
    controller.stream.listen((event) async {
      final contextMenu = _contextMenus.findOrFail((element) => element.builder.label == event.label);
      await contextMenu.handle(event);
    });
  }

  void register (List<MineralContextMenu> mineralContextMenus) {
    for (final contextMenu in mineralContextMenus) {
      _contextMenus.putIfAbsent(contextMenu.builder.label, () => contextMenu);
    }
  }

  List<MineralContextMenu> getFromGuild (Guild guild) {
    bool filter(MineralContextMenu element) => element.builder.scope.mode == Scope.guild.mode || element.builder.scope.mode == guild.id;

    return _contextMenus.where(filter).values.toList();
  }
}
