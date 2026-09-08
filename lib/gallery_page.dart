import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'full_screen_page.dart';
import 'dart:typed_data';

class GalleryPage extends StatefulWidget {
  final AssetPathEntity album;

  const GalleryPage({super.key, required this.album});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  Future<List<AssetEntity>> loadAssets() async {
    return widget.album.getAssetListPaged(page: 0, size: 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.name)),
      body: FutureBuilder<List<AssetEntity>>(
        future: loadAssets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final assets = snapshot.data!;
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return FutureBuilder<Uint8List?>(
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize(200, 200),
                  quality: 70,
                ),
                builder: (context, thumbSnap) {
                  if (thumbSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!thumbSnap.hasData || thumbSnap.data == null) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  }
                  return GestureDetector(
                    onTap: () async {
                      final allAssets = await widget.album.getAssetListPaged(page: 0, size: 100);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenPage(
                            assets: allAssets,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            thumbSnap.data!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (asset.type == AssetType.video)
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam, color: Colors.white, size: 18),
                                const SizedBox(width: 2),
                                Text(
                                  formatDuration(asset.videoDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}