import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/voice_transform_service.dart';
import '../../widgets/glassmorphism_widgets.dart';

class VoiceEffectsPage extends StatefulWidget {
  final String audioPath;
  final Duration originalDuration;

  const VoiceEffectsPage({
    super.key,
    required this.audioPath,
    required this.originalDuration,
  });

  @override
  State<VoiceEffectsPage> createState() => _VoiceEffectsPageState();
}

class _VoiceEffectsPageState extends State<VoiceEffectsPage>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _effectPreviewController;
  
  List<VoiceEffect> _availableEffects = [];
  VoiceEffect? _selectedEffect;
  String? _transformedAudioPath;
  double _intensity = 1.0;
  bool _isLoading = false;
  bool _isTransforming = false;
  bool _isPreviewPlaying = false;
  bool _serviceAvailable = false;
  String? _errorMessage;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _effectPreviewController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _initializeService();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _effectPreviewController.dispose();
    _audioPlayer.dispose();
    
    // Clean up transformed audio file
    if (_transformedAudioPath != null) {
      VoiceTransformService.cleanupTransformedFile(_transformedAudioPath!);
    }
    
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPreviewPlaying = false;
      });
    });
  }

  Future<void> _initializeService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if service is available
      _serviceAvailable = await VoiceTransformService.isServiceAvailable();
      
      if (_serviceAvailable) {
        // Get available effects
        _availableEffects = await VoiceTransformService.getAvailableEffects();
      } else {
        _availableEffects = VoiceTransformService.freeEffects;
        _errorMessage = 'Voice effects service is offline. Only basic effects available.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load voice effects: ${e.toString()}';
      _availableEffects = VoiceTransformService.freeEffects;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectEffect(VoiceEffect effect) async {
    setState(() {
      _selectedEffect = effect;
      _transformedAudioPath = null;
    });

    // Check if it's a premium effect and user doesn't have access
    if (effect.isPaid && !VoiceTransformService.hasPremiumAccess()) {
      _showPremiumDialog();
      return;
    }

    // Auto-preview the effect
    await _previewEffect();
  }

  Future<void> _previewEffect() async {
    if (_selectedEffect == null) return;

    setState(() {
      _isTransforming = true;
      _errorMessage = null;
    });

    _loadingController.repeat();

    try {
      final result = await VoiceTransformService.transformAudio(
        audioFilePath: widget.audioPath,
        effectId: _selectedEffect!.id,
        intensity: _intensity,
      );

      if (result.success && result.transformedFilePath != null) {
        // Clean up previous transformed file
        if (_transformedAudioPath != null) {
          VoiceTransformService.cleanupTransformedFile(_transformedAudioPath!);
        }

        setState(() {
          _transformedAudioPath = result.transformedFilePath;
        });

        // Auto-play preview
        await _playPreview();
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Preview failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTransforming = false;
      });
      _loadingController.stop();
    }
  }

  Future<void> _playPreview() async {
    try {
      final audioPath = _transformedAudioPath ?? widget.audioPath;
      
      if (_isPreviewPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPreviewPlaying = false;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(audioPath));
        setState(() {
          _isPreviewPlaying = true;
        });
        _effectPreviewController.forward();
      }
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  Future<void> _applyEffect() async {
    if (_selectedEffect == null) {
      Navigator.pop(context);
      return;
    }

    // If we already have a transformed file, use it
    if (_transformedAudioPath != null) {
      Navigator.pop(context, {
        'confirmed': true,
        'effectId': _selectedEffect!.id,
        'transformedPath': _transformedAudioPath,
        'intensity': _intensity,
      });
      return;
    }

    // Otherwise, transform the audio
    setState(() {
      _isTransforming = true;
      _errorMessage = null;
    });

    _loadingController.repeat();

    try {
      final result = await VoiceTransformService.transformAudio(
        audioFilePath: widget.audioPath,
        effectId: _selectedEffect!.id,
        intensity: _intensity,
      );

      if (result.success && result.transformedFilePath != null) {
        Navigator.pop(context, {
          'confirmed': true,
          'effectId': _selectedEffect!.id,
          'transformedPath': result.transformedFilePath,
          'intensity': _intensity,
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to apply effect: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTransforming = false;
      });
      _loadingController.stop();
    }
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: const Text(
          'Premium Effect',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This voice effect is part of our premium collection.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            GlassmorphismButton(
              onPressed: () async {
                Navigator.pop(context);
                // TODO: Implement premium purchase
                final purchased = await VoiceTransformService.purchasePremiumAccess();
                if (purchased) {
                  await _previewEffect();
                }
              },
              backgroundColor: Colors.black.withOpacity(0.8),
              child: const Text(
                'Unlock Premium Effects',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassmorphismAppBar(
        title: 'Voice Effects',
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a1a),
              Color(0xFF0d0d0d),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Preview Controls
                GlassmorphismContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _effectPreviewController,
                            builder: (context, child) {
                              return GestureDetector(
                                onTap: _playPreview,
                                child: GlassmorphismContainer(
                                  width: 60,
                                  height: 60,
                                  borderRadius: BorderRadius.circular(30),
                                  backgroundColor: _isPreviewPlaying
                                      ? Colors.red.withOpacity(0.6)
                                      : Colors.black.withOpacity(0.7),
                                  child: Transform.scale(
                                    scale: _isPreviewPlaying
                                        ? 1.0 + (_effectPreviewController.value * 0.1)
                                        : 1.0,
                                    child: Icon(
                                      _isPreviewPlaying ? Icons.stop : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (_selectedEffect != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _selectedEffect!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedEffect!.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Intensity Slider
                if (_selectedEffect != null)
                  GlassmorphismContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Effect Intensity',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'Subtle',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _intensity,
                                onChanged: (value) {
                                  setState(() {
                                    _intensity = value;
                                  });
                                },
                                onChangeEnd: (value) {
                                  // Auto-preview when slider changes
                                  _previewEffect();
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            const Text(
                              'Strong',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Effects List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _availableEffects.isEmpty
                          ? const Center(
                              child: Text(
                                'No effects available',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: _availableEffects.length,
                              itemBuilder: (context, index) {
                                final effect = _availableEffects[index];
                                final isSelected = _selectedEffect?.id == effect.id;
                                
                                return GestureDetector(
                                  onTap: () => _selectEffect(effect),
                                  child: GlassmorphismContainer(
                                    padding: const EdgeInsets.all(16),
                                    backgroundColor: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderColor: isSelected
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.white.withOpacity(0.2),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getEffectIcon(effect.id),
                                          color: isSelected ? Colors.white : Colors.white70,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          effect.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (effect.isPaid)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'PRO',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphismButton(
                        onPressed: () => Navigator.pop(context),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child:                       GlassmorphismButton(
                        onPressed: _isTransforming ? null : _applyEffect,
                        backgroundColor: Colors.black.withOpacity(0.7),
                        child: _isTransforming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _selectedEffect == null ? 'Skip Effects' : 'Apply Effect',
                                style: const TextStyle(
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
        ),
      ),
    );
  }

  IconData _getEffectIcon(String effectId) {
    switch (effectId) {
      case 'robot':
        return Icons.smart_toy;
      case 'child':
        return Icons.child_friendly;
      case 'deep':
        return Icons.graphic_eq;
      case 'alien':
        return Icons.science;
      case 'whisper':
        return Icons.volume_down;
      case 'monster':
        return Icons.pets;
      default:
        return Icons.audiotrack;
    }
  }
} 