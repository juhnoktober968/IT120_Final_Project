import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';
import 'services/model_service.dart';
import 'services/history_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class ClassifyPage extends StatefulWidget {
  const ClassifyPage({super.key});

  @override
  State<ClassifyPage> createState() => _ClassifyPageState();
}

class _ClassifyPageState extends State<ClassifyPage> with TickerProviderStateMixin {
  CameraController? _cameraController;
  final ImagePicker _imagePicker = ImagePicker();
  final ModelService _modelService = ModelService();
  
  List<CameraDescription>? _cameras;
  File? _selectedImage;
  List<Map<String, dynamic>>? _predictions;
  bool _isClassifying = false;
  bool _useLiveCamera = false;
  bool _flashOn = false;
  Timer? _classificationTimer;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Initialize model
    _modelService.initializeModel();
    
    // Initialize cameras (permission prompt will appear when user taps Live Camera)
    _initializeCameras();
  }

  /// Request camera permission and handle responses.
  /// If permanently denied, open app settings.
  /// If denied, offer to retry.
  Future<bool> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        return true;
      }

      final result = await Permission.camera.request();
      if (result.isGranted) {
        return true;
      }

      if (result.isPermanentlyDenied) {
        // Prompt user to open app settings
        if (!mounted) return false;
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera permission required'),
            content: const Text('Camera access is required for live classification. Open app settings to allow camera access?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Open Settings')),
            ],
          ),
        );

        if (open == true) {
          await openAppSettings();
        }
        return false;
      } else {
        // Denied (but not permanently). Offer to request again.
        if (!mounted) return false;
        final retry = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera access needed'),
            content: const Text('This feature needs camera access. Would you like to allow it now?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
            ],
          ),
        );

        if (retry == true) {
          return await _requestCameraPermission();
        }
        return false;
      }
    } catch (e) {
      print('Permission check failed: $e');
      return false;
    }
  }

  Future<String> _saveFileToAppDir(File file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/classified_images');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      final filename = 'cls_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${saveDir.path}/$filename';
      await file.copy(newPath);
      return newPath;
    } catch (e) {
      print('Error saving file to app dir: $e');
      return file.path;
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      print('Available cameras: ${_cameras?.length}');
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find back camera or use first available
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        await _initializeCamera(backCamera);
        setState(() {}); // Update UI after camera initialization
      } else {
        print('No cameras available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found on this device')),
          );
        }
      }
    } catch (e) {
      print('Error initializing cameras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing cameras: $e')),
        );
      }
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    try {
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      // Set flash mode to off by default
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera controller: $e');
    }
  }
  Future<void> _toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        if (_flashOn) {
          await _cameraController!.setFlashMode(FlashMode.off);
        } else {
          await _cameraController!.setFlashMode(FlashMode.torch);
        }
        setState(() => _flashOn = !_flashOn);
      } catch (e) {
        print('Error toggling flash: $e');
      }
    }
  }

  void _startRealTimeClassification() {
    // Stop any existing timer first
    _stopRealTimeClassification();
    
    _classificationTimer = Timer.periodic(
      const Duration(milliseconds: 800), // Classify every 800ms
      (_) async {
        if (!_useLiveCamera || _cameraController == null) {
          _classificationTimer?.cancel();
          return;
        }
        
        if (!_cameraController!.value.isInitialized || _cameraController!.value.isTakingPicture) {
          return;
        }

        try {
          final image = await _cameraController!.takePicture();
          final file = File(image.path);
          
          if (mounted && _useLiveCamera) {
            final result = await _modelService.classifyImage(file);
            
              if (mounted && _useLiveCamera) {
              if (result['success']) {
                setState(() {
                  _predictions = result['predictions'];
                });

                final top = (result['predictions'] as List).isNotEmpty ? result['predictions'][0] : null;
                if (top != null) {
                  try {
                    final savedPath = await _saveFileToAppDir(file);
                    HistoryService.instance.addRecord(
                      label: top['label'] as String,
                      confidence: (top['confidence'] as double),
                      imagePath: savedPath,
                    );
                  } catch (e) {
                    // fallback to temp path if saving fails
                    HistoryService.instance.addRecord(
                      label: top['label'] as String,
                      confidence: (top['confidence'] as double),
                      imagePath: file.path,
                    );
                  }
                }
              }
            }
            
            // Clean up temp file
            try {
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              print('Error deleting temp file: $e');
            }
          }
        } catch (e) {
          print('Error during real-time classification: $e');
        }
      },
    );
  }

  void _stopRealTimeClassification() {
    _classificationTimer?.cancel();
    _classificationTimer = null;
  }

  Future<void> _pickImageAndClassify({required ImageSource source}) async {
    try {
      _stopRealTimeClassification();
      setState(() => _useLiveCamera = false);
      
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isClassifying = true;
          _predictions = null;
        });
        
        await _classifyImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _classifyImage() async {
    if (_selectedImage == null) return;

    try {
      final result = await _modelService.classifyImage(_selectedImage!);
      
      if (mounted) {
        if (result['success']) {
          setState(() {
            _predictions = result['predictions'];
            _isClassifying = false;
          });

          final top = (result['predictions'] as List).isNotEmpty ? result['predictions'][0] : null;
          if (top != null) {
            HistoryService.instance.addRecord(
              label: top['label'] as String,
              confidence: (top['confidence'] as double),
              imagePath: _selectedImage!.path,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Classification failed: ${result['error']}')),
          );
          setState(() => _isClassifying = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isClassifying = false);
      }
    }
  }

  Future<void> _toggleLiveCamera() async {
    // If trying to enable live camera, request permission first
    if (!_useLiveCamera) {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        return; // Permission denied, don't enable camera
      }
    }

    if (_cameras == null || _cameras!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera is not initialized')),
      );
      return;
    }

    setState(() {
      _useLiveCamera = !_useLiveCamera;
      if (!_useLiveCamera) {
        _selectedImage = null;
        _predictions = null;
      }
    });
    
    if (_useLiveCamera) {
      print('Starting real-time classification');
      _startRealTimeClassification();
    } else {
      print('Stopping real-time classification');
      _stopRealTimeClassification();
    }
  }

  Widget _buildClassificationResult() {
    if (_predictions == null || _predictions!.isEmpty) {
      return const SizedBox.shrink();
    }

    final topPrediction = _predictions![0];
    final topConfidence = (topPrediction['confidence'] * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top prediction card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1),
                const Color(0xFF8B5CF6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Result',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                topPrediction['label'],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$topConfidence% Confidence',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // All predictions
        Text(
          'All Results',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ..._predictions!.map((prediction) {
          final confidence = (prediction['confidence'] * 100);
          final confidenceStr = confidence.toStringAsFixed(1);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        prediction['label'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$confidenceStr%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: confidence / 100.0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                        const Color(0xFF8B5CF6),
                        const Color(0xFF6366F1),
                        (confidence / 100.0) * 0.5,
                      )!,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCameraReady = _cameraController != null && 
                          _cameraController!.value.isInitialized;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classify an Image'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _useLiveCamera && isCameraReady
          ? _buildCameraView()
          : _buildImageView(),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera preview
        CameraPreview(_cameraController!),

        // Overlay with results
        SafeArea(
          child: Column(
            children: [
              // Top buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    FloatingActionButton(
                      mini: true,
                      onPressed: _toggleLiveCamera,
                      backgroundColor: Colors.black54,
                      child: const Icon(Icons.close),
                    ),
                    // Flash toggle button
                    FloatingActionButton(
                      mini: true,
                      onPressed: _toggleFlash,
                      backgroundColor: Colors.black54,
                      child: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Results display
              if (_predictions != null && _predictions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _predictions![0]['label'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_predictions![0]['confidence'] * 100).toStringAsFixed(1)}% Confidence',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Image preview
          Container(
            width: double.infinity,
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey[200],
              border: Border.all(
                color: const Color(0xFF6366F1),
                width: 2,
              ),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select an image to classify',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClassifying
                      ? null
                      : () => _pickImageAndClassify(source: ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isClassifying
                      ? null
                      : () => _pickImageAndClassify(source: ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live camera button
          // if (_cameras != null && _cameras!.isNotEmpty && _cameraController != null)
          //   SizedBox(
          //     width: double.infinity,
          //     child: ElevatedButton.icon(
          //       onPressed: _toggleLiveCamera,
          //       icon: const Icon(Icons.videocam),
          //       label: const Text('Live Camera'),
          //       style: ElevatedButton.styleFrom(
          //         padding: const EdgeInsets.symmetric(vertical: 14),
          //         backgroundColor: const Color(0xFF6366F1),
          //       ),
          //     ),
          //   )
          // else if (_cameras == null || _cameras!.isEmpty)
          //   SizedBox(
          //     width: double.infinity,
          //     child: ElevatedButton.icon(
          //       onPressed: null,
          //       icon: const Icon(Icons.videocam),
          //       label: const Text('Live Camera (Not Available)'),
          //       style: ElevatedButton.styleFrom(
          //         padding: const EdgeInsets.symmetric(vertical: 14),
          //       ),
          //     ),
          //   ),
          const SizedBox(height: 32),

          // Classification status
          if (_isClassifying)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Classifying...',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            )
          else
            _buildClassificationResult(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopRealTimeClassification();
    _cameraController?.dispose();
    _pulseController.dispose();
    _modelService.dispose();
    super.dispose();
  }
}