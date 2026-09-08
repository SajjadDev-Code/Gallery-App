  import 'package:flutter/material.dart';
  import 'package:photo_manager/photo_manager.dart';
  import 'package:video_player/video_player.dart';
  import 'dart:io';

  class FullScreenPage extends StatefulWidget {
    final List<AssetEntity> assets;
    final int initialIndex;

    const FullScreenPage({
      super.key,
      required this.assets,
      this.initialIndex = 0,
    });




    @override
    State<FullScreenPage> createState() => _FullScreenPageState();
  }

  class _FullScreenPageState extends State<FullScreenPage> {
    late int currentIndex;
    late AssetEntity currentAsset;

    VideoPlayerController? _controller;
    bool isVideo = false;
    bool isLoading = true;
    bool showControls = true;

    double currentSpeed = 1.0;

    bool isLocked = false;
    bool isLoopOne = false;
    bool isLoopAll = false;





    Set<String> favoriteIds = {};





    @override
    void initState() {
      super.initState();
      currentIndex = widget.initialIndex;

      _pageController = PageController(initialPage: widget.initialIndex);

      loadAsset();
    }

    late PageController _pageController;
    Future<void> loadAsset() async {
      if (!mounted) return;

      setState(() {
        isLoading = true;
      });

      final asset = widget.assets[currentIndex];
      currentAsset = asset;
      isVideo = asset.type == AssetType.video;

      // OLD CONTROLLER SAFE DISPOSE
      if (_controller != null) {
        await _controller!.pause();
        await _controller!.dispose();
        _controller = null;
      }
      if (isVideo) {
        final file = await asset.file;

        if (file == null || !mounted) {
          setState(() => isLoading = false);
          return;
        }

        final controller = VideoPlayerController.file(file);

        try {
          await controller.initialize();

          if (!mounted) return;

          _controller?.dispose();
          _controller = controller;

          setState(() {}); // FIRST render frame

          await Future.delayed(const Duration(milliseconds: 50)); // ⭐ KEY FIX

          await _controller!.play();

          _controller!.addListener(() {
            if (!mounted || !_controller!.value.isInitialized) return;
            setState(() {});
          });

        } catch (e) {
          debugPrint("Video error: $e");
        }
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    }

    void playNext() {
      if (currentIndex + 1 >= widget.assets.length) return;

      currentIndex++;

      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      loadAsset();
    }
    void playPrevious() {
      if (currentIndex - 1 < 0) return;

      currentIndex--;

      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );

      loadAsset();
    }
    void changeSpeed() {
      setState(() {
        if (currentSpeed == 1.0) {
          currentSpeed = 1.5;
        } else if (currentSpeed == 1.5) {
          currentSpeed = 2.0;
        } else {
          currentSpeed = 1.0;
        }
        _controller?.setPlaybackSpeed(currentSpeed);
      });
    }

    void changeLoop() {
      setState(() {
        if (!isLoopOne && !isLoopAll) {
          isLoopOne = true;
          _controller?.setLooping(true);
        } else if (isLoopOne) {
          isLoopOne = false;
          isLoopAll = true;
          _controller?.setLooping(false);
        } else {
          isLoopAll = false;
          _controller?.setLooping(false);
        }
      });
    }

    String format(Duration d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
    }

    @override
    void dispose() {
      _pageController.dispose(); // ✅ ADD THIS
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            if (!isLocked) setState(() => showControls = !showControls);
          },
          child: Stack(
            children: [

              // ✅ MAIN PAGEVIEW (FIXED PROPERLY)
              PageView.builder(
                controller: _pageController,
                itemCount: widget.assets.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                    isLoading = true;
                  });

                  loadAsset(); // ONLY THIS (NO await)
                },
                itemBuilder: (context, index) {
                  final asset = widget.assets[index];
                  final isVideoItem = asset.type == AssetType.video;

                  if (isVideoItem) {
                    if (index == currentIndex &&
                        _controller != null &&
                        _controller!.value.isInitialized) {
                      return Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      );
                    }
                    return const SizedBox();
                  }

                  return FutureBuilder<File?>(
                    future: asset.file,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return Image.file(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      );
                    },
                  );
                },
              ),

              // ⏳ LOADING
              if (isLoading)
                const Center(child: CircularProgressIndicator()),

              // 🎮 CONTROLS
              if (showControls && !isLocked && isVideo && _controller != null)
                Positioned(
                  bottom: 20,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(format(_controller!.value.position),
                              style: const TextStyle(color: Colors.white)),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: _controller!.value.duration.inSeconds.toDouble(),
                              value: _controller!.value.position.inSeconds
                                  .clamp(0, _controller!.value.duration.inSeconds.toDouble())
                                  .toDouble(),
                              onChanged: (value) {
                                _controller!.seekTo(Duration(seconds: value.toInt()));
                              },
                            ),
                          ),
                          Text(format(_controller!.value.duration),
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              isLoopOne
                                  ? Icons.repeat_one
                                  : (isLoopAll ? Icons.repeat : Icons.repeat_outlined),
                              color: Colors.white,
                            ),
                            onPressed: changeLoop,
                          ),

                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous, color: Colors.white),
                                onPressed: playPrevious,
                              ),
                              IconButton(
                                icon: Icon(
                                  _controller!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 35,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller!.value.isPlaying
                                        ? _controller!.pause()
                                        : _controller!.play();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, color: Colors.white),
                                onPressed: playNext,
                              ),
                            ],
                          ),

                          TextButton(
                            onPressed: changeSpeed,
                            child: Text(
                              "${currentSpeed}x",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 🔝 TOP BAR
              if (showControls && !isLocked)
                Positioned(
                  top: 40,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          currentAsset.title ?? "Media",
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          favoriteIds.contains(currentAsset.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            if (favoriteIds.contains(currentAsset.id)) {
                              favoriteIds.remove(currentAsset.id);
                            } else {
                              favoriteIds.add(currentAsset.id);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // 🔓 UNLOCK
              if (isLocked)
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.lock_open, color: Colors.white, size: 40),
                    onPressed: () {
                      setState(() {
                        isLocked = false;
                        showControls = true;
                      });
                    },
                  ),
                ),
            ],
          )
        ),
      );
    }
  }








