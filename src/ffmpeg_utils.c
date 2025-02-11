
#include "ffmpeg_utils.h"

#include <libavformat/avformat.h>
#include <libavutil/timestamp.h>

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt,
                       const char *tag) {
  AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;

  platform_log(
      LOG_LEVEL_DEBUG,
      "%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s "
      "stream_index:%d\n",
      tag, av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
      av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
      av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
      pkt->stream_index);
}

FFI_PLUGIN_EXPORT int log_dump_format(const char *filename) {
  AVFormatContext *fmt_ctx = NULL;
  int ret;
  if ((ret = avformat_open_input(&fmt_ctx, filename, NULL, NULL)) < 0) {
    platform_log(LOG_LEVEL_ERROR, "Could not open video file\n");
    return -1;
  }

  av_dump_format(fmt_ctx, 0, filename, 1);

  avformat_close_input(&fmt_ctx);
  return 0;
}

FFI_PLUGIN_EXPORT void show_codecs() {
  void *iter = NULL;
  const AVCodec *codec = NULL;

  platform_log(LOG_LEVEL_DEBUG, "Available decoders:\n");
  // Iterate over decoders
  while ((codec = av_codec_iterate(&iter)) != NULL) {
    if (av_codec_is_decoder(codec)) {
      platform_log(LOG_LEVEL_DEBUG, "Decoder Name: %s\n", codec->name);
      platform_log(LOG_LEVEL_DEBUG, "Decoder Description: %s\n",
                   codec->long_name);
      platform_log(LOG_LEVEL_DEBUG, "Decoder Type: %s\n",
                   codec->type == AVMEDIA_TYPE_VIDEO ? "Video" : "Audio");
      platform_log(LOG_LEVEL_DEBUG, "\n");
    }
  }

  platform_log(LOG_LEVEL_DEBUG, "\nAvailable encoders:\n");
  // Iterate over encoders
  codec = NULL;
  iter = NULL;
  while ((codec = av_codec_iterate(&iter)) != NULL) {
    if (av_codec_is_encoder(codec)) {
      platform_log(LOG_LEVEL_DEBUG, "Encoder Name: %s\n", codec->name);
      platform_log(LOG_LEVEL_DEBUG, "Encoder Description: %s\n",
                   codec->long_name);
      platform_log(LOG_LEVEL_DEBUG, "Encoder Type: %s\n",
                   codec->type == AVMEDIA_TYPE_VIDEO ? "Video" : "Audio");
      platform_log(LOG_LEVEL_DEBUG, "\n");
    }
  }
}

