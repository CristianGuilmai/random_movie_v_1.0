const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const axios = require('axios');
const crypto = require('crypto');
const redis = require('redis');
require('dotenv').config({ path: './config.env' });

const app = express();
const PORT = process.env.PORT || 3000;
console.log('🚀 Servidor iniciando con endpoints actualizados...');

// ===== CONFIGURACIÓN DE REDIS CACHE =====
let redisClient;
const CACHE_TTL = 3600; // 1 hora en segundos

// Inicializar Redis (opcional, fallback a memoria si no está disponible)
const initRedis = async () => {
  try {
    if (process.env.REDIS_URL) {
      redisClient = redis.createClient({
        url: process.env.REDIS_URL
      });
      await redisClient.connect();
      console.log('✅ Redis conectado exitosamente');
    } else {
      console.log('⚠️ Redis no configurado, usando cache en memoria');
    }
  } catch (error) {
    console.log('⚠️ Redis no disponible, usando cache en memoria:', error.message);
  }
};

// Cache en memoria como fallback
const memoryCache = new Map();

// Función para obtener datos del cache
const getFromCache = async (key) => {
  try {
    if (redisClient && redisClient.isOpen) {
      const cached = await redisClient.get(key);
      return cached ? JSON.parse(cached) : null;
    } else {
      return memoryCache.get(key) || null;
    }
  } catch (error) {
    console.log('❌ Error obteniendo del cache:', error.message);
    return null;
  }
};

// Función para guardar datos en el cache
const setCache = async (key, data, ttl = CACHE_TTL) => {
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.setEx(key, ttl, JSON.stringify(data));
    } else {
      memoryCache.set(key, data);
      // Limpiar cache en memoria después del TTL
      setTimeout(() => memoryCache.delete(key), ttl * 1000);
    }
  } catch (error) {
    console.log('❌ Error guardando en cache:', error.message);
  }
};

// Inicializar Redis al arrancar
initRedis();

// ===== MIDDLEWARE =====
// Middleware de seguridad
app.use(helmet());
app.use(express.json({ limit: '10mb' }));

// CORS configurado
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];
    if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('No permitido por CORS'));
    }
  },
  credentials: true
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: {
    error: 'Demasiadas solicitudes, intenta más tarde',
    retryAfter: Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000) / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// ===== VALIDACIÓN DE APP SIGNATURE =====
const validateAppSignature = (req, res, next) => {
  const signature = req.headers['x-app-signature'];
  const expectedSignature = process.env.APP_SIGNATURE;
  
  if (!signature || signature !== expectedSignature) {
    return res.status(401).json({ 
      error: 'App signature inválida',
      code: 'INVALID_SIGNATURE'
    });
  }
  next();
};

// ===== ENDPOINTS BÁSICOS =====
// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Randomovie API v1.0',
    version: '1.0.0',
    endpoints: {
      movies: '/api/movies/*',
      people: '/api/people/*',
      search: '/api/search/*',
      recommendations: '/api/recommendations'
    },
    documentation: 'https://github.com/your-repo/randomovie-api'
  });
});

// ===== ENDPOINTS DE PELÍCULAS =====
// Películas en cartelera
app.get('/api/movies/now-playing', validateAppSignature, async (req, res) => {
  try {
    const { page = 1, language = 'es-ES', include_adult = 'true' } = req.query;

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    // Crear clave de cache única
    const cacheKey = `now_playing:${language}:${page}:${include_adult}`;
    
    // Intentar obtener del cache primero
    const cachedData = await getFromCache(cacheKey);
    if (cachedData) {
      console.log('📦 Cache HIT para now-playing');
      return res.json({
        success: true,
        data: cachedData.data,
        pagination: cachedData.pagination,
        timestamp: new Date().toISOString(),
        cached: true
      });
    }
    
    console.log('🌐 Cache MISS, llamando a TMDB para now-playing');
    const response = await axios.get('https://api.themoviedb.org/3/movie/now_playing', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        page: page,
        include_adult: include_adult === 'true'
      },
      timeout: 10000
    });

    const data = {
      data: response.data.results,
      pagination: {
        page: response.data.page,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results
      }
    };
    
    // Guardar en cache
    await setCache(cacheKey, data);
    console.log('💾 Datos guardados en cache para now-playing');

    res.json({
      success: true,
      data: response.data.results,
      pagination: {
        page: response.data.page,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results
      },
      timestamp: new Date().toISOString(),
      cached: false
    });

  } catch (error) {
    console.error('Error en now-playing:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'NOW_PLAYING_ERROR'
    });
  }
});

