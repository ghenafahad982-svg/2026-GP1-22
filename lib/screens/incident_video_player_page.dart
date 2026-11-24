import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../raqeeb_ui.dart';

class IncidentVideoPlayerPage extends StatefulWidget {
  const IncidentVideoPlayerPage({super.key, required this.videoUrl});
  final String videoUrl;

  @override
  State<IncidentVideoPlayerPage> createState() =>
      _IncidentVideoPlayerPageState();
}

class _IncidentVideoPlayerPageState extends State<IncidentVideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;
  double? _dragSeconds;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.addListener(_onVideoChanged);
    _initializeVideo = _controller.initialize();
  }

  void _onVideoChanged() {
    if (mounted && _dragSeconds == null) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _seekRelative(int seconds) async {
    if (!_controller.value.isInitialized) return;
    final duration = _controller.value.duration;
    final target = _controller.value.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > duration ? duration : target;
    await _controller.seekTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'مشاهدة تسجيل الحادث', 'Incident Recording'))),
      body: FutureBuilder<void>(
        future: _initializeVideo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !_controller.value.isInitialized) {
            return Center(child: Text(tr(context, 'تعذر تشغيل الفيديو', 'Could not play recording')));
          }

          final value = _controller.value;
          final durationSeconds = value.duration.inMilliseconds / 1000.0;
          final positionSeconds = value.position.inMilliseconds / 1000.0;
          final currentSeconds = (_dragSeconds ?? positionSeconds)
              .clamp(0.0, durationSeconds > 0 ? durationSeconds : 0.0);

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  child: Column(
                    children: [
                      Slider(
                        min: 0,
                        max: durationSeconds > 0 ? durationSeconds : 1,
                        value: currentSeconds,
                        onChanged: durationSeconds <= 0
                            ? null
                            : (seconds) => setState(() => _dragSeconds = seconds),
                        onChangeEnd: durationSeconds <= 0
                            ? null
                            : (seconds) async {
                                setState(() => _dragSeconds = null);
                                await _controller.seekTo(
                                  Duration(milliseconds: (seconds * 1000).round()),
                                );
                              },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(Duration(milliseconds: (currentSeconds * 1000).round()))),
                            Text(_formatDuration(value.duration)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: tr(context, 'ترجيع 10 ثوانٍ', 'Back 10 seconds'),
                            icon: const Icon(Icons.replay_10),
                            iconSize: 36,
                            onPressed: () => _seekRelative(-10),
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            tooltip: value.isPlaying
                                ? tr(context, 'إيقاف مؤقت', 'Pause')
                                : tr(context, 'تشغيل', 'Play'),
                            icon: Icon(value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill),
                            iconSize: 52,
                            onPressed: () async {
                              if (value.isPlaying) {
                                await _controller.pause();
                              } else {
                                await _controller.play();
                              }
                            },
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            tooltip: tr(context, 'تقديم 10 ثوانٍ', 'Forward 10 seconds'),
                            icon: const Icon(Icons.forward_10),
                            iconSize: 36,
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
