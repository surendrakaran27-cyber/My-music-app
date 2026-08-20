import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: MusicApp(), debugShowCheckedModeBanner: false));

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  int _currentIndex = 0;

  // 5 Tabs ke screens
  final List<Widget> _pages = [
    const Center(child: Text("Trending Songs", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Albums", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Playlists", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Search", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Settings", style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // 1. Body Content
          Expanded(child: _pages[_currentIndex]),

          // 2. Persistent Mini Player (Ye har screen ke upar dikhega)
          Container(
            height: 60,
            color: const Color(0xFF282828),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.music_note, color: Colors.green, size: 40),
                ),
                const Expanded(child: Text("Song Name - Artist", style: TextStyle(color: Colors.white))),
                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.white), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
      
      // 3. Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Trending'),
          BottomNavigationBarItem(icon: Icon(Icons.album), label: 'Albums'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlist'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
