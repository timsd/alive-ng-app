/// Riverpod providers for the video meeting service.
///
/// Encapsulates access to the [MeetingGateway] port so UI widgets
/// and screens can participate in meetings without depending on concrete SDKs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meeting_models.dart';
import '../services/adapters/livekit_meeting_gateway.dart';
import '../services/ports/meeting_gateway.dart';

/// Provider for the abstract [MeetingGateway].
///
/// Instantiates the concrete [LiveKitMeetingGateway] adapter and manages
/// its lifecycle.
final meetingGatewayProvider = Provider<MeetingGateway>((ref) {
  final gateway = LiveKitMeetingGateway();
  ref.onDispose(() => gateway.dispose());
  return gateway;
});

/// Stream provider for real-time [MeetingSession] updates.
final meetingSessionStreamProvider = StreamProvider<MeetingSession>((ref) {
  final gateway = ref.watch(meetingGatewayProvider);
  return gateway.sessionStream;
});

/// Stream provider for room connection [RoomStatus] changes.
final meetingRoomStatusProvider = StreamProvider<RoomStatus>((ref) {
  final gateway = ref.watch(meetingGatewayProvider);
  return gateway.roomStatus;
});
