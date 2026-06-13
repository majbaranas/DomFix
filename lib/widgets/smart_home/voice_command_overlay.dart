import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/local_voice_assistant.dart';
import '../../theme/app_colors.dart';

class VoiceCommandOverlay extends StatefulWidget {
  const VoiceCommandOverlay({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceCommandOverlay(),
    );
  }

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay> with SingleTickerProviderStateMixin {
  String _transcription = "Listening...";
  String _feedback = "";
  bool _isProcessing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _startListening();
  }

  Future<void> _startListening() async {
    final assistant = LocalVoiceAssistant.instance;
    await assistant.startListening(
      onResult: (text) {
        if (mounted && text.isNotEmpty) setState(() => _transcription = text);
      },
      onDone: () async {
        if (mounted) setState(() {
          _isProcessing = true;
          _pulseController.stop();
        });
        
        final result = await assistant.processCommand(_transcription);
        
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _feedback = result ?? "Command not recognized";
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    LocalVoiceAssistant.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border(
            top: BorderSide(color: AppColors.whiteBorder5, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Pulsing Mic
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _feedback.isEmpty && !_isProcessing
                        ? AppColors.neonAccent.withValues(alpha: 0.05 + (_pulseController.value * 0.15))
                        : (_feedback == "Command not recognized" 
                            ? AppColors.error.withValues(alpha: 0.15) 
                            : AppColors.success.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _feedback.isEmpty && !_isProcessing
                            ? AppColors.neonAccent
                            : (_feedback == "Command not recognized" ? AppColors.error : AppColors.success),
                        boxShadow: [
                          BoxShadow(
                            color: (_feedback.isEmpty && !_isProcessing 
                                ? AppColors.neonAccent 
                                : (_feedback == "Command not recognized" ? AppColors.error : AppColors.success))
                                .withValues(alpha: 0.4),
                            blurRadius: 20 * (_feedback.isEmpty ? _pulseController.value : 1.0),
                            spreadRadius: 5 * (_feedback.isEmpty ? _pulseController.value : 1.0),
                          )
                        ],
                      ),
                      child: Icon(
                        _feedback.isEmpty
                            ? Icons.mic_rounded
                            : (_feedback == "Command not recognized" ? Icons.close_rounded : Icons.check_rounded),
                        color: AppColors.onPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            // Transcription
            Text(
              _transcription,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Feedback
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _feedback.isNotEmpty ? 1.0 : 0.0,
              child: Text(
                _feedback.isEmpty ? " " : _feedback,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _feedback == "Command not recognized" ? AppColors.error : AppColors.success,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
