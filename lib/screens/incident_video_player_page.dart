
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class IncidentVideoPlayerPage extends StatefulWidget {
  const IncidentVideoPlayerPage({
    super.key,
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  State<IncidentVideoPlayerPage> createState() =>
      _IncidentVideoPlayerPageState();
}

class _IncidentVideoPlayerPageState
    extends State<IncidentVideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeVideo;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    _initializeVideo = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاهدة تسجيل الحادث'),
      ),
      body: FutureBuilder<void>(
        future: _initializeVideo,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError ||
              !_controller.value.isInitialized) {
            return const Center(
              child: Text('تعذر تشغيل الفيديو'),
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                            maxHeight: constraints.maxHeight - 80,
                          ),
                          child: AspectRatio(
                            aspectRatio:
                                _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      iconSize: 44,
                      onPressed: () async {
                        if (_controller.value.isPlaying) {
                          await _controller.pause();
                        } else {
                          await _controller.play();
                        }

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