// Películas trending
app.get('/api/movies/trending', validateAppSignature, async (req, res) => {
  try {
    const { page = 1, language = 'es-ES', include_adult = 'true' } = req.query;

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get('https://api.themoviedb.org/3/trending/movie/week', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        page: page,
        include_adult: include_adult === 'true'
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data.results,
      pagination: {
        page: response.data.page,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en trending:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'TRENDING_ERROR'
    });
  }
});

// Próximos estrenos
app.get('/api/movies/upcoming', validateAppSignature, async (req, res) => {
  try {
    const { page = 1, language = 'es-ES', include_adult = 'true' } = req.query;

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get('https://api.themoviedb.org/3/discover/movie', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        with_release_type: '2|3',
        'release_date.gte': new Date().toISOString().split('T')[0],
        'release_date.lte': new Date(Date.now() + 120 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        sort_by: 'popularity.desc',
        include_adult: include_adult === 'true',
        page: page
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data.results,
      pagination: {
        page: response.data.page,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en upcoming:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'UPCOMING_ERROR'
    });
  }
});

// ===== NUEVOS ENDPOINTS: CAST, CREW Y CREDITS =====

// Obtener reparto completo (cast y crew)
app.get('/api/movies/:id/credits', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎬 Obteniendo credits para película ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/credits`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: {
        id: response.data.id,
        cast: response.data.cast || [],
        crew: response.data.crew || []
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo credits:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'CREDITS_ERROR',
      details: error.message
    });
  }
});

// Obtener solo el cast (actores)
app.get('/api/movies/:id/cast', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES', limit = 20 } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`👥 Obteniendo cast para película ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/credits`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    const cast = response.data.cast || [];
    const limitedCast = limit ? cast.slice(0, parseInt(limit)) : cast;

    res.json({
      success: true,
      data: limitedCast,
      count: limitedCast.length,
      total: cast.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo cast:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'CAST_ERROR',
      details: error.message
    });
  }
});

// Obtener solo el crew (equipo técnico)
app.get('/api/movies/:id/crew', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES', department } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎥 Obteniendo crew para película ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/credits`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    let crew = response.data.crew || [];

    // Filtrar por departamento si se especifica
    if (department) {
      crew = crew.filter(member => 
        member.department?.toLowerCase() === department.toLowerCase()
      );
    }

    res.json({
      success: true,
      data: crew,
      count: crew.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo crew:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'CREW_ERROR',
      details: error.message
    });
  }
});

// ===== NUEVO ENDPOINT: PROVEEDORES DE STREAMING =====

// Obtener proveedores de streaming
app.get('/api/movies/:id/providers', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { country = 'US' } = req.query; // US por defecto, puedes cambiarlo a 'CL' para Chile

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`📺 Obteniendo proveedores para película ID: ${id}, país: ${country}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/watch/providers`, {
      params: {
        api_key: process.env.TMDB_API_KEY
      },
      timeout: 10000
    });

    const results = response.data.results || {};
    const countryData = results[country.toUpperCase()] || null;

    res.json({
      success: true,
      data: {
        id: response.data.id,
        country: country.toUpperCase(),
        providers: countryData,
        available_countries: Object.keys(results)
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo proveedores:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'PROVIDERS_ERROR',
      details: error.message
    });
  }
});

// ===== NUEVO ENDPOINT: VIDEOS/TRAILERS =====

