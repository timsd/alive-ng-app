import 'package:flutter/widgets.dart';
import 'video_embed_stub.dart'
    if (dart.library.html) 'video_embed_web.dart' as platform;

Widget buildVideoEmbed({
  required String videoId,
  required String embedUrl,
}) {
  return platform.buildPlatformVideoEmbed(
    videoId: videoId,
    embedUrl: embedUrl,
  );
}

