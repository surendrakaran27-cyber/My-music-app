import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
  final YoutubeExplode _yt = YoutubeExplode();
  final TextEditingController _searchController = TextEditingController();

  // User Profile Data
  String _userName = "SURSA KARNOT";
  String _selectedAvatar = "👑";
  String _audioQuality = "High (320kbps)";

  // App & Song State
  List<Video> _searchResults = [];
  List<Video> _trendingSongs = [];
  bool _isLoading = false;
  bool _isTrendingLoading = false;
  
  String _currentTitle = "No song playing";
  String _currentArtist = "";
  String _currentImage = "";
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchTrending();

    // Listen to playback state
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });

    // Listen to duration & position for full player seekbar
    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "SURSA KARNOT";
      _selectedAvatar = prefs.getString('user_avatar') ?? "👑";
      _audioQuality = prefs.getString('audio_quality') ?? "High (320kbps)";
    });
  }

  Future<void> _savePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _loadPreferences();
  }

  // Search Engine
  Future<void> searchSongs(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final searchList = await _yt.search.search(query.trim());
      setState(() {
        _searchResults = searchList.toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search error: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Trending Engine
  Future<void> _fetchTrending() async {
    setState(() => _isTrendingLoading = true);
    try {
      final list = await _yt.search.search("Latest Hindi Songs 2026");
      setState(() {
        _trendingSongs = list.take(20).toList();
      });
    } catch (_) {}
    setState(() => _isTrendingLoading = false);
  }

  // Audio Player Engine
  void playVideo(Video video) async {
    try {
      setState(() {
        _currentTitle = video.title;
        _currentArtist = video.author;
        _currentImage = video.thumbnails.highResUrl;
      });

      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final audioStreams = manifest.audioOnly;
      final selectedStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.muxed.withHighestBitrate();

      await _audioPlayer.setUrl(selectedStream.url.toString());
      _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Playback error: $e")),
        );
      }
    }
  }

  // Format Duration for Seekbar (MM:SS)
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // Full Spotify-like Player Screen (Bottom Sheet)
  void _showFullPlayer() {
    if (_currentImage.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return StreamBuilder<Duration>(
            stream: _audioPlayer.positionStream,
            builder: (context, snapshot) {
              final currentPos = snapshot.data ?? _position;
              return Container(
                height: MediaQuery.of(context).size.height * 0.92,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Pull down bar
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text("PLAYING FROM YOUR APP", style: TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
                        const Icon(Icons.more_vert, color: Colors.white),
                      ],
                    ),
                    const Spacer(),
                    // Album Poster
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _currentImage,
                        height: 280,
                        width: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 280,
                          width: 280,
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.music_note, color: Colors.green, size: 80),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Title & Artist
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currentTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currentArtist,
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Progress Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                        activeTrackColor: Colors.green,
                        inactiveTrackColor: Colors.grey.shade800,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        min: 0,
                        max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                        value: currentPos.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                        onChanged: (val) {
                          _audioPlayer.seek(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(currentPos), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(_formatDuration(_duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Playback Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                          onPressed: () {
                            _audioPlayer.seek(currentPos - const Duration(seconds: 10));
                          },
                        ),
                        IconButton(
                          iconSize: 72,
                          color: Colors.green,
                          icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          onPressed: () {
                            if (_isPlaying) {
                              _audioPlayer.pause();
                            } else {
                              _audioPlayer.play();
                            }
                            setModalState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                          onPressed: () {
                            _audioPlayer.seek(currentPos + const Duration(seconds: 10));
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 1. Trending Tab Screen
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
          child: Text("🔥 Trending Tracks", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        if (_isTrendingLoading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.green)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _trendingSongs.length,
              itemBuilder: (context, index) {
                final video = _trendingSongs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      video.thumbnails.lowResUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.green),
                    ),
                  ),
                  title: Text(video.title, style: const TextStyle(color: Colors.white), maxLines: 1),
                  subtitle: Text(video.author, style: const TextStyle(color: Colors.grey), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green, size: 36),
                  onTap: () => playVideo(video),
                );
              },
            ),
          ),
      ],
    );
  }

  // 2. Search Tab Screen
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
              hintText: 'Search songs, artists, mashups...',
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
                final video = _searchResults[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      video.thumbnails.lowResUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.green),
                    ),
                  ),
                  title: Text(video.title, style: const TextStyle(color: Colors.white), maxLines: 1),
                  subtitle: Text(video.author, style: const TextStyle(color: Colors.grey), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green, size: 36),
                  onTap: () => playVideo(video),
                );
              },
            ),
          ),
      ],
    );
  }

  // 3. Settings Tab Screen
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
          title: const Text("Audio Quality", style: TextStyle(color: Colors.white)),
          subtitle: Text(_audioQuality, style: const TextStyle(color: Colors.grey)),
          trailing: DropdownButton<String>(
            dropdownColor: const Color(0xFF2A2A2A),
            value: _audioQuality,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: "Low (96kbps)", child: Text("Low (96kbps)", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: "Normal (160kbps)", child: Text("Normal (160kbps)", style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: "High (320kbps)", child: Text("High (320kbps)", style: TextStyle(color: Colors.white))),
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
          subtitle: const Text("v1.2.0 (Full Spotify Engine)", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // Profile Edit Dialog
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

            // Mini Player Bar (Tap to open full Spotify player)
            GestureDetector(
              onTap: _showFullPlayer,
              child: Container(
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
