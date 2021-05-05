// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/hls/better_player_hls_audio_track.dart';

// Project imports:
import 'package:better_player/src/hls/better_player_hls_track.dart';
import 'package:better_player/src/hls/hls_parser/hls_master_playlist.dart';
import 'package:better_player/src/hls/hls_parser/hls_playlist_parser.dart';
import 'package:better_player/src/hls/hls_parser/rendition.dart';

///HLS helper class
class BetterPlayerHlsUtils {
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  static Future<List<BetterPlayerHlsTrack>> parseTracks(
      String data, String masterPlaylistUrl) async {
    final List<BetterPlayerHlsTrack> tracks = [];
    try {
      final parsedPlaylist = await HlsPlaylistParser.create()
          .parseString(Uri.parse(masterPlaylistUrl), data);
      if (parsedPlaylist is HlsMasterPlaylist) {
        parsedPlaylist.variants.forEach(
          (variant) {
            tracks.add(BetterPlayerHlsTrack(variant.format.width,
                variant.format.height, variant.format.bitrate));
          },
        );
      }

      if (tracks.isNotEmpty) {
        tracks.insert(0, BetterPlayerHlsTrack.defaultTrack());
      }
    } catch (exception) {
      BetterPlayerUtils.log("Exception on parseSubtitles: $exception");
    }
    return tracks;
  }

  static Future<List<BetterPlayerHlsAudioTrack>> parseLanguages(
      String data, String masterPlaylistUrl) async {
    final List<BetterPlayerHlsAudioTrack> audios = [];
    final parsedPlaylist = await HlsPlaylistParser.create()
        .parseString(Uri.parse(masterPlaylistUrl), data);
    if (parsedPlaylist is HlsMasterPlaylist) {
      for (int index = 0; index < parsedPlaylist.audios.length; index++) {
        final Rendition audio = parsedPlaylist.audios[index];
        audios.add(BetterPlayerHlsAudioTrack(
          id: index,
          label: audio.name,
          language: audio.format.language,
          url: audio.url.toString(),
        ));
      }
    }

    return audios;
  }

  static Future<String?> getDataFromUrl(String url,
      [Map<String, String?>? headers]) async {
    try {
      final request = await _httpClient.getUrl(Uri.parse(url));
      if (headers != null) {
        headers.forEach((name, value) => request.headers.add(name, value!));
      }

      final response = await request.close();
      var data = "";
      await response.transform(const Utf8Decoder()).listen((content) {
        data += content.toString();
      }).asFuture<String?>();

      return data;
    } catch (exception) {
      BetterPlayerUtils.log("GetDataFromUrl failed: $exception");
      return null;
    }
  }
}
