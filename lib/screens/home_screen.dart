import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/interactive_chat_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/tmdb_service.dart';
import '../services/secure_service.dart';
import '../state/app_state.dart';
import '../models/movie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedGenreKey;
  List<Movie> _now = [];
  List<Movie> _trending = [];
  List<Movie> _upcoming = [];
  bool _loadingNow = true;
  bool _loadingTrending = true;
  bool _loadingUpcoming = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _selectedGenreKey = app.lastSelectedGenreKey;
    _loadNowPlaying();
    _loadTrending();
    _loadUpcoming();
  }

  Future<void> _loadNowPlaying() async {
    try {
      final data = await SecureService.fetchNowPlaying();

      // Obtener detalles completos (cast) para cada película
      final moviesWithCast = <Movie>[];
      for (final movie in data.take(10)) { // Limitar a 10 para rendimiento
        final cast = await SecureService.getMovieCast(movieId: movie.id);
        final movieWithDetails = movie.copyWith(cast: cast);
        moviesWithCast.add(movieWithDetails);
      }

      if (mounted) {
        setState(() {
          _now = moviesWithCast;
          _loadingNow = false;
        });
      }
    } catch (e) {
      print('Error fetching now playing: $e');
      if (mounted) {
        setState(() {
          _loadingNow = false;
        });
      }
    }
  }

  Future<void> _loadTrending() async {
    try {
      final data = await SecureService.fetchTrending();

      // Obtener detalles completos (cast) para cada película
      final moviesWithCast = <Movie>[];
      for (final movie in data.take(10)) { // Limitar a 10 para rendimiento
        final cast = await SecureService.getMovieCast(movieId: movie.id);
        final movieWithDetails = movie.copyWith(cast: cast);
        moviesWithCast.add(movieWithDetails);
      }

      if (mounted) {
        setState(() {
          _trending = moviesWithCast;
          _loadingTrending = false;
        });
      }
    } catch (e) {
      print('Error fetching trending: $e');
      if (mounted) {
        setState(() {
          _loadingTrending = false;
        });
      }
    }
  }

  Future<void> _loadUpcoming() async {
    try {
      final data = await SecureService.fetchUpcoming();

      // Obtener detalles completos (cast) para cada película
      final moviesWithCast = <Movie>[];
      for (final movie in data.take(10)) { // Limitar a 10 para rendimiento
        final cast = await SecureService.getMovieCast(movieId: movie.id);
        final movieWithDetails = movie.copyWith(cast: cast);
        moviesWithCast.add(movieWithDetails);
      }

      if (mounted) {
        setState(() {
          _upcoming = moviesWithCast;
          _loadingUpcoming = false;
        });
      }
    } catch (e) {
      print('Error fetching upcoming: $e');
      if (mounted) {
        setState(() {
          _loadingUpcoming = false;
        });
      }
    }
  }
  Widget _buildMovieCarousel(String title, List<Movie> movies, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : movies.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: movies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final m = movies[index];
                        return InkWell(
                          onTap: () => context.pushNamed('detail', extra: m),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (m.posterUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: m.posterUrl!, 
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade800,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade800,
                                        child: const Icon(Icons.movie, color: Colors.white),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey.shade800,
                                      child: const Icon(Icons.movie, color: Colors.white),
                                    ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.8),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (m.voteAverage > 0)
                                            Text(
                                              '⭐ ${m.voteAverage.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.yellow,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('MoodChatWidget está construyéndose'); // Debug
    final app = context.watch<AppState>();

    // Generar lista completa de años desde 1900 hasta el año actual
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(currentYear - 1900 + 1, (i) => 1900 + i);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Randomovie'),
        actions: [
          // Botón de debug (solo en modo debug)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                print('🔍 DEBUG: Ejecutando debug completo...');
                await SecureService.debugFullFlow();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debug ejecutado. Revisa los logs.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.pushNamed('settings'),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text('Menú', style: TextStyle(fontSize: 20)),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('Ver después'),
                onTap: () => context.pushNamed('favorites'),
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Ya vistas'),
                onTap: () => context.pushNamed('watched'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Historial de búsqueda'),
                onTap: () => context.pushNamed('history'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configuración'),
                onTap: () => context.pushNamed('settings'),
              ),
            ],
          ),
        ),
      ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRIMERA SECCIÓN: Chat de estado de ánimo con carousel
                const InteractiveChatWidget(),

                const SizedBox(height: 32),

                // SEGUNDA SECCIÓN: Buscar película al azar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título de la sección
                      Row(
                        children: [
                          Icon(
                            Icons.casino,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Buscar película al azar',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Contenido de búsqueda
                      const Text('Selecciona un género'),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _selectedGenreKey,
                        isExpanded: true,
                        hint: const Text('Género'),
                        items: TmdbService.genres.keys
                            .map(
                              (key) => DropdownMenuItem(
                            value: key,
                            child: Text(key),
                          ),
                        )
                            .toList(),
                        onChanged: (value) async {
                          setState(() => _selectedGenreKey = value);
                          await app.setLastGenreKey(value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Filtros de año
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<int>(
                              value: app.yearStart,
                              isExpanded: true,
                              style: Theme.of(context).textTheme.bodySmall,
                              items: years
                                  .where((y) => y <= currentYear)
                                  .map((y) => DropdownMenuItem(
                                    value: y, 
                                    child: Text('Desde $y', style: Theme.of(context).textTheme.bodySmall),
                                  ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                final start = v;
                                var end = app.yearEnd;
                                if (start > end) {
                                  end = currentYear;
                                }
                                app.setYearRange(start, end);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<int>(
                              value: app.yearEnd,
                              isExpanded: true,
                              style: Theme.of(context).textTheme.bodySmall,
                              items: years
                                  .where((y) => y >= app.yearStart && y <= currentYear)
                                  .map((y) => DropdownMenuItem(
                                    value: y, 
                                    child: Text('Hasta $y', style: Theme.of(context).textTheme.bodySmall),
                                  ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                int end = v;
                                int start = app.yearStart;
                                app.setYearRange(start, end);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Filtrar por puntuación'),
                        subtitle: app.useRatingFilter
                            ? Text('${app.minRating.toStringAsFixed(1)} - ${app.maxRating.toStringAsFixed(1)} ⭐')
                            : const Text('Sin filtro de puntuación'),
                        value: app.useRatingFilter,
                        onChanged: (value) => app.setUseRatingFilter(value),
                      ),

                      if (app.useRatingFilter) ...[
                        const SizedBox(height: 8),
                        const Text('Rango de puntuación:', style: TextStyle(fontWeight: FontWeight.w500)),
                        RangeSlider(
                          values: RangeValues(app.minRating, app.maxRating),
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          labels: RangeLabels(
                            app.minRating.toStringAsFixed(1),
                            app.maxRating.toStringAsFixed(1),
                          ),
                          onChanged: (RangeValues values) {
                            app.setRatingRange(values.start, values.end);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _selectedGenreKey == null
                              ? null
                              : () => context.pushNamed('results', extra: _selectedGenreKey),
                          icon: const Icon(Icons.casino, size: 18),
                          label: const Text('Buscar película', style: TextStyle(fontSize: 14)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pushNamed('advanced-search'),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Búsqueda avanzada', style: TextStyle(fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildMovieCarousel('Estrenos', _now, _loadingNow),
                      const SizedBox(height: 24),

                      _buildMovieCarousel('Más votadas esta semana', _trending, _loadingTrending),
                      const SizedBox(height: 24),

                      _buildMovieCarousel('Próximos estrenos', _upcoming, _loadingUpcoming),
                      
                      // Banner Ad
                      const SizedBox(height: 24),
                      const Center(
                        child: BannerAdWidget(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}