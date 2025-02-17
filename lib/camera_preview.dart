import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_status.dart';

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

  Future<PermissionStatusEnum>? cameraPermissionFtrBldr;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    cameraPermissionFtrBldr = initializeCameraPermission();
  }

  Future<PermissionStatusEnum> initializeCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
      return PermissionStatusEnum.granted;
    } else if (status.isDenied) {
      return PermissionStatusEnum.denied;
    } else if (status.isPermanentlyDenied) {
      return PermissionStatusEnum.permanentlyDenied;
    } else {
      return PermissionStatusEnum.unknown;
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

  Future<void> _captureImage() async {
    if (!_controller!.value.isInitialized) return;

    final XFile image = await _controller!.takePicture();
    print("Image captured: ${image.path}");

    var data = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(imagePath: image.path),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<PermissionStatusEnum>(
        future: cameraPermissionFtrBldr,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data == PermissionStatusEnum.granted) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_isCameraInitialized)
                  Positioned.fill(child: CameraPreview(_controller!))
                else
                  Center(child: CircularProgressIndicator()),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Controls with larger icons and shadow/glow effect
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flash Button with shadow/glow effect
                      AnimatedScale(
                        duration: Duration(milliseconds: 300),
                        scale: _flashScale,
                        child: IconButton(
                          icon: Icon(
                            _controller!.value.flashMode == FlashMode.auto
                                ? Icons.flash_auto
                                : _controller!.value.flashMode ==
                                        FlashMode.torch
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                            color: Colors.white,
                            size: 40,
                          ),
                          onPressed: () {
                            _toggleFlash();
                          },
                        ),
                      ),
                      // IconButton(
                      //   icon: Icon(
                      //     _controller!.value.flashMode == FlashMode.auto
                      //         ? Icons.flash_auto
                      //         : _controller!.value.flashMode == FlashMode.torch
                      //         ? Icons.flash_on
                      //         : Icons.flash_off,
                      //     color: Colors.white,
                      //     size: 36,
                      //   ),
                      //   onPressed: _toggleFlash,
                      // ),

                      // Zoom controls and capture button
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              duration: Duration(milliseconds: 300),
                              scale: _zoomInScale,
                              child: IconButton(
                                icon: Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 36,
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
                                    size: 80,
                                  ),
                                  Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 65,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 20),
                            AnimatedScale(
                              duration: Duration(milliseconds: 300),
                              scale: _zoomOutScale,
                              child: IconButton(
                                icon: Icon(
                                  Icons.zoom_out,
                                  color: Colors.white,
                                  size: 36,
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
                            size: 36,
                          ),
                          onPressed: _switchCamera,
                        ),
                      ),
                    ],
                  ),
                ),
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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

  double _scale = 1.0;
  double _previousScale = 1.0;

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
    Matrix4? _endMatrix;
    Offset _position = _doubleTapDetails!.localPosition;

    if (_transformationController.value != Matrix4.identity()) {
      _endMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0);

      // For a 3x zoom
      // _transformationController.value = Matrix4.identity()
      //   ..translate(-position.dx * 2, -position.dy * 2)
      //   ..scale(3.0);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: _endMatrix,
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
              scale: _scale,
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
