import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'albums_page.dart';
import 'videos_page.dart';
import 'photos_page.dart'; // jahan PicturesPage hai

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

// ----------------- HomePage -----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const AlbumsPage(),
    const PhotosPage(), // ✅ FIXED
    const VideosPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: Colors.blue,   // 👈 active icon + text blue
        unselectedItemColor: Colors.grey, // 👈 inactive items

        backgroundColor: Colors.white,    // 👈 bar background

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: "Albums",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: "Photos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_rounded),
            label: "Videos",
          ),
        ],

        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}