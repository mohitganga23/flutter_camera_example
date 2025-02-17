import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  bool _isFlashOn = false;

  int _selectedCameraIndex = 0;
  double _zoomLevel = 1.0;

  Future<PermissionStatusEnum>? cameraPermissionFtrBldr;

  @override
  void initState() {
    super.initState();
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
        ResolutionPreset.high,
      );
      await _controller!.initialize();
      setState(() => _isCameraInitialized = true);
    }
  }

  void _toggleFlash() async {
    if (_controller != null && _controller!.value.isInitialized) {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    }
  }

  void _zoomIn() async {
    if (_controller != null) {
      _zoomLevel = (_zoomLevel + 0.1).clamp(1.0, 8.0);
      await _controller!.setZoomLevel(_zoomLevel);
      setState(() {});
    }
  }

  void _zoomOut() async {
    if (_controller != null) {
      _zoomLevel = (_zoomLevel - 0.1).clamp(1.0, 8.0);
      await _controller!.setZoomLevel(_zoomLevel);
      setState(() {});
    }
  }

  Future<void> _captureImage() async {
    if (!_controller!.value.isInitialized) return;
    final XFile image = await _controller!.takePicture();
    print("Image captured: ${image.path}");
  }

  void _switchCamera() async {
    if (cameras != null && cameras!.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
      await _controller?.dispose();
      await _initializeCamera();
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
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.flash_on,
                          color: _isFlashOn ? Colors.yellow : Colors.white,
                        ),
                        onPressed: _toggleFlash,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.zoom_in, color: Colors.white),
                              onPressed: _zoomIn,
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
                            IconButton(
                              icon: Icon(Icons.zoom_out, color: Colors.white),
                              onPressed: _zoomOut,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.cameraswitch, color: Colors.white),
                        onPressed: _switchCamera,
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
                  Text('Camera permission is required to use this app',
                      textAlign: TextAlign.center),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final status = await Permission.camera.request();
                      if (status.isGranted) {
                        setState(() => cameraPermissionFtrBldr =
                            initializeCameraPermission());
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
