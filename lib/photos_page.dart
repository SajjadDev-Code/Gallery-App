import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'full_screen_page.dart';
import 'dart:typed_data';

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage>
    with AutomaticKeepAliveClientMixin {

  List<AssetEntity> allAssets = [];

  List<AssetEntity> filteredAssets = [];

  TextEditingController searchController = TextEditingController();

  Map<String, Uint8List> thumbCache = {};

  bool isLoaded = false;


  int selectedColumns = 3;
  String viewType = "grid";
  String sortType = "newest";

  bool isSelecting = false;
  Set<String> selectedIds = {};

  bool _showScrollbar = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!isLoaded) loadMedia();

    filteredAssets = [];
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
          "Photos",
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
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 10),
                    Text("Select"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'columns',
                child: Row(
                  children: [
                    Icon(Icons.grid_view),
                    SizedBox(width: 10),
                    Text("Columns"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.view_list),
                    SizedBox(width: 10),
                    Text("View Type"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort),
                    SizedBox(width: 10),
                    Text("Sort by"),
                  ],
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
      body: !isLoaded
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          setState(() {
            _showScrollbar = true;
          });

          Future.delayed(const Duration(milliseconds: 700), () {
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
            thickness: MaterialStateProperty.all(10),
            radius: const Radius.circular(10),


            interactive: true,
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: _showScrollbar,
            child: viewType == "grid"
                ? GridView.builder(
              controller: _scrollController, // ✅ IMPORTANT
              cacheExtent: 500,
              padding: const EdgeInsets.all(4),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: selectedColumns,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: filteredAssets.length,
              itemBuilder: (context, index) {
                final asset = filteredAssets[index];

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
                            assets: filteredAssets,
                            initialIndex: index,
                          ),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AssetEntityImage(
                          asset,
                          isOriginal: false,
                          thumbnailSize:
                          const ThumbnailSize.square(300),
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
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
                : ListView.builder(
              controller: _scrollController, // ✅ IMPORTANT
              itemCount: filteredAssets.length,
              itemBuilder: (context, index) {
                final asset = filteredAssets[index];

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
                            assets: filteredAssets,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AssetEntityImage(
                            asset,
                            isOriginal: false,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            asset.title ?? "Photo",
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


                        if (isSelecting)
                          Checkbox(
                            value:
                            selectedIds.contains(asset.id),
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



  Future<void> loadMedia() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth || !permission.hasAccess) {
      PhotoManager.openSetting();
      setState(() {
        isLoaded = true;
        allAssets = [];
        filteredAssets = [];
      });
      return;
    }

    final albums =
    await PhotoManager.getAssetPathList(type: RequestType.image);

    List<AssetEntity> media = [];

    for (var album in albums) {
      final assets = await album.getAssetListPaged(page: 0, size: 100);
      media.addAll(assets);
    }

    media.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    setState(() {
      allAssets = media;
      filteredAssets = media;
      isLoaded = true;
    });

    print("Loaded assets: ${filteredAssets.length}");
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
        filteredAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      } else if (sortType == "oldest") {
        filteredAssets.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      } else if (sortType == "az") {
        filteredAssets.sort((a, b) => (a.title ?? "").compareTo(b.title ?? ""));
      } else if (sortType == "za") {
        filteredAssets.sort((a, b) => (b.title ?? "").compareTo(a.title ?? ""));
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

    final ids = selectedIds.toList();

    await PhotoManager.editor.deleteWithIds(ids);

    selectedIds.clear();
    isSelecting = false;

    await loadMedia(); // 👈 last me rakho
  }








}
