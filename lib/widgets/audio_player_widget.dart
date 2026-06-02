import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int? duration;
  final bool isCurrentUser;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isCurrentUser,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayDuration = _duration.inSeconds > 0 
        ? _duration 
        : Duration(seconds: widget.duration ?? 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isCurrentUser
                  ? AppColors.primaryContainer.withValues(alpha: 0.3)
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isCurrentUser
                  ? AppColors.primaryContainer
                  : AppColors.onSurface,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Waveform placeholder and duration
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple waveform visualization
            Row(
              children: List.generate(
                20,
                (index) => Container(
                  width: 2,
                  height: (index % 3 + 1) * 4.0,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: widget.isCurrentUser
                        ? AppColors.primaryContainer.withValues(alpha: 0.4)
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Duration
            Text(
              _isPlaying 
                  ? '${_formatDuration(_position)} / ${_formatDuration(displayDuration)}'
                  : _formatDuration(displayDuration),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
