import 'dart:async';

import 'package:mineral/domains/events/types/packet_type.dart';

abstract interface class ListenablePacket<T> {
  PacketType get event;

  FutureOr<void> listen(Map<String, dynamic> payload);
}
