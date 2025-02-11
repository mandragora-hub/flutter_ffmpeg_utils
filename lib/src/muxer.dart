import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'bindings.dart';

Future<int> muxerAsync(final String videoFilename, final String audioFilename,
    final String outputFilename) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextMuxerRequestId++;
  final _MuxerRequest request = _MuxerRequest(
      requestId,
      videoFilename.toNativeUtf8().cast<Char>(),
      audioFilename.toNativeUtf8().cast<Char>(),
      outputFilename.toNativeUtf8().cast<Char>());

  final Completer<int> completer = Completer<int>();
  _muxerRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

class _MuxerRequest {
  final int id;
  final Pointer<Char> videoFilenamePtr;
  final Pointer<Char> audioFilenamePtr;
  final Pointer<Char> outputFilenamePtr;

  const _MuxerRequest(this.id, this.videoFilenamePtr, this.audioFilenamePtr,
      this.outputFilenamePtr);

  void dispose() {
    calloc.free(videoFilenamePtr);
    calloc.free(audioFilenamePtr);
    calloc.free(outputFilenamePtr);
  }
}

class _MuxerResponse {
  final int id;
  final int result;

  const _MuxerResponse(this.id, this.result);
}

int _nextMuxerRequestId = 0;

final Map<int, Completer<int>> _muxerRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _MuxerResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _muxerRequests[data.id]!;
        _muxerRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _MuxerRequest) {
          final int result = bindings.muxer(data.videoFilenamePtr,
              data.audioFilenamePtr, data.outputFilenamePtr);

          final _MuxerResponse response = _MuxerResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
