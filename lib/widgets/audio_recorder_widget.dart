import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(File audioFile, int duration) onAudioRecorded;
  final VoidCallback onCancel;

  const AudioRecorderWidget({
    super.key,
    required this.onAudioRecorded,
    required this.onCancel,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      _startRecording();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder!.startRecorder(
        toFile: _audioPath,
        codec: Codec.aacADTS,
      );
      
      setState(() => _isRecording = true);
      
      // Update duration every second
      while (_isRecording && mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (_isRecording && mounted) {
          setState(() => _recordDuration++);
        }
      }
    } catch (e) {
      debugPrint('[AudioRecorder] Error: $e');
      if (mounted) widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      
      if (_audioPath != null && mounted) {
        widget.onAudioRecorded(File(_audioPath!), _recordDuration);
      }
    } catch (e) {
      debugPrint('[AudioRecorder] Error stopping: $e');
    }
  }

  void _cancelRecording() async {
    try {
      await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      widget.onCancel();
    } catch (e) {
      debugPrint('[AudioRecorder] Error canceling: $e');
      widget.onCancel();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Recording animation
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Duration
          Text(
            _formatDuration(_recordDuration),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          // Send button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
