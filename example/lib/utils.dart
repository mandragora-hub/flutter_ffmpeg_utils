import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_utils/ffmpeg_utils.dart' as ffmpeg_utils;

enum DownloadStatus { downloading, muxing, done, error, idle }

class YoutubeDownloader {
  Directory? downloadsDir;

  DownloadStatus _status = DownloadStatus.idle;

  String get status {
    switch (_status) {
      case DownloadStatus.downloading:
        return "Downloading";
      case DownloadStatus.muxing:
        return "Muxing";
      case DownloadStatus.done:
        return "Done";
      case DownloadStatus.error:
        return "Error";
      case DownloadStatus.idle:
        return "Idle";
    }
  }

// Track the file download status.
  int len = 0;
  int count = 0;

  double get progress => (len == 0 ? 0 : (count / len) * 100);

  YoutubeDownloader() {
    getDownloadsDirectory().then((d) => {downloadsDir = d});
  }

  void deleteFileIfExists(final File file) {
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  String cleanFilename(String filename) {
    return filename
        .replaceAll(r'\', '')
        .replaceAll('/', '')
        .replaceAll('*', '')
        .replaceAll('?', '')
        .replaceAll('"', '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll(':', '')
        .replaceAll('|', '');
  }

  void download(final String title, AudioOnlyStreamInfo audioOnlyStreamInfo,
      VideoOnlyStreamInfo videoOnlyStreamInfo) async {
    // Downloading
    _status = DownloadStatus.downloading;

    YoutubeExplode yt = YoutubeExplode();

    len = videoOnlyStreamInfo.size.totalBytes +
        audioOnlyStreamInfo.size.totalBytes;
    count = 0;

    Stream<List<int>> audioStreams = yt.videos.streams.get(audioOnlyStreamInfo);
    Stream<List<int>> videoStreams = yt.videos.streams.get(videoOnlyStreamInfo);

    final String audioName =
        cleanFilename("$title-audio.${audioOnlyStreamInfo.container}");
    final String videoName =
        cleanFilename("$title-video.${videoOnlyStreamInfo.container}");

    File audioFile = File('${downloadsDir!.path}/$audioName');
    File videoFile = File('${downloadsDir!.path}/$videoName');
    deleteFileIfExists(audioFile);
    deleteFileIfExists(videoFile);

    IOSink audioFileStream =
        audioFile.openWrite(mode: FileMode.writeOnlyAppend);
    IOSink videoFileStream =
        videoFile.openWrite(mode: FileMode.writeOnlyAppend);

    await for (final data in audioStreams) {
      count += data.length;
      audioFileStream.add(data);
    }

    await audioFileStream.flush();
    await audioFileStream.close();

    await for (final data in videoStreams) {
      count += data.length;
      videoFileStream.add(data);
    }

    await videoFileStream.flush();
    await videoFileStream.close();

    // ----------------------------
    // Muxing
    _status = DownloadStatus.muxing;

    int result = await ffmpeg_utils.muxerAsync(
        videoFile.path, audioFile.path, "${downloadsDir!.path}/$title.mp4");
    (result != 0)
        ? _status = DownloadStatus.error
        : _status = DownloadStatus.done;

    yt.close();
  }
}