// Obtener videos y trailers
app.get('/api/movies/:id/videos', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎞️ Obteniendo videos para película ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/videos`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    const videos = response.data.results || [];
    
    // Separar por tipo
    const trailers = videos.filter(v => v.type === 'Trailer');
    const teasers = videos.filter(v => v.type === 'Teaser');
    const clips = videos.filter(v => v.type === 'Clip');
    const featurettes = videos.filter(v => v.type === 'Featurette');

    res.json({
      success: true,
      data: {
        id: response.data.id,
        all_videos: videos,
        trailers: trailers,
        teasers: teasers,
        clips: clips,
        featurettes: featurettes,
        total_count: videos.length
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo videos:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'VIDEOS_ERROR',
      details: error.message
    });
  }
});

// ===== ENDPOINT COMBINADO (OPTIMIZADO) =====

// Obtener detalles completos de película (incluye todo en una llamada)
app.get('/api/movies/:id/complete', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES', country = 'US' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido',
        code: 'INVALID_MOVIE_ID'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎬 Obteniendo información completa para película ID: ${id}`);

    // Usar append_to_response para obtener todo en una sola llamada
    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        append_to_response: 'credits,videos,watch/providers,images,recommendations,similar'
      },
      timeout: 15000
    });

    const data = response.data;
    const providers = data['watch/providers']?.results?.[country.toUpperCase()] || null;

    res.json({
      success: true,
      data: {
        // Información básica
        id: data.id,
        title: data.title,
        original_title: data.original_title,
        overview: data.overview,
        poster_path: data.poster_path,
        backdrop_path: data.backdrop_path,
        release_date: data.release_date,
        runtime: data.runtime,
        vote_average: data.vote_average,
        vote_count: data.vote_count,
        popularity: data.popularity,
        genres: data.genres,
        
        // Cast y Crew
        cast: data.credits?.cast?.slice(0, 20) || [],
        crew: data.credits?.crew || [],
        director: data.credits?.crew?.find(person => person.job === 'Director'),
        
        // Videos
        trailers: data.videos?.results?.filter(v => v.type === 'Trailer') || [],
        all_videos: data.videos?.results || [],
        
        // Proveedores
        streaming_providers: providers,
        
        // Recomendaciones
        recommendations: data.recommendations?.results?.slice(0, 10) || [],
        similar: data.similar?.results?.slice(0, 10) || []
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo información completa:', error.message);
    
    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Película no encontrada',
        code: 'MOVIE_NOT_FOUND'
      });
    }

    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'COMPLETE_INFO_ERROR',
      details: error.message
    });
  }
});

// ===== ENDPOINTS DE BÚSQUEDA DE PERSONAS =====
// Búsqueda de personas (actores, directores)
app.post('/api/people/search', validateAppSignature, async (req, res) => {
  try {
    const { query, language = 'es-ES', page = 1 } = req.body;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({
        error: 'Query de búsqueda requerida',
        code: 'MISSING_QUERY'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🔍 Buscando persona: "${query}"`);

    const response = await axios.get('https://api.themoviedb.org/3/search/person', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        query: query,
        page: page,
        include_adult: true
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: {
        results: response.data.results,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results,
        page: response.data.page
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en búsqueda de personas:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'PEOPLE_SEARCH_ERROR'
    });
  }
});

// Obtener películas de una persona
app.get('/api/people/:id/movies', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de persona inválido' 
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎬 Obteniendo películas de persona ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/person/${id}/movie_credits`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    // Combinar cast y crew, eliminar duplicados
    const movies = new Map();
    
    if (response.data.cast) {
      response.data.cast.forEach(movie => {
        if (!movies.has(movie.id)) {
          movies.set(movie.id, {
            ...movie,
            role: 'actor',
            character: movie.character
          });
        }
      });
    }

    if (response.data.crew) {
      response.data.crew.forEach(movie => {
        if (!movies.has(movie.id)) {
          movies.set(movie.id, {
            ...movie,
            role: movie.job,
            department: movie.department
          });
        }
      });
    }

    const moviesList = Array.from(movies.values())
      .sort((a, b) => (b.popularity || 0) - (a.popularity || 0))
      .slice(0, 50);

    console.log(`✅ Encontradas ${moviesList.length} películas`);

    res.json({
      success: true,
      data: moviesList,
      count: moviesList.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo películas de persona:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'PERSON_MOVIES_ERROR'
    });
  }
});

// Obtener detalles de una persona
app.get('/api/people/:id', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de persona inválido' 
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`👤 Obteniendo detalles de persona ID: ${id}`);

    const response = await axios.get(`https://api.themoviedb.org/3/person/${id}`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo detalles de persona:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'PERSON_DETAILS_ERROR'
    });
  }
});

