import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'full_screen_page.dart';
import 'dart:typed_data';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage>
    with AutomaticKeepAliveClientMixin {

  int selectedColumns = 3;
  String viewType = "grid";
  String sortType = "newest";

  bool isSelecting = false;
  Set<String> selectedIds = {};
  List<AssetEntity> allVideos = [];
  List<AssetEntity> filteredVideos = [];
  TextEditingController searchController = TextEditingController();
  Map<String, Uint8List> thumbCache = {};
  bool isLoaded = false;
  bool isSearching = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollbar = false;

  @override
  void initState() {
    super.initState();
    if (!isLoaded) loadVideos();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Videos",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        actions: [
          if (isSelecting)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: deleteSelected,
            ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'select',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text("Select"),
                ),
              ),
              const PopupMenuItem(
                value: 'columns',
                child: ListTile(
                  leading: Icon(Icons.grid_view),
                  title: Text("Columns"),
                ),
              ),
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.view_list),
                  title: Text("View Type"),
                ),
              ),
              const PopupMenuItem(
                value: 'sort',
                child: ListTile(
                  leading: Icon(Icons.sort),
                  title: Text("Sort by"),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'columns') showColumnsSheet();
              else if (value == 'view') showViewTypeSheet();
              else if (value == 'sort') showSortSheet();
              else if (value == 'select') enableSelectionMode();
            },
          ),
        ],
      ),

      // BODY
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          setState(() {
            _showScrollbar = true;
          });

          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showScrollbar = false;
              });
            }
          });

          return false;
        },
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: MaterialStateProperty.all(Colors.blue),
            trackColor: MaterialStateProperty.all(Colors.grey.shade300),
            radius: const Radius.circular(10),
            thickness: MaterialStateProperty.all(10), // 👈 yahan weight barhaya
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: _showScrollbar,
            child: !isLoaded
                ? const Center(child: CircularProgressIndicator())
                : filteredVideos.isEmpty
                ? const Center(child: Text("No Videos Found"))
                : viewType == "grid"
                ? GridView.builder(
              controller: _scrollController, // 👈 IMPORTANT
              padding: const EdgeInsets.all(4),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: selectedColumns,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: filteredVideos.length,
              itemBuilder: (context, index) {
                final asset = filteredVideos[index];

                return FutureBuilder<Uint8List?>(
                  future: getThumb(asset),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          isSelecting = true;
                          selectedIds.add(asset.id);
                        });
                      },
                      onTap: () {
                        if (isSelecting) {
                          setState(() {
                            selectedIds.contains(asset.id)
                                ? selectedIds.remove(asset.id)
                                : selectedIds.add(asset.id);
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenPage(
                                assets: filteredVideos,
                                initialIndex: index,
                              ),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            ),
                          ),

                          if (isSelecting)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedIds.contains(asset.id)
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),

                          if (isSelecting &&
                              selectedIds.contains(asset.id))
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 22,
                              ),
                            ),

                          Positioned(
                            bottom: 4,
                            right: 4, // 👈 moved to right side
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam, color: Colors.white, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    formatDuration(asset.videoDuration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            )
                : ListView.builder(
              controller: _scrollController, // 👈 IMPORTANT
              itemCount: filteredVideos.length,
              itemBuilder: (context, index) {
                final asset = filteredVideos[index];

                return InkWell(
                  onTap: () {
                    if (isSelecting) {
                      setState(() {
                        selectedIds.contains(asset.id)
                            ? selectedIds.remove(asset.id)
                            : selectedIds.add(asset.id);
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenPage(
                            assets: filteredVideos,
                            initialIndex: index,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade100,
                    ),
                    child: Row(
                      children: [

                        // THUMBNAIL
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: getThumb(asset),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.black12,
                                      child: const Icon(Icons.videocam),
                                    );
                                  }

                                  return Image.memory(
                                    snapshot.data!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),

                              // 🎯 VIDEO ICON + TIME OVERLAY (NEW)
                              Positioned(
                                bottom: 4,
                                right: 4, // 👈 moved to right side
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.videocam, color: Colors.white, size: 14),
                                      const SizedBox(width: 3),
                                      Text(
                                        formatDuration(asset.videoDuration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // TITLE
                        Expanded(
                          child: Text(
                            asset.title ?? "Video",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // ✅ ARROW (same like photo page)
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),

                        const SizedBox(width: 8),

                        // CHECKBOX (only when selecting)
                        if (isSelecting)
                          Checkbox(
                            value: selectedIds.contains(asset.id),
                            onChanged: (v) {
                              setState(() {
                                v == true
                                    ? selectedIds.add(asset.id)
                                    : selectedIds.remove(asset.id);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<Uint8List?> getThumb(AssetEntity asset) async {
    if (thumbCache.containsKey(asset.id)) return thumbCache[asset.id];

    final data =
    await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));

    if (data != null) thumbCache[asset.id] = data;
    return data;
  }

  Future<void> loadVideos() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final albums =
    await PhotoManager.getAssetPathList(type: RequestType.video);

    List<AssetEntity> videos = [];

    for (var album in albums) {
      final assets = await album.getAssetListPaged(page: 0, size: 100);

      // ✅ IMPORTANT FILTER (sirf videos)
      videos.addAll(
        assets.where((asset) => asset.type == AssetType.video),
      );
    }

    videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    setState(() {
      allVideos = videos;
      filteredVideos = videos;
      isLoaded = true;
    });
  }

  void showColumnsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Title (LEFT aligned properly)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: const [
                        Icon(Icons.grid_view, color: Colors.blue),
                        SizedBox(width: 10),
                        Text("Columns",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.blue),),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Option Rows (label left, radio right)
                  _buildColumnOption(setStateSheet, 2,),
                  _buildColumnOption(setStateSheet, 3),
                  _buildColumnOption(setStateSheet, 4),
                  _buildColumnOption(setStateSheet, 5),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel",style: TextStyle(color: Colors.black),),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text("OK",style: TextStyle(color: Colors.white),),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColumnOption(Function setStateSheet, int value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$value Columns",
            style: const TextStyle(fontSize: 16),
          ),
          Radio<int>(
            activeColor: Colors.blue, // 👈 ADD THIS LINE
            value: value,
            groupValue: selectedColumns,
            onChanged: (val) {
              setStateSheet(() {
                selectedColumns = val!;
              });
            },
          ),
        ],
      ),
    );
  }
  void showViewTypeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.grid_view, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          "View Type",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildViewOption(setStateSheet, "grid", "Grid", Icons.grid_view),
                  _buildViewOption(setStateSheet, "list", "List", Icons.view_list),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildViewOption(
      Function setStateSheet,
      String value,
      String title,
      IconData icon,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // LEFT SIDE (ICON + TEXT)
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),

          // RIGHT SIDE (RADIO)
          Radio<String>(
            activeColor: Colors.blue,
            value: value,
            groupValue: viewType,
            onChanged: (val) {
              setStateSheet(() {
                viewType = val!;
              });
            },
          ),
        ],
      ),
    );
  }

  void showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.sort, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          "Sort By",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildSortOption(setStateSheet, "newest", "Newest on top", Icons.arrow_downward),
                  _buildSortOption(setStateSheet, "oldest", "Oldest on top", Icons.arrow_upward),
                  _buildSortOption(setStateSheet, "az", "Name (A-Z)", Icons.sort_by_alpha),
                  _buildSortOption(setStateSheet, "za", "Name (Z-A)", Icons.sort),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 140,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            applySorting();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )

                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildSortOption(
      Function setStateSheet,
      String value,
      String title,
      IconData icon,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // LEFT SIDE
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),

          // RIGHT SIDE RADIO
          Radio<String>(
            activeColor: Colors.blue,
            value: value,
            groupValue: sortType,
            onChanged: (val) {
              setStateSheet(() {
                sortType = val!;
              });
            },
          ),

        ],
      ),
    );
  }

  void applySorting() {
    setState(() {
      if (sortType == "newest") {
        filteredVideos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      } else if (sortType == "oldest") {
        filteredVideos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      } else if (sortType == "az") {
        filteredVideos.sort((a, b) => (a.title ?? "").compareTo(b.title ?? ""));
      } else if (sortType == "za") {
        filteredVideos.sort((a, b) => (b.title ?? "").compareTo(a.title ?? ""));
      }
    });
  }





  void enableSelectionMode() {
    setState(() {
      isSelecting = true;
      selectedIds.clear();
    });
  }


  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;

    final toDelete = filteredVideos
        .where((a) => selectedIds.contains(a.id))
        .toList();

    final ids = toDelete.map((e) => e.id).toList();

    await PhotoManager.editor.deleteWithIds(ids);

    setState(() {
      allVideos.removeWhere((a) => selectedIds.contains(a.id));
      filteredVideos.removeWhere((a) => selectedIds.contains(a.id));

      selectedIds.clear();
      isSelecting = false;
    });
  }
}
