import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Position? p;
  CameraController? controller;
  List<CameraDescription>? _cameras;
  bool isEnable = true;
  bool isLoading = false;
  int indexCam = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController? oldController = controller;
    if (oldController != null) {
      controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        // showInSnackBar(
        //     'Camera error ${cameraController.value.errorDescription}');
      }
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled =
    await Geolocator.isLocationServiceEnabled().whenComplete(() => null);
    if (!serviceEnabled && !kIsWeb) {
      await Geolocator.openLocationSettings()
          .whenComplete(() => toggleLoading());
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission().whenComplete(() => null);
    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission().whenComplete(() => null);
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition().whenComplete(() => null);
  }

  void reqGeo() async {
    toggleLoading(load: true);
    if (!kIsWeb) {
      await Permission.locationWhenInUse.request();
    }
    _determinePosition().then((value) {
      p = value;
    })
    // .timeout(const Duration(seconds: 3))
        .whenComplete(() => toggleLoading());
  }

  void reqCam() async {
    toggleLoading(load: true);
    if (!kIsWeb) {
      await Permission.camera.request();
    }
    _cameras = await availableCameras().whenComplete(() => toggleLoading());
    if (_cameras!.length > 1) {
      indexCam = (indexCam - 1).abs();
    }
    controller = CameraController(_cameras![indexCam], ResolutionPreset.max);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            openAppSettings();
            print("AKSES KAMERA DITOLAK");
            break;
          default:
            print("AKSES KAMERA ERROR : ${e.code}");
            break;
        }
      }
    }).whenComplete(() => toggleLoading());
  }

  Widget cam() {
    if (controller != null && controller!.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            alignment: Alignment.topCenter,
            width: 1000,
            child: CameraPreview(controller!),
          ),
          if (_cameras!.length > 1)
            IconButton(
              onPressed: () => reqCam(),
              icon: const Icon(
                Icons.cameraswitch,
                color: Colors.white,
                size: 50,
              ),
            ),
        ],
      );
    }
    return const Text("BLANK CAMERA");
  }

  void toggleLoading({bool load = false}) {
    setState(() {
      isEnable = !load;
      isLoading = load;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Deasy Webview'),
          centerTitle: true,
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("LATITUDE : ${p?.altitude}"),
                Text("LONGITUDE : ${p?.longitude}"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => isEnable ? reqGeo() : null,
                  child: const Text("Location"),
                ),
                const SizedBox(width: 50),
                ElevatedButton(
                  onPressed: () => isEnable ? reqCam() : null,
                  child: const Text("Camera"),
                ),
                const SizedBox(width: 50),
                ElevatedButton(
                  onPressed: () async => await launchUrl(
                    Uri.parse("https://flutter.dev"),
                    mode: LaunchMode.inAppWebView,
                    webOnlyWindowName: "_self",
                  ),
                  child: const Text("Callback"),
                ),
              ],
            ),
            isLoading
                ? const LinearProgressIndicator(minHeight: 20)
                : const SizedBox(height: 10),
            cam(),
          ],
        ),
      ),
    );
  }
}