// ===== ENDPOINTS DE BÚSQUEDA INTELIGENTE =====
// Búsqueda inteligente con corrección de texto
app.post('/api/search/intelligent', validateAppSignature, async (req, res) => {
  try {
    const { query, language = 'es-ES' } = req.body;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({
        error: 'Query de búsqueda requerida',
        code: 'MISSING_QUERY'
      });
    }

    if (!process.env.GROQ_API_KEY || !process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API keys no configuradas',
        code: 'API_KEYS_MISSING'
      });
    }

    console.log(`🤖 Búsqueda inteligente: "${query}"`);

    // 1. Analizar con Groq
    const groqResponse = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'system',
            content: `Eres un experto en cine. Analiza la búsqueda del usuario y determina:
1. Tipo: "movie", "actor", "director" o "genre"
2. Nombre correcto EN INGLÉS (para TMDB)
3. Explicación amigable en español

Ejemplos:
- "hombre que nace viejo" → {"type":"movie","corrected":"The Curious Case of Benjamin Button","explanation":"¿Te refieres a 'El Curioso Caso de Benjamin Button'?"}
- "joni dip" → {"type":"actor","corrected":"Johnny Depp","explanation":"¿Te refieres a Johnny Depp?"}
- "kenu revs" → {"type":"actor","corrected":"Keanu Reeves","explanation":"¿Te refieres a Keanu Reeves?"}
- "soldado ryan" → {"type":"movie","corrected":"Saving Private Ryan","explanation":"¿Te refieres a 'Rescatando al Soldado Ryan'?"}
- "spielber" → {"type":"director","corrected":"Steven Spielberg","explanation":"¿Te refieres a Steven Spielberg?"}
- "cristopher nolan" → {"type":"director","corrected":"Christopher Nolan","explanation":"¿Te refieres a Christopher Nolan?"}

IMPORTANTE:
- Nombres de películas SIEMPRE en inglés
- Nombres de personas SIEMPRE en inglés
- Explicación SIEMPRE en español
- Sé tolerante con errores ortográficos graves

Responde SOLO en JSON válido sin markdown ni formato adicional:
{"type":"...","corrected":"...","explanation":"..."}`
          },
          {
            role: 'user',
            content: query
          }
        ],
        temperature: 0.3,
        max_completion_tokens: 200
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      }
    );

    let analysis;
    try {
      const content = groqResponse.data.choices[0].message.content.trim();
      const cleanContent = content.replace(/```json|```/g, '').trim();
      analysis = JSON.parse(cleanContent);
    } catch (e) {
      console.error('Error parseando respuesta de Groq:', e);
      return res.status(500).json({
        error: 'Error procesando análisis',
        code: 'GROQ_PARSE_ERROR'
      });
    }

    console.log('🎯 Análisis:', analysis);

    // 2. Buscar en TMDB según el tipo
    let results = [];
    let searchType = analysis.type || 'movie';

    if (searchType === 'actor' || searchType === 'director') {
      // Buscar persona
      const personSearch = await axios.get('https://api.themoviedb.org/3/search/person', {
        params: {
          api_key: process.env.TMDB_API_KEY,
          language: language,
          query: analysis.corrected,
          include_adult: true
        },
        timeout: 10000
      });

      if (personSearch.data.results && personSearch.data.results.length > 0) {
        const personId = personSearch.data.results[0].id;
        
        // Obtener películas de la persona
        const creditsResponse = await axios.get(`https://api.themoviedb.org/3/person/${personId}/movie_credits`, {
          params: {
            api_key: process.env.TMDB_API_KEY,
            language: language
          },
          timeout: 10000
        });

        // Combinar cast y crew según el tipo
        if (searchType === 'actor') {
          results = creditsResponse.data.cast || [];
        } else {
          // Para directores, filtrar solo trabajos de dirección
          const crewMovies = creditsResponse.data.crew || [];
          results = crewMovies.filter(movie => movie.job === 'Director');
        }

        // Ordenar por popularidad
        results.sort((a, b) => (b.popularity || 0) - (a.popularity || 0));
      }
    } else {
      // Buscar película
      const movieSearch = await axios.get('https://api.themoviedb.org/3/search/movie', {
        params: {
          api_key: process.env.TMDB_API_KEY,
          language: language,
          query: analysis.corrected,
          include_adult: true
        },
        timeout: 10000
      });

      results = movieSearch.data.results || [];
    }

    console.log(`✅ Encontrados ${results.length} resultados`);

    res.json({
      success: true,
      data: {
        correctedQuery: analysis.corrected,
        explanation: analysis.explanation || `¿Te refieres a "${analysis.corrected}"?`,
        type: searchType,
        results: results.slice(0, 50),
        count: results.length
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en búsqueda inteligente:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'INTELLIGENT_SEARCH_ERROR',
      details: error.message
    });
  }
});

