import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize();

  runApp(const DownloadApp());
}

class DownloadApp extends StatelessWidget {
  const DownloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Downloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int progress = 0;
  bool isDownloading = false;

  ReceivePort receivePort = ReceivePort();

  @override
  void initState() {
    IsolateNameServer.registerPortWithName(
        receivePort.sendPort, "downloadFile");

    receivePort.listen((message) {
      setState(() {
        progress = message;
      });
      debugPrint("Download progress: $message");
      if (progress == 100) {
        setState(() {
          isDownloading = false;
        });
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);

    super.initState();
  }

  @pragma('vm:entry-point')
  static downloadCallback(id, status, progress) {
    SendPort? sendPort = IsolateNameServer.lookupPortByName("downloadFile");

    sendPort?.send(progress);
  }

  Future<void> fileDownloader() async {
    bool isPermissionGranted = await getPermission();

    if (!isPermissionGranted) {
      debugPrint("No permission");

      isPermissionGranted = await getPermission();
      return;
    }

    setState(() {
      isDownloading = true;
    });

    Directory? basePath =
        await Future.value(Directory("/storage/emulated/0/Download"));

    if (Platform.isIOS) {
      basePath = await getExternalStorageDirectory();
    }
    const url =
        "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";

    // const url =
    //     "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4";

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: basePath!.path,
      fileName: "video",
      allowCellular: true,
      saveInPublicStorage: true,
      showNotification: true,
      openFileFromNotification: true,
    );
  }

  Future<bool> getPermission() async {
    final statuses = await [
      Permission.manageExternalStorage,
      Permission.audio,
      Permission.videos,
      Permission.photos,
      Permission.accessNotificationPolicy,
      Permission.notification,
    ].request();

    return statuses[Permission.videos] == PermissionStatus.granted &&
        statuses[Permission.audio] == PermissionStatus.granted &&
        statuses[Permission.photos] == PermissionStatus.granted &&
        statuses[Permission.manageExternalStorage] ==
            PermissionStatus.granted &&
        statuses[Permission.notification] == PermissionStatus.granted &&
        statuses[Permission.accessNotificationPolicy] ==
            PermissionStatus.granted;
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    receivePort.close();
    isDownloading = false;
    progress = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Home"),
      ),
      body: Center(
        child: isDownloading
            ? Stack(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 15,
                    strokeCap: StrokeCap.butt,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    semanticsLabel: "fd",
                    strokeAlign: 3,
                    value: progress / 100,
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    left: 0,
                    child: Center(
                      child: Text(
                        "$progress%",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ],
              )
            : ElevatedButton(
                // onPressed: () {
                //   setState(() {
                //     isDownloading = true;
                //   });
                // },
                onPressed: fileDownloader,
                child: const Text("Download"),
              ),
      ),
    );
  }
}
