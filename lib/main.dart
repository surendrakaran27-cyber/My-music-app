import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MaterialApp(home: MusicApp(), debugShowCheckedModeBanner: false));

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _controller = TextEditingController();
  List songs = [];
  bool isLoading = false;
  String currentSong = "";

  void searchMusic(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => isLoading = true);
    final url = Uri.parse("https://saavn.dev/api/search/songs?query=$query");
    try {
      final res = await http.get(url);
      final data = jsonDecode(res.body);
      setState(() {
        songs = data['data']['results'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void playSong(String url, String title) async {
    try {
      setState(() => currentSong = title);
      await _player.setUrl(url);
      _player.play();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("गाना प्ले करने में समस्या आई")),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("My Music", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "गाना या आर्टिस्ट सर्च करें...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF282828),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.green),
                  onPressed: () => searchMusic(_controller.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: searchMusic,
            ),
          ),
          if (isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.green),
            )),
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final title = song['name'] ?? 'Unknown';
                final downloadUrls = song['downloadUrl'] as List?;
                final audioUrl = (downloadUrls != null && downloadUrls.isNotEmpty)
                    ? downloadUrls.last['url']
                    : null;
                final imageUrl = (song['image'] != null && (song['image'] as List).isNotEmpty)
                    ? song['image'].last['url']
                    : '';

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.music_note, color: Colors.white))
                        : const Icon(Icons.music_note, color: Colors.white),
                  ),
                  title: Text(title, style: const TextStyle(color: Colors.white), maxLines: 1),
                  subtitle: Text(song['primaryArtists'] ?? '', style: TextStyle(color: Colors.grey[400]), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                  onTap: () {
                    if (audioUrl != null) {
                      playSong(audioUrl, title);
                    }
                  },
                );
              },
            ),
          ),
          if (currentSong.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF282828),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentSong,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: () {
                          if (isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