// ===== ENDPOINTS ADICIONALES DE PELÍCULAS =====
// Detalles de película
app.get('/api/movies/:id', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { language = 'es-ES' } = req.query;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido' 
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo detalles de película:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'MOVIE_DETAILS_ERROR'
    });
  }
});

// Búsqueda de películas
app.post('/api/movies/search', validateAppSignature, async (req, res) => {
  try {
    const { query, language = 'es-ES', page = 1, include_adult = true } = req.body;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({
        error: 'Query de búsqueda requerida',
        code: 'MISSING_QUERY'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get('https://api.themoviedb.org/3/search/movie', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        query: query,
        page: page,
        include_adult: include_adult
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: {
        results: response.data.results,
        total_pages: response.data.total_pages,
        total_results: response.data.total_results,
        page: response.data.page
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en búsqueda de películas:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'MOVIE_SEARCH_ERROR'
    });
  }
});

// Película aleatoria
app.post('/api/movies/random', validateAppSignature, async (req, res) => {
  try {
    const { 
      genres = [], 
      language = 'es-ES', 
      yearStart = 1900, 
      yearEnd = new Date().getFullYear(),
      minVotes = 0,
      excludeAdult = false 
    } = req.body;

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const params = {
      api_key: process.env.TMDB_API_KEY,
      language: language,
      include_adult: !excludeAdult,
      'vote_count.gte': minVotes,
      'release_date.gte': `${yearStart}-01-01`,
      'release_date.lte': `${yearEnd}-12-31`,
      sort_by: 'popularity.desc'
    };

    if (genres.length > 0) {
      params.with_genres = genres.join(',');
    }

    const response = await axios.get('https://api.themoviedb.org/3/discover/movie', {
      params,
      timeout: 10000
    });

    const results = response.data.results;
    if (results && results.length > 0) {
      const randomIndex = Math.floor(Math.random() * Math.min(results.length, 20));
      const randomMovie = results[randomIndex];

      res.json({
        success: true,
        data: randomMovie,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(404).json({
        error: 'No se encontraron películas con los criterios especificados',
        code: 'NO_MOVIES_FOUND'
      });
    }

  } catch (error) {
    console.error('Error obteniendo película aleatoria:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'RANDOM_MOVIE_ERROR'
    });
  }
});

// ===== ENDPOINTS DE RECOMENDACIONES =====
// Recomendaciones de IA
app.post('/api/recommendations', validateAppSignature, async (req, res) => {
  try {
    const { 
      userPreferences, 
      ratedMovies = [], 
      watchedMovies = [], 
      type = 'preferences' 
    } = req.body;

    if (!process.env.GROQ_API_KEY) {
      return res.status(500).json({
        error: 'API key de Groq no configurada',
        code: 'GROQ_API_KEY_MISSING'
      });
    }

    console.log(`🤖 Generando recomendaciones tipo: ${type}`);

    let systemPrompt = 'Eres un experto en recomendaciones de películas. Debes responder SOLO con una lista de títulos de películas separados por comas, sin numeración, sin explicaciones, sin texto adicional.';
    let userPrompt = '';
    
    if (type === 'preferences' && userPreferences) {
      userPrompt = `Basándote en estas preferencias: "${userPreferences}", recomienda exactamente 5 películas. Responde SOLO con los títulos separados por comas.`;
    } else if (type === 'ratings' && ratedMovies.length > 0) {
      const movieTitles = ratedMovies
        .map(m => `"${m.title || m.name}"`)
        .slice(0, 10)
        .join(', ');
      userPrompt = `Basándote en que al usuario le gustaron estas películas: ${movieTitles}, recomienda exactamente 5 películas similares. Responde SOLO con los títulos separados por comas.`;
    } else if (type === 'watched' && watchedMovies.length > 0) {
      const movieTitles = watchedMovies
        .map(m => `"${m.title || m.name}"`)
        .slice(0, 10)
        .join(', ');
      userPrompt = `El usuario ha visto estas películas: ${movieTitles}. Recomienda exactamente 5 películas que podrían gustarle. Responde SOLO con los títulos separados por comas.`;
    } else {
      return res.status(400).json({
        error: 'Datos insuficientes para generar recomendaciones',
        code: 'INSUFFICIENT_DATA'
      });
    }

    const groqResponse = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'system',
            content: systemPrompt
          },
          {
            role: 'user',
            content: userPrompt
          }
        ],
        temperature: 0.7,
        max_completion_tokens: 300,
        top_p: 1,
        stream: false
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    const content = groqResponse.data.choices[0].message.content.trim();
    const recommendations = content
      .split(',')
      .map(title => title.trim())
      .filter(title => title.length > 0)
      .slice(0, 5);

    if (recommendations.length === 0) {
      return res.status(500).json({
        error: 'No se pudieron generar recomendaciones',
        code: 'NO_RECOMMENDATIONS_GENERATED'
      });
    }

    res.json({
      success: true,
      data: recommendations,
      count: recommendations.length,
      model_used: 'llama-3.3-70b-versatile',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en recomendaciones:', error.message);
    res.status(500).json({
      error: 'Error al generar recomendaciones',
      code: 'RECOMMENDATIONS_ERROR',
      details: error.message
    });
  }
});

// ===== INICIAR SERVIDOR =====
const server = app.listen(PORT, () => {
  console.log(`🚀 Servidor ejecutándose en puerto ${PORT}`);
  console.log(`📡 Endpoints disponibles:`);
  console.log(`   - GET  /health`);
  console.log(`   - GET  /api/movies/now-playing`);
  console.log(`   - GET  /api/movies/trending`);
  console.log(`   - GET  /api/movies/upcoming`);
  console.log(`   - GET  /api/movies/:id`);
  console.log(`   - GET  /api/movies/:id/complete (NUEVO - Todo en 1)`);
  console.log(`   - GET  /api/movies/:id/credits (NUEVO)`);
  console.log(`   - GET  /api/movies/:id/cast (NUEVO)`);
  console.log(`   - GET  /api/movies/:id/crew (NUEVO)`);
  console.log(`   - GET  /api/movies/:id/providers (NUEVO)`);
  console.log(`   - GET  /api/movies/:id/videos (NUEVO)`);
  console.log(`   - POST /api/movies/search`);
  console.log(`   - POST /api/movies/random`);
  console.log(`   - POST /api/people/search`);
  console.log(`   - GET  /api/people/:id/movies`);
  console.log(`   - GET  /api/people/:id`);
  console.log(`   - POST /api/search/intelligent`);
  console.log(`   - POST /api/recommendations`);
});

// Manejo de señales para cierre graceful
process.on('SIGINT', () => {
  console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
  server.close(() => {
    console.log('✅ Servidor cerrado correctamente');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
  server.close(() => {
    console.log('✅ Servidor cerrado correctamente');
    process.exit(0);
  });
});
