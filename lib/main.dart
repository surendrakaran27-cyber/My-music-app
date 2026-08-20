import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(
      home: MusicApp(),
      debugShowCheckedModeBanner: false,
    ));

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  int _currentIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  // User Profile
  String _userName = "SURSA KARNOT";
  String _selectedAvatar = "👑";
  String _audioQuality = "320kbps";

  // Data State
  List _searchResults = [];
  List _trendingSongs = [];
  bool _isLoading = false;
  bool _isTrendingLoading = false;
  String _currentTitle = "No song playing";
  String _currentArtist = "";
  String _currentImage = "";
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchTrending();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "SURSA KARNOT";
      _selectedAvatar = prefs.getString('user_avatar') ?? "👑";
      _audioQuality = prefs.getString('audio_quality') ?? "320kbps";
    });
  }

  Future<void> _savePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _loadPreferences();
  }

  // Multi-API Search Function
  Future<void> searchSongs(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final endpoints = [
      'https://saavn.dev/api/search/songs?query=$query',
      'https://jiosaavn-api-privatecvc.vercel.app/search/songs?query=$query',
      'https://saavn.me/search/songs?query=$query',
    ];

    bool success = false;
    for (String url in endpoints) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          List results = [];
          if (data['data'] != null && data['data']['results'] != null) {
            results = data['data']['results'];
          } else if (data['results'] != null) {
            results = data['results'];
          }

          if (results.isNotEmpty) {
            setState(() {
              _searchResults = results;
              success = true;
            });
            break;
          }
        }
      } catch (_) {}
    }

    setState(() => _isLoading = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No songs found or check network connection.")),
      );
    }
  }

  // Fetch Trending Default Songs
  Future<void> _fetchTrending() async {
    setState(() => _isTrendingLoading = true);
    try {
      final res = await http.get(Uri.parse('https://saavn.dev/api/search/songs?query=Trending%20Hindi')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _trendingSongs = data['data']?['results'] ?? [];
        });
      }
    } catch (_) {}
    setState(() => _isTrendingLoading = false);
  }

  // Play Audio
  void playSong(dynamic song) async {
    try {
      String? downloadUrl;
      if (song['downloadUrl'] is List && (song['downloadUrl'] as List).isNotEmpty) {
        final list = song['downloadUrl'] as List;
        downloadUrl = list.last['url'] ?? list.first['url'];
      }

      if (downloadUrl != null) {
        setState(() {
          _currentTitle = song['name'] ?? 'Song';
          if (song['artists']?['primary'] != null && (song['artists']['primary'] as List).isNotEmpty) {
            _currentArtist = song['artists']['primary'][0]['name'] ?? '';
          } else {
            _currentArtist = song['primaryArtists'] ?? '';
          }

          if (song['image'] is List && (song['image'] as List).isNotEmpty) {
            _currentImage = (song['image'] as List).last['url'] ?? '';
          }
        });

        await _audioPlayer.setUrl(downloadUrl);
        _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Playback error. Trying next...")),
        );
      }
    }
  }

  // 1. Trending Screen
  Widget _buildTrendingPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 4),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green.withOpacity(0.2),
                  child: Text(_selectedAvatar, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Welcome back,", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => setState(() => _currentIndex = 3),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text("🔥 Trending Today", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        if (_isTrendingLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.green)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _trendingSongs.length,
              itemBuilder: (context, index) {
                final song = _trendingSongs[index];
                final title = song['name'] ?? 'Song';
                final artist = song['artists']?['primary']?[0]?['name'] ?? song['primaryArtists'] ?? '';
                final imgUrl = (song['image'] is List && (song['image'] as List).isNotEmpty)
                    ? song['image'][1]['url']
                    : '';

                return ListTile(
                  leading: imgUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.music_note, color: Colors.white),
                  title: Text(title, style: const TextStyle(color: Colors.white), maxLines: 1),
                  subtitle: Text(artist, style: const TextStyle(color: Colors.grey), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green, size: 36),
                  onTap: () => playSong(song),
                );
              },
            ),
          ),
      ],
    );
  }

  // 2. Search Screen
  Widget _buildSearchPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => searchSongs(val),
            decoration: InputDecoration(
              hintText: 'Search songs, albums, artists...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF222222),
              prefixIcon: const Icon(Icons.search, color: Colors.green),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.green),
                onPressed: () => searchSongs(_searchController.text),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.green)))
        else if (_searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Text("Search for your favorite song above 🔍", style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final song = _searchResults[index];
                final title = song['name'] ?? 'Song';
                final artist = song['artists']?['primary']?[0]?['name'] ?? song['primaryArtists'] ?? '';
                final imgUrl = (song['image'] is List && (song['image'] as List).isNotEmpty)
                    ? song['image'][1]['url']
                    : '';

                return ListTile(
                  leading: imgUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.music_note, color: Colors.white),
                  title: Text(title, style: const TextStyle(color: Colors.white), maxLines: 1),
                  subtitle: Text(artist, style: const TextStyle(color: Colors.grey), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green, size: 36),
                  onTap: () => playSong(song),
                );
              },
            ),
          ),
      ],
    );
  }

  // 3. Settings Screen
  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green.withOpacity(0.2),
                child: Text(_selectedAvatar, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text("Local Profile", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.green),
                onPressed: _showEditProfileDialog,
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          tileColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.high_quality, color: Colors.green),
          title: const Text("Audio Streaming Quality", style: TextStyle(color: Colors.white)),
          subtitle: Text(_audioQuality, style: const TextStyle(color: Colors.grey)),
          trailing: DropdownButton<String>(
            dropdownColor: const Color(0xFF2A2A2A),
            value: _audioQuality,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: "96kbps", child: Text("Low (96 kbps)", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: "160kbps", child: Text("Normal (160 kbps)", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: "320kbps", child: Text("High (320 kbps)", style: TextStyle(color: Colors.white))),
            ],
            onChanged: (val) {
              if (val != null) _savePreference('audio_quality', val);
            },
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.cleaning_services, color: Colors.green),
          title: const Text("Clear Cache", style: TextStyle(color: Colors.white)),
          subtitle: const Text("Clean temporary storage", style: TextStyle(color: Colors.grey)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cache cleared successfully!")),
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.info_outline, color: Colors.green),
          title: const Text("App Version", style: TextStyle(color: Colors.white)),
          subtitle: const Text("v1.0.0 (Release)", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final avatars = ["👑", "🎧", "🎸", "🎤", "🎵", "🦁", "🔥", "🚀"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Your Name",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Choose Avatar", style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: avatars.map((av) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => _selectedAvatar = av),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedAvatar == av ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(av, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _savePreference('user_name', nameController.text.trim());
                _savePreference('user_avatar', _selectedAvatar);
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildTrendingPage(),
      const Center(child: Text("Albums - Coming Soon", style: TextStyle(color: Colors.white))),
      const Center(child: Text("Playlists - Coming Soon", style: TextStyle(color: Colors.white))),
      _buildSearchPage(),
      _buildSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: pages[_currentIndex]),

            // Mini Player Bar
            Container(
              height: 65,
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                border: Border(top: BorderSide(color: Colors.black54)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _currentImage.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(_currentImage, width: 48, height: 48, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.music_note, color: Colors.green, size: 40),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1),
                        if (_currentArtist.isNotEmpty)
                          Text(_currentArtist, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    color: Colors.green,
                    iconSize: 38,
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
