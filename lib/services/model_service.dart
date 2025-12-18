
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class ModelService {
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isInitialized = false;

  // Initialize the model
  Future<void> initializeModel() async {
    try {
      // Load model from assets
      _interpreter = await Interpreter.fromAsset('assets/models/model_unquant.tflite');
      
      // Load labels (create a labels.txt file with your class names)
      _labels = await _loadLabels();
      
      _isInitialized = true;
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  // Load labels from assets
  Future<List<String>> _loadLabels() async {
    final labelsData = await rootBundle.loadString('assets/models/labels.txt');
    return labelsData.split('\n').where((label) => label.isNotEmpty).toList();
  }

  // Run inference on image
  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    if (!_isInitialized) {
      await initializeModel();
    }

    try {
      // Preprocess image
      final input = await _preprocessImage(imageFile);
      
      // Prepare output buffer with batch dimension [1, numClasses]
      final output = List<List<double>>.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );
      
      // Run inference
      _interpreter.run(input, output);
      
      // Process results (flatten the output)
      final results = _processResults(output[0]);
      
      return {
        'success': true,
        'predictions': results,
        'topPrediction': results[0],
      };
    } catch (e) {
      print('Classification failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Preprocess image for model input
  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    try {
      // Read and decode the actual image from file
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Center-crop to square (preserve subject) then resize to model input size (224x224)
      final int cropSize = image.width < image.height ? image.width : image.height;
      final int offsetX = ((image.width - cropSize) / 2).round();
      final int offsetY = ((image.height - cropSize) / 2).round();
      
      // copyCrop signature: copyCrop(Image src, {required int x, required int y, required int width, required int height})
      final cropped = img.copyCrop(image, x: offsetX, y: offsetY, width: cropSize, height: cropSize);
      final resized = img.copyResize(cropped, width: 224, height: 224);
      
      // Normalize the resized image
      final normalizedImage = _normalizeImage(resized);
      
      return normalizedImage;
    } catch (e) {
      print('Error preprocessing image: $e');
      // Return a default image on error
      return _createDummyImage();
    }
  }
  
  // Create a dummy image for fallback
  List<List<List<List<double>>>> _createDummyImage() {
    final imageData = List<List<List<int>>>.generate(
      224,
      (_) => List<List<int>>.generate(
        224,
        (_) => [128, 128, 128], // RGB channels
      ),
    );
    return _normalizeImageFromList(imageData);
  }

  // Normalize pixel values from img.Image
  List<List<List<List<double>>>> _normalizeImage(img.Image image) {
    final List<List<List<List<double>>>> batchInput = [];
    final List<List<List<double>>> input = [];
    
    for (int y = 0; y < image.height; y++) {
      final List<List<double>> row = [];
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        
        // Extract RGB from Pixel object (image 4.3.0 API)
        // Pixel has r, g, b properties
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        
        // Normalize to 0-1 range for floating-point model
        final List<double> channels = [
          r / 255.0,  // Red
          g / 255.0,  // Green
          b / 255.0,  // Blue
        ];
        row.add(channels);
      }
      input.add(row);
    }
    
    batchInput.add(input); // Add batch dimension
    return batchInput;
  }

  // Normalize pixel values from list format
  List<List<List<List<double>>>> _normalizeImageFromList(List<List<List<int>>> image) {
    final List<List<List<List<double>>>> batchInput = [];
    final List<List<List<double>>> input = [];
    
    for (int y = 0; y < image.length; y++) {
      final List<List<double>> row = [];
      for (int x = 0; x < image[y].length; x++) {
        final pixelChannels = image[y][x];
        final List<double> channels = [
          (pixelChannels[0]) / 255.0,  // Red
          (pixelChannels[1]) / 255.0,  // Green
          (pixelChannels[2]) / 255.0,  // Blue
        ];
        row.add(channels);
      }
      input.add(row);
    }
    
    batchInput.add(input); // Add batch dimension
    return batchInput;
  }

  // Process model output (floating-point)
  List<Map<String, dynamic>> _processResults(List<double> output) {
    final List<Map<String, dynamic>> predictions = [];
    
    // For floating-point models, values are already normalized (0-1 range)
    for (int i = 0; i < output.length && i < _labels.length; i++) {
      predictions.add({
        'label': _labels[i],
        'confidence': output[i].clamp(0.0, 1.0), // Ensure values are in 0-1 range
      });
    }
    
    // Sort by confidence descending
    predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    
    return predictions.take(5).toList(); // Return top 5 predictions
  }

  // Dispose resources
  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
    }
  }
}

