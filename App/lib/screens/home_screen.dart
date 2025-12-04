import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/playlist_screen.dart';
import '../services/database_service.dart';
import '../models/track.dart';
import 'dart:math' as math; 

class MyHomeScreen extends StatefulWidget {
  final DatabaseService dbService; 
  const MyHomeScreen({super.key, required this.dbService});

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0; 
  bool _isLoading = true;
  int _currentTrackIndex = 0;
  List<Track> _recommendations = [];
  String _currentStrategy = "Cold Start"; 

  double _dragX = 0.0;
  double _startDragX = 0.0;
  late final AnimationController _animationController;
  final double _swipeThreshold = 100.0;

  void _resetCardAnimationListener() {
    setState(() {
      _dragX = _startDragX * (1.0 - _animationController.value); 
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addListener(_resetCardAnimationListener);

    _fetchHybridRecommendations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchHybridRecommendations() async {
    setState(() {
      _isLoading = true;
    });
    
    final int interactionCount = await widget.dbService.countInteractions();
    
    final List<Track> tracks;
    if (interactionCount < 5) {
      tracks = await widget.dbService.getColdStartTracks();
      _currentStrategy = "Démarrage à Froid";
    } else {
      tracks = await widget.dbService.getHybridRecommendations();
      _currentStrategy = "Hybride (Personnalisé)";
    }

    setState(() {
      _recommendations = tracks;
      _isLoading = false;
      _currentTrackIndex = 0;
      print("LOG: Nouvelle session. Stratégie actuelle: $_currentStrategy. Morceaux: ${_recommendations.length}");
    });
  }

  void _onSwipe(bool liked) async { 
    if (_recommendations.isEmpty) return;

    final Track currentTrack = _recommendations[_currentTrackIndex];
    final int status = liked ? 1 : -1;

    await widget.dbService.updateInteraction(currentTrack.trackId, status);
    
    setState(() {
      _currentTrackIndex++;
      _dragX = 0.0; 
      _startDragX = 0.0;
    });

    if (_currentTrackIndex >= _recommendations.length) {
      await _fetchHybridRecommendations(); 
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final double finalX = _dragX;
    final bool liked = finalX > 0;
    
    if (finalX.abs() > _swipeThreshold) {
      _animateAndCompleteSwipe(liked);
    } else {
      _resetCard();
    }
  }

  void _resetCard() {
    _startDragX = _dragX;
    _animationController.removeListener(_resetCardAnimationListener);
    _animationController.addListener(_resetCardAnimationListener);
    _animationController.reverse(from: 1.0);
  }

  void _animateAndCompleteSwipe(bool liked) {
    if (_recommendations.isEmpty) return;
    
    final double targetX = liked ? 1000.0 : -1000.0; 
    final double startX = _dragX;
    
    final offScreenListener = () {
      setState(() {
        _dragX = Tween<double>(begin: startX, end: targetX)
            .evaluate(_animationController);
      });
    };

    _animationController.removeListener(_resetCardAnimationListener); 
    _animationController.addListener(offScreenListener);

    _animationController.forward(from: 0.0).then((_) {
      _onSwipe(liked); 

      _animationController.removeListener(offScreenListener); 
      _animationController.reset(); 
      _animationController.addListener(_resetCardAnimationListener);
    });
  }
  
  void _onButtonSwipe(bool liked) {
      if (_recommendations.isEmpty) return;
      
      setState(() {
          _dragX = liked ? _swipeThreshold + 1 : -(_swipeThreshold + 1);
      });
      
      _animateAndCompleteSwipe(liked);
  }
  
  Widget _buildTrackCard(Track track) {
      return Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade700, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15.0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                track.trackArtist, 
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.white70, 
                  fontWeight: FontWeight.w300
                )
              ),
              const SizedBox(height: 8),
              Text(
                track.trackName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 15),
              Text(
                'Popularité: ${track.trackPopularity.toStringAsFixed(1)}\nStyle: ${track.clusterStyle}',
                style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.white60
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Chargement ($_currentStrategy)..."), 
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("Aucun morceau trouvé. Vérifiez la connexion à la BDD."),
        ),
      );
    }
    
    final Track trackActuel = _recommendations[_currentTrackIndex];

    final int nextIndex = (_currentTrackIndex + 1) % _recommendations.length;
    final Track trackSuivant = _recommendations.length > 1 ? _recommendations[nextIndex] : trackActuel;

    final double dragFactor = (_dragX.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final double angle = _dragX / 500 * (math.pi / 180 * 20); 

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("KEYRIL Recommandation ($_currentStrategy)"), 
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                if (_recommendations.length > 1) 
                  Transform.scale(
                    scale: 0.9 + (dragFactor * 0.1), 
                    child: _buildTrackCard(trackSuivant), 
                  ),

                GestureDetector(
                  onPanStart: (details) {
                      _startDragX = 0.0;
                      _animationController.stop();
                  },
                  onPanUpdate: (details) {
                      setState(() {
                          _dragX += details.delta.dx;
                      });
                  },
                  onPanEnd: _onPanEnd, 
                  child: Transform.translate(
                    offset: Offset(_dragX, 0),
                    child: Transform.rotate(
                      angle: angle,
                      child: _buildTrackCard(trackActuel),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FloatingActionButton(
                  heroTag: "dislikeBtn",
                  onPressed: () => _onButtonSwipe(false),
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.close, size: 30),
                ),
                const SizedBox(width: 40),
                FloatingActionButton(
                  heroTag: "likeBtn",
                  onPressed: () => _onButtonSwipe(true),
                  backgroundColor: Colors.green.shade400,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.favorite, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex, 
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music_rounded), label: "Playlist"),
        ],
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => PlaylistScreen(dbService: widget.dbService),
              ),
            ).then((_) {
              setState(() {
                _selectedIndex = 0;
              });
            });
          }
        },
      ),
    );
  }
}