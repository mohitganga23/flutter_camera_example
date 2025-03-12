import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;

  bool _isCameraInitialized = false;

  int _selectedCameraIndex = 0;
  double _zoomLevel = 1.0;

  double _flashScale = 1.0;
  double _zoomInScale = 1.0;
  double _zoomOutScale = 1.0;
  double _switchCameraScale = 1.0;

  Future<PermissionStatus>? cameraPermissionFtrBldr;

  ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    cameraPermissionFtrBldr = initializeCameraPermission();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<PermissionStatus> initializeCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
      return PermissionStatus.granted;
    } else if (status.isDenied) {
      return PermissionStatus.denied;
    } else if (status.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    } else {
      return PermissionStatus.permanentlyDenied;
    }
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras!.isNotEmpty) {
      _controller = CameraController(
        cameras![_selectedCameraIndex],
        ResolutionPreset.ultraHigh,
      );
      await _controller!.initialize();
      setState(() => _isCameraInitialized = true);
    }
  }

  void _toggleFlash() async {
    if (_controller != null && _controller!.value.isInitialized) {
      List<FlashMode> flashModes = [
        FlashMode.auto,
        FlashMode.torch,
        FlashMode.off
      ];

      int currentIndex = flashModes.indexOf(_controller!.value.flashMode);
      int nextIndex = (currentIndex + 1) % flashModes.length;

      await _controller!.setFlashMode(flashModes[nextIndex]);

      setState(() => _flashScale = 1.1);
      Future.delayed(Duration(milliseconds: 300), () {
        setState(() => _flashScale = 1.0);
      });
    }
  }

  void _zoomIn() async {
    if (_controller != null) {
      _zoomLevel = (_zoomLevel + 0.1).clamp(1.0, 8.0);
      await _controller!.setZoomLevel(_zoomLevel);

      setState(() => _zoomInScale = 1.1);
      Future.delayed(Duration(milliseconds: 300), () {
        setState(() => _zoomInScale = 1.0);
      });
    }
  }

  void _zoomOut() async {
    if (_controller != null) {
      _zoomLevel = (_zoomLevel - 0.1).clamp(1.0, 8.0);
      await _controller!.setZoomLevel(_zoomLevel);

      setState(() => _zoomOutScale = 1.1);

      Future.delayed(Duration(milliseconds: 300), () {
        setState(() => _zoomOutScale = 1.0);
      });
    }
  }

  void _switchCamera() async {
    if (cameras != null && cameras!.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
      await _controller?.dispose();
      await _initializeCamera();

      setState(() => _switchCameraScale = 1.1);

      Future.delayed(Duration(milliseconds: 300), () {
        setState(() => _switchCameraScale = 1.0);
      });
    }
  }

  Future<void> _captureImage() async {
    if (!_controller!.value.isInitialized) return;

    final XFile image = await _controller!.takePicture();
    print("Image captured: ${image.path}");

    Position currentPosition = await _determinePosition();

    File cI = File(image.path);

    Uint8List cU = await screenshotController.captureFromWidget(
      imageCapture(
        file: cI,
        latitude: currentPosition.latitude.toStringAsFixed(6),
        longitude: currentPosition.longitude.toStringAsFixed(6),
      ),
    );

    String dir = (await getTemporaryDirectory()).path;
    String filePath = "$dir/${DateTime.now().millisecondsSinceEpoch}.jpg";

    File finalImage = File(filePath);
    await finalImage.writeAsBytes(cU);

    var data = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(imagePath: finalImage.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<PermissionStatus>(
        future: cameraPermissionFtrBldr,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data == PermissionStatus.granted) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isCameraInitialized
                    ? Expanded(
                        child: CameraPreview(
                          _controller!,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppBar(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                automaticallyImplyLeading: true,
                                leading: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Icon(
                                    CupertinoIcons.arrow_left_circle_fill,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(color: Colors.black),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Flash Button with shadow/glow effect
                                    AnimatedScale(
                                      duration: Duration(milliseconds: 300),
                                      scale: _flashScale,
                                      child: IconButton(
                                        icon: Icon(
                                          _controller!.value.flashMode ==
                                                  FlashMode.auto
                                              ? Icons.flash_auto
                                              : _controller!.value.flashMode ==
                                                      FlashMode.torch
                                                  ? Icons.flash_on
                                                  : Icons.flash_off,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () {
                                          _toggleFlash();
                                        },
                                      ),
                                    ),

                                    // Zoom controls and capture button
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedScale(
                                            duration:
                                                Duration(milliseconds: 300),
                                            scale: _zoomInScale,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                              onPressed: _zoomIn,
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          InkWell(
                                            onTap: _captureImage,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  color: Colors.white38,
                                                  size: 65,
                                                ),
                                                Icon(
                                                  Icons.circle,
                                                  color: Colors.white,
                                                  size: 50,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          AnimatedScale(
                                            duration:
                                                Duration(milliseconds: 300),
                                            scale: _zoomOutScale,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.zoom_out,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                              onPressed: _zoomOut,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Camera switch button with shadow/glow effect
                                    AnimatedScale(
                                      duration: Duration(milliseconds: 300),
                                      scale: _switchCameraScale,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.cameraswitch,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: _switchCamera,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(child: CircularProgressIndicator()),
              ],
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera, size: 50, color: Colors.red),
                  SizedBox(height: 20),
                  Text(
                    'Camera permission is required to use this app',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final status = await Permission.camera.request();
                      if (status.isGranted) {
                        setState(
                          () => cameraPermissionFtrBldr =
                              initializeCameraPermission(),
                        );
                      }
                    },
                    child: Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget imageCapture({
    required File file,
    required String latitude,
    required String longitude,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            file,
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Latitude: $latitude",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                Text(
                  "Longitude: $longitude",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                Text(
                  "Date: ${DateTime.now().toString()}",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog(
        'Location services are disabled.',
        'Enable Location',
        () async {
          await Geolocator.openLocationSettings();
        },
      );
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog(
          'Location permissions are denied.',
          'Request Permission',
          () async {
            await Geolocator.requestPermission();
          },
        );
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationDialog(
        'Location permissions are permanently denied. Please enable them in settings.',
        'Open Settings',
        () async {
          await openAppSettings();
        },
      );
      return Future.error('Location permissions are permanently denied.');
    }

    // Permissions are granted, fetch location
    return await Geolocator.getCurrentPosition();
  }

  void _showLocationDialog(
    String message,
    String actionLabel,
    VoidCallback onActionPress,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Location Permission Dialog",
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text("Permission Required"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onActionPress();
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Tween<double>(
            begin: 0.5,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOutBack)).evaluate(anim1),
          child: child,
        );
      },
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<Matrix4>? _animation;

  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  double scale = 1.0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _animationController!.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    Matrix4? endMatrix;

    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController!),
    );
    _animationController!.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Center(
        child: GestureDetector(
          onDoubleTapDown: (d) => _doubleTapDetails = d,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 3.0,
            scaleEnabled: true,
            child: Transform.scale(
              scale: scale,
              child: Image.file(File(widget.imagePath)),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context, null),
              icon: const Icon(
                Icons.clear_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, widget.imagePath),
              icon: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