FFI_PLUGIN_EXPORT int muxer(const char *video_filename,
                            const char *audio_filename,
                            const char *output_filename) {
  AVFormatContext *video_fmt_ctx = NULL, *audio_fmt_ctx = NULL, *output_fmt_ctx;
  AVStream *video_out_stream, *audio_out_stream;
  AVPacket packet;
  int ret, video_index = 0, audio_index = 1;
  int video_stream_index = -1, audio_stream_index = -1;

  // Open video file
  if ((ret = avformat_open_input(&video_fmt_ctx, video_filename, NULL, NULL)) <
      0) {
    platform_log(LOG_LEVEL_ERROR, "Could not open video file\n");
    return -1;
  }
  if ((ret = avformat_find_stream_info(video_fmt_ctx, NULL)) < 0) {
    platform_log(LOG_LEVEL_ERROR, "Could not retrieve video stream info\n");
    return -1;
  }

  // Open audio file
  if ((ret = avformat_open_input(&audio_fmt_ctx, audio_filename, NULL, NULL)) <
      0) {
    platform_log(LOG_LEVEL_ERROR, "Could not open audio file\n");
    return -1;
  }
  if ((ret = avformat_find_stream_info(audio_fmt_ctx, NULL)) < 0) {
    platform_log(LOG_LEVEL_ERROR, "Could not retrieve audio stream info\n");
    return -1;
  }

  /* allocate the output media context */
  avformat_alloc_output_context2(&output_fmt_ctx, NULL, NULL, output_filename);
  if (!output_fmt_ctx) {
    platform_log(
        LOG_LEVEL_DEBUG,
        "Could not deduce output format from file extension: using MPEG.\n");
    avformat_alloc_output_context2(&output_fmt_ctx, NULL, "mpeg",
                                   output_filename);
  }
  if (!output_fmt_ctx) return 1;

  /* Add the audio and video streams using the default format codecs
   * and initialize the codecs. */

  // Add video stream to output
  for (int i = 0; i < video_fmt_ctx->nb_streams; i++) {
    if (video_fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      AVStream *in_stream = video_fmt_ctx->streams[i];
      video_out_stream = avformat_new_stream(output_fmt_ctx, NULL);
      avcodec_parameters_copy(video_out_stream->codecpar, in_stream->codecpar);
      video_out_stream->codecpar->codec_tag = 0;
      video_stream_index = i;
      break;
    }
  }

  // Add audio stream to output
  for (int i = 0; i < audio_fmt_ctx->nb_streams; i++) {
    if (audio_fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      AVStream *in_stream = audio_fmt_ctx->streams[i];
      audio_out_stream = avformat_new_stream(output_fmt_ctx, NULL);
      avcodec_parameters_copy(audio_out_stream->codecpar, in_stream->codecpar);
      audio_out_stream->codecpar->codec_tag = 0;
      audio_stream_index = i;
      break;
    }
  }

  // Show general information about output format context
  av_dump_format(output_fmt_ctx, 0, output_filename, 1);

  /* open the output file, if needed */
  if (!(output_fmt_ctx->oformat->flags & AVFMT_NOFILE)) {
    ret = avio_open(&output_fmt_ctx->pb, output_filename, AVIO_FLAG_WRITE);
    if (ret < 0) {
      platform_log(LOG_LEVEL_ERROR, "Could not open '%s': %s\n",
                   output_filename, av_err2str(ret));
      return 1;
    }
  }

  /* Write the stream header, if any. */
  ret = avformat_write_header(output_fmt_ctx, NULL);
  if (ret < 0) {
    platform_log(LOG_LEVEL_ERROR,
                 "Error occurred when opening output file: %s\n",
                 av_err2str(ret));
    return 1;
  }

  // Read and write packets from video file
  while (av_read_frame(video_fmt_ctx, &packet) >= 0) {
    if (packet.stream_index == video_stream_index) {
      packet.stream_index = video_index;
      av_packet_rescale_ts(
          &packet, video_fmt_ctx->streams[video_stream_index]->time_base,
          video_out_stream->time_base);
      log_packet(output_fmt_ctx, &packet, "Video");
      av_interleaved_write_frame(output_fmt_ctx, &packet);
    }
    av_packet_unref(&packet);
  }

  // Read and write packets from audio file
  while (av_read_frame(audio_fmt_ctx, &packet) >= 0) {
    if (packet.stream_index == audio_stream_index) {
      packet.stream_index = audio_index;
      av_packet_rescale_ts(
          &packet, audio_fmt_ctx->streams[audio_stream_index]->time_base,
          audio_out_stream->time_base);
      log_packet(output_fmt_ctx, &packet, "Audio");
      av_interleaved_write_frame(output_fmt_ctx, &packet);
    }
    av_packet_unref(&packet);
  }

  // Write trailer
  av_write_trailer(output_fmt_ctx);

  // Cleanup
  avformat_close_input(&video_fmt_ctx);
  avformat_close_input(&audio_fmt_ctx);
  if (!(output_fmt_ctx->flags & AVFMT_NOFILE)) /* Close the output file. */
    avio_closep(&output_fmt_ctx->pb);

  /* free the stream */
  avformat_free_context(output_fmt_ctx);

  platform_log(LOG_LEVEL_DEBUG, "Muxing completed successfully!\n");
  return 0;
}

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b) { return a + b; }

// A longer-lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b) {
  // Simulate work.
#if _WIN32
  Sleep(5000);
#else
  usleep(5000 * 1000);
#endif
  return a + b;
}
