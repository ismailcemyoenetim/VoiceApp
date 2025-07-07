import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../widgets/glassmorphism_widgets.dart';

class ProfilePhotoPreview extends StatefulWidget {
  final String imagePath;
  
  const ProfilePhotoPreview({
    super.key,
    required this.imagePath,
  });

  @override
  State<ProfilePhotoPreview> createState() => _ProfilePhotoPreviewState();
}

class _ProfilePhotoPreviewState extends State<ProfilePhotoPreview> {
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  Offset _currentTranslation = Offset.zero;
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;
  static const double _cropSize = 250.0; // Size of the crop circle
  
  ui.Image? _originalImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final File imageFile = File(widget.imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        _originalImage = frameInfo.image;
      });
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
  }

  void _resetTransformation() {
    setState(() {
      _currentScale = 1.0;
      _currentTranslation = Offset.zero;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _onScaleChanged(double scale) {
    setState(() {
      _currentScale = scale;
      final matrix = Matrix4.identity()
        ..scale(scale)
        ..translate(_currentTranslation.dx, _currentTranslation.dy);
      _transformationController.value = matrix;
    });
  }

  void _onInteractionUpdate() {
    final Matrix4 matrix = _transformationController.value;
    setState(() {
      _currentScale = matrix.getMaxScaleOnAxis();
      // Extract translation from matrix (matrix[12] = x, matrix[13] = y)
      _currentTranslation = Offset(matrix[12], matrix[13]);
    });
  }

  Future<String?> _cropAndSaveImage() async {
    if (_originalImage == null) return null;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final double imageWidth = _originalImage!.width.toDouble();
      final double imageHeight = _originalImage!.height.toDouble();
      
      // Create a fixed size square output (256x256 for profile photos)
      const int outputSize = 256;
      
      // Calculate visible area dimensions based on current scale and translation
      final double visibleWidth = ((_cropSize + 100) / _currentScale);
      final double visibleHeight = ((_cropSize + 100) / _currentScale);
      
      // Calculate the center point of the crop area in image coordinates
      final double centerX = (imageWidth / 2) - (_currentTranslation.dx / _currentScale);
      final double centerY = (imageHeight / 2) - (_currentTranslation.dy / _currentScale);
      
      // Calculate crop bounds (square crop area)
      final double cropRadius = (_cropSize / 2) / _currentScale;
      final double cropLeft = (centerX - cropRadius).clamp(0.0, imageWidth);
      final double cropTop = (centerY - cropRadius).clamp(0.0, imageHeight);
      final double cropRight = (centerX + cropRadius).clamp(0.0, imageWidth);
      final double cropBottom = (centerY + cropRadius).clamp(0.0, imageHeight);
      
      // Create a picture recorder to draw the cropped and circular image
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // Create circular clip path
      const double radius = outputSize / 2.0;
      final Path clipPath = Path()..addOval(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius)
      );
      canvas.clipPath(clipPath);
      
      // Define source and destination rectangles
      final Rect sourceRect = Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom);
      final Rect destRect = Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble());
      
      // Draw the image with high quality settings
      final Paint paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;
      
      canvas.drawImageRect(_originalImage!, sourceRect, destRect, paint);
      
      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(outputSize, outputSize);
      
      // Convert to PNG bytes
      final ByteData? byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('❌ Failed to convert image to bytes');
        return null;
      }
      
      // Save to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = path.join(tempDir.path, fileName);
      final File file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      debugPrint('🖼️ Cropped image saved to: $filePath');
      debugPrint('🖼️ Image dimensions: ${outputSize}x$outputSize');
      debugPrint('🖼️ Source crop: $sourceRect');
      
      // Clean up
      picture.dispose();
      croppedImage.dispose();
      
      return filePath;
      
    } catch (e) {
      debugPrint('❌ Error cropping image: $e');
      return null;
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Text(
          'Profile Photo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _originalImage == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                // Background image (blurred)
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(widget.imagePath)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Header controls
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: GlassmorphismContainer(
                          padding: const EdgeInsets.all(16),
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.crop_free,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Position and resize your photo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // Reset button
                                  GestureDetector(
                                    onTap: _resetTransformation,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Reset',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Pinch to zoom • Drag to reposition • Only the area inside the circle will be saved',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              // Zoom slider
                              Row(
                                children: [
                                  const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                                  Expanded(
                                    child: Slider(
                                      value: _currentScale,
                                      min: _minScale,
                                      max: _maxScale,
                                      divisions: 25,
                                      activeColor: Colors.blue,
                                      inactiveColor: Colors.white.withOpacity(0.3),
                                      onChanged: _onScaleChanged,
                                    ),
                                  ),
                                  const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Interactive crop area
                      Expanded(
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Interactive image
                              SizedBox(
                                width: _cropSize + 100, // Extra space for dragging
                                height: _cropSize + 100,
                                child: InteractiveViewer(
                                  transformationController: _transformationController,
                                  minScale: _minScale,
                                  maxScale: _maxScale,
                                  boundaryMargin: const EdgeInsets.all(50),
                                                                     onInteractionUpdate: (details) {
                                     _onInteractionUpdate();
                                   },
                                  child: Image.file(
                                    File(widget.imagePath),
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              
                              // Crop circle overlay
                              IgnorePointer(
                                child: Container(
                                  width: _cropSize + 100,
                                  height: _cropSize + 100,
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Dark overlay with hole
                                      Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: _cropSize,
                                            height: _cropSize,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(_cropSize / 2),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 10,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Cut out the circle
                                      ClipPath(
                                        clipper: _CircleHoleClipper(radius: _cropSize / 2),
                                        child: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Scale indicator and preview
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Scale indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Zoom: ${(_currentScale * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Action buttons
                            Row(
                              children: [
                                // Cancel button
                                Expanded(
                                  child: GlassmorphismButton(
                                    onPressed: () => Navigator.of(context).pop(null),
                                    backgroundColor: Colors.grey.withOpacity(0.3),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Use Photo button
                                Expanded(
                                  child: GlassmorphismButton(
                                    onPressed: _isProcessing
                                        ? null
                                        : () async {
                                            debugPrint('🖼️ Cropping and saving image...');
                                            final String? croppedPath = await _cropAndSaveImage();
                                            if (croppedPath != null) {
                                              Navigator.of(context).pop(croppedPath);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Failed to process image'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                    backgroundColor: _isProcessing
                                        ? Colors.grey.withOpacity(0.3)
                                        : Colors.blue.withOpacity(0.3),
                                    child: _isProcessing
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Processing...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Text(
                                            'Use Photo',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Custom clipper to create a hole in the overlay
class _CircleHoleClipper extends CustomClipper<Path> {
  final double radius;
  
  _CircleHoleClipper({required this.radius});
  
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Create hole in the center
    final Rect circle = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    path.addOval(circle);
    
    return path..fillType = PathFillType.evenOdd;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
} 