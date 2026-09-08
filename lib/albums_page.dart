import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'gallery_page.dart';
import 'full_screen_page.dart';


class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  Future<void> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();

    if (!result.isAuth) {
      PhotoManager.openSetting();
    }
  }

  final ScrollController _scrollController = ScrollController();

  bool _showScrollbar = false;
  bool selectionModeJustStarted = false;

  bool isLoadedOnce = false;

  List<String> customAlbums = [];

  Map<String, List<AssetEntity>> albumAssetsCache = {};

  Map<String, List<AssetEntity>> albumCache = {};


  void showCreateAlbumDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Title row (like Tips icon + text)
                Row(
                  children: const [
                    Icon(Icons.create_new_folder_outlined,
                        color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      "Tips",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Album name",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  "You can create a new album while copying or moving pictures or videos.",
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      Navigator.pop(context);

                      setState(() {
                        customAlbums.add(name);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Album '$name' created")),
                      );
                    },
                    child: const Text("OK", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  int selectedColumns = 2;
  String viewType = "grid";
  String sortType = "az";

  bool isSelecting = false;
  Set<String> selectedIds = {};

  Set<AssetPathEntity> selectedAlbums = {};
  Set<String> selectedCustomAlbums = {};

  List<AssetPathEntity> allAlbums = [];
  List<AssetPathEntity> filteredAlbums = [];




  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();



  @override
  void initState() {
    super.initState();
    init();
  }



  Future<void> init() async {
    if (isLoadedOnce) return;

    final result = await PhotoManager.requestPermissionExtend();

    if (!result.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    await PhotoManager.clearFileCache();   // 👈 ADD
    await PhotoManager.releaseCache();     // 👈 ADD

    await loadAlbums();
    await preloadThumbnails(); // 👈 YE ADD KARO
    isLoadedOnce = true;
  }

  // 👇 ALL FUNCTIONS GO HERE (this is correct place)
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
                          onPressed: () {
                            applySorting();
                            Navigator.pop(context);
                          },
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






  Future<void> loadAlbums() async {

    final result = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,   // ✅ IMPORTANT
      onlyAll: false,
    );

    List<AssetPathEntity> temp = [];

    for (var album in result) {
      try {
        final count = await album.assetCountAsync;
        final name = album.name?.trim() ?? "";

        if (count > 0 &&
            name.isNotEmpty &&
            name.toLowerCase() != "null" &&
            name.toLowerCase() != "favorites" &&
            name.toLowerCase() != "hidden") {

          temp.add(album);
        }

      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      allAlbums = temp;
      filteredAlbums = temp;
    });
  }


  Future<void> preloadThumbnails() async {
    final futures = filteredAlbums.map((album) async {
      final list = await album.getAssetListPaged(page: 0, size: 1);
      return MapEntry(album.id, list);
    });

    final results = await Future.wait(futures);

    for (final entry in results) {
      albumCache[entry.key] = entry.value;
    }
  }

  void searchAlbums(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredAlbums = List.from(allAlbums);
      } else {
        filteredAlbums = allAlbums
            .where((album) =>
            album.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void enableSelectionMode() {
    setState(() {
      isSelecting = true;
      selectedAlbums.clear();
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Search Albums",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white),
            ),
            onChanged: searchAlbums,
          ),
        )
            : isSelecting
            ? Text("${selectedAlbums.length} selected")
            : const Text("Albums"),

        actions: [

          // CAMERA
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () async {
              final XFile? photo = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 100,
              );

              if (photo == null) return;

              final bytes = await photo.readAsBytes();

              final result = await PhotoManager.editor.saveImage(
                bytes,
                filename: "IMG_${DateTime.now().millisecondsSinceEpoch}.jpg",
              );
              if (result != null) {
                await PhotoManager.clearFileCache();
                await PhotoManager.releaseCache();
                await Future.delayed(Duration(seconds: 2));
                await loadAlbums();
              }

              if (result == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Save failed ❌")),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Saved to Gallery ✅")),
              );
            },
          ),

          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                searchController.clear();
                filteredAlbums = List.from(allAlbums);
              });
            },
          ),

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
                value: 'CreateAlbum',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder_outlined),
                    SizedBox(width: 10),
                    Text("Create Album"),
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
              if (value == 'CreateAlbum') {
                showCreateAlbumDialog();
              }
              else if (value == 'columns') {
                showColumnsSheet();
              }
              else if (value == 'view') {
                showViewTypeSheet();
              }
              else if (value == 'sort') {
                showSortSheet();
              }
              else if (value == 'select') {
                enableSelectionMode();
              }
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
            thickness: MaterialStateProperty.all(10),
            interactive: true,
          ),

          child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: _showScrollbar, // 👈 IMPORTANT

              child: viewType == "list"
                  ? ListView.builder(
                controller: _scrollController,
                itemCount: filteredAlbums.length,
                itemBuilder: (context, index) {
                  final album = filteredAlbums[index];

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade100,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GalleryPage(album: album),
                          ),
                        );
                      },
                      child: Row(
                        children: [

                          // 📸 Thumbnail (fixed size)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child:FutureBuilder<List<AssetEntity>>(
                                future: album.getAssetListPaged(page: 0, size: 50),
                                builder: (context, snapshot) {

                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return Container(color: Colors.grey);
                                  }

                                  final assets = snapshot.data!;
                                  final asset = assets[0];

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GalleryPage(album: album),
                                        ),
                                      );
                                    },

                                    child: AssetEntityImage(
                                      asset,
                                      isOriginal: false,
                                      thumbnailSize: const ThumbnailSize.square(300),
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              )
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 📝 TEXT (IMPORTANT FIX)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  album.name.isEmpty ? "Unknown Album" : album.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 4),

                                FutureBuilder<int>(
                                  future: album.assetCountAsync,
                                  builder: (context, snap) {
                                    return Text(
                                      "${snap.data ?? 0} items",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // ✅ ARROW (same like photo page)
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),

                          const SizedBox(width: 8),


                        ],
                      ),
                    ),
                  );
                },
              ):
              GridView.builder(
                cacheExtent: 1000,
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(10),

                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: selectedColumns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),

                itemCount: customAlbums.length + filteredAlbums.length,

                itemBuilder: (context, index) {

                  // =========================
                  // 🟦 CUSTOM ALBUMS
                  // =========================
                  if (index < customAlbums.length) {
                    final name = customAlbums[index];

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          isSelecting = true;
                          selectedCustomAlbums.add(name);
                        });
                      },
                      onTap: () {
                        if (isSelecting) {
                          setState(() {
                            selectedCustomAlbums.contains(name)
                                ? selectedCustomAlbums.remove(name)
                                : selectedCustomAlbums.add(name);

                            if (selectedCustomAlbums.isEmpty) {
                              isSelecting = false;
                            }
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(name)),
                                body: const Center(child: Text("Empty Album")),
                              ),
                            ),
                          );
                        }
                      },

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [

                                  Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: Icon(Icons.folder,
                                          size: 50, color: Colors.blue),
                                    ),
                                  ),

                                  if (isSelecting &&
                                      selectedCustomAlbums.contains(name))
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.blue, width: 2),
                                      ),
                                    ),

                                  if (isSelecting &&
                                      selectedCustomAlbums.contains(name))
                                    const Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Icon(Icons.check_circle,
                                          color: Colors.blue, size: 22),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 2),

                          const Text(
                            "0 items",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // =========================
                  // 🟨 REAL ALBUMS
                  // =========================
                  final album = filteredAlbums[index - customAlbums.length];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Expanded(
                        child: FutureBuilder<List<AssetEntity>>(
                          future: albumCache.containsKey(album.id)
                              ? Future.value(albumCache[album.id])
                              : album.getAssetListPaged(page: 0, size: 50).then((list) {
                            albumCache[album.id] = list;
                            return list;
                          }),
                          builder: (context, snapshot) {

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Icon(Icons.folder, color: Colors.grey),
                                ),
                              );
                            }

                            final asset = snapshot.data!.first;
                            final isVideo = asset.type == AssetType.video;

                            return GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  isSelecting = true;
                                  selectedIds.add(asset.id);
                                });
                              },
                              onTap: () async {
                                if (isSelecting) {
                                  setState(() {
                                    selectedIds.contains(asset.id)
                                        ? selectedIds.remove(asset.id)
                                        : selectedIds.add(asset.id);
                                  });
                                } else {
                                  final assets = snapshot.data!; // 👈 FULL LIST

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GalleryPage(album: album),
                                    ),
                                  );
                                }
                              },

                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
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
                                            color: selectedIds.contains(asset.id)
                                                ? Colors.blue.withOpacity(0.18)
                                                : Colors.black.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selectedIds.contains(asset.id)
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (isSelecting && selectedIds.contains(asset.id))
                                      const Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(Icons.check_circle,
                                            color: Colors.blue, size: 22),
                                      ),

                                    if (isVideo)
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 37,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        album.name.isEmpty ? "Unknown Folder" : album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 2),

                      FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (context, snap) {
                          return Text(
                            "${snap.data ?? 0} items",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              )
          ),
        ),
      ),
    );
  }





  void applySorting() {
    setState(() {
      if (sortType == "az") {
        filteredAlbums.sort((a, b) => a.name.compareTo(b.name));
      }
      else if (sortType == "za") {
        filteredAlbums.sort((a, b) => b.name.compareTo(a.name));
      }
      else if (sortType == "newest") {
        filteredAlbums.sort((a, b) => b.id.compareTo(a.id));
      }
      else if (sortType == "oldest") {
        filteredAlbums.sort((a, b) => a.id.compareTo(b.id));
      }
    });
  }



  Future<void> deleteSelected() async {
    if (selectedCustomAlbums.isEmpty && selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Items?"),
          content: const Text("Do you want to delete selected items?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // 🟢 CUSTOM ALBUMS DELETE (app only)
    customAlbums.removeWhere(
          (item) => selectedCustomAlbums.contains(item),
    );

    selectedCustomAlbums.clear();

    // 🔵 REAL FILES DELETE (important fix)
    final List<AssetEntity> assetsToDelete = [];

    for (String id in selectedIds) {
      final asset = await AssetEntity.fromId(id);
      if (asset != null) {
        assetsToDelete.add(asset);
      }
    }

    if (assetsToDelete.isNotEmpty) {
      await PhotoManager.editor.deleteWithIds(
        assetsToDelete.map((e) => e.id).toList(),
      );
    }

    selectedIds.clear();
    isSelecting = false;

    setState(() {});

    await loadAlbums();
  }
}


