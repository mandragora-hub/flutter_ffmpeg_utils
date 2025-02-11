import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ffmpeg_utils_example/utils.dart';
import 'dart:async';

import 'package:ffmpeg_utils/ffmpeg_utils.dart' as ffmpeg_utils;
import 'package:window_size/window_size.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  setupWindow();

  runApp(const MyApp());
}

const double windowWidth = 480;
const double windowHeight = 854;

void setupWindow() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    WidgetsFlutterBinding.ensureInitialized();
    setWindowTitle('Navigation and routing');
    setWindowMinSize(const Size(windowWidth, windowHeight));
    setWindowMaxSize(const Size(windowWidth, windowHeight));
    getCurrentScreen().then((screen) {
      setWindowFrame(Rect.fromCenter(
        center: screen!.frame.center,
        width: windowWidth,
        height: windowHeight,
      ));
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _messangerKey = GlobalKey<ScaffoldMessengerState>();

  late int sumResult;
  late Future<int> sumAsyncResult;

  final myController = TextEditingController();
  YoutubeDownloader downloader = YoutubeDownloader();

  void download(final String url) async {
    YoutubeExplode yt = YoutubeExplode();

    Video video = await yt.videos.get(url);
    print(video.title);

    StreamManifest manifest = await yt.videos.streams.getManifest(video.id);
    print(manifest);

    AudioOnlyStreamInfo audioOnlyStreamInfo =
        manifest.audioOnly.withHighestBitrate();
    print(audioOnlyStreamInfo);

    VideoOnlyStreamInfo videoOnlyStreamInfo =
        manifest.videoOnly.withHighestBitrate();
    print(videoOnlyStreamInfo);

    downloader.download(video.title, audioOnlyStreamInfo, videoOnlyStreamInfo);

    yt.close();
  }

  double progress = 0;
  late String downloaderStatus = downloader.status;

  void updateProgress() {
    setState(() {
      downloaderStatus = downloader.status;
      progress = downloader.progress;
    });
  }

  @override
  void initState() {
    super.initState();

    myController.text = "https://www.youtube.com/watch?v=0zivnTIKwMw";

    sumResult = ffmpeg_utils.sum(1, 2);
    sumAsyncResult = ffmpeg_utils.sumAsync(3, 4);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      scaffoldMessengerKey: _messangerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Text(
                  'sum(1, 2) = $sumResult',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                FutureBuilder<int>(
                  future: sumAsyncResult,
                  builder: (BuildContext context, AsyncSnapshot<int> value) {
                    final displayValue =
                        (value.hasData) ? value.data : 'loading';
                    return Text(
                      'await sumAsync(3, 4) = $displayValue',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56.0),
                  child: Divider(
                    height: 5,
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: Icon(Icons.clear),
                    labelText: 'Youtube URL',
                    hintText: 'Youtube link',
                    filled: true,
                  ),
                  controller: myController,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: () async {
                          download(myController.text);
                          Timer.periodic(Duration(seconds: 1), (timer) {
                            updateProgress();
                            // debugPrint(timer.tick.toString());
                            if (downloader.status == "Done" ||
                                downloader.status == "Error") {
                              _messangerKey.currentState?.showSnackBar(SnackBar(
                                  content: Text("Video download successflly")));

                              timer.cancel();
                            }
                          });
                        },
                        child: const Text('Download audio and video'),
                      ),
                      Tooltip(
                        message:
                            "Useful for test the platform log. check you console.",
                        child: FilledButton.tonal(
                          onPressed: () {
                            ffmpeg_utils.showCodecs();
                            _messangerKey.currentState?.showSnackBar(
                                SnackBar(content: Text("Check you console.")));
                          },
                          child: const Text('Log Codecs'),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Status: $downloaderStatus, Progress: ${progress.toStringAsFixed(2)}%',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
