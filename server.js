const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const axios = require('axios');
const crypto = require('crypto');
require('dotenv').config({ path: './config.env' });

const app = express();
const PORT = process.env.PORT || 3000;
console.log('🚀 Servidor iniciando con endpoints actualizados...');

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
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutos
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // 100 requests por ventana
  message: {
    error: 'Demasiadas solicitudes, intenta más tarde',
    retryAfter: Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000) / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Validación de app signature
const validateAppSignature = (req, res, next) => {
  const signature = req.headers['x-app-signature'];
  const expectedSignature = process.env.APP_SIGNATURE;
  
  if (!signature || signature !== expectedSignature) {
    return res.status(401).json({ 
      error: 'Acceso no autorizado',
      code: 'INVALID_SIGNATURE'
    });
  }
  next();
};

// Endpoint de salud
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    port: PORT
  });
});

// Endpoint de prueba
app.get('/', (req, res) => {
  res.json({
    message: 'Randomovie Backend está funcionando!',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    port: PORT,
    environment: process.env.NODE_ENV || 'development'
  });
});

// ===== RUTAS ESPECÍFICAS PRIMERO (ANTES DE LAS RUTAS CON PARÁMETROS) =====

// Endpoint para películas en cartelera (now playing) - RUTA ESPECÍFICA
app.get('/api/movies/now-playing', validateAppSignature, async (req, res) => {
  try {
    console.log('✅ Endpoint now-playing accedido');
    
    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }
    
    // Procesar parámetro page de la query string
    const page = parseInt(req.query.page) || 1;
    console.log(`📄 Procesando página: ${page}`);
    
    const response = await axios.get('https://api.themoviedb.org/3/movie/now_playing', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES',
        page: page
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data.results,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en now playing:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'NOW_PLAYING_ERROR'
    });
  }
});

// Endpoint para películas populares (trending) - RUTA ESPECÍFICA
app.get('/api/movies/trending', validateAppSignature, async (req, res) => {
  try {
    console.log('✅ Endpoint trending accedido');
    
    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }
    
    // Procesar parámetro page de la query string
    const page = parseInt(req.query.page) || 1;
    console.log(`📄 Procesando página: ${page}`);
    
    const response = await axios.get('https://api.themoviedb.org/3/trending/movie/week', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES',
        page: page
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data.results,
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

// Endpoint para próximos estrenos (upcoming) - USANDO DISCOVER CON FILTROS ESPECÍFICOS
app.get('/api/movies/upcoming', validateAppSignature, async (req, res) => {
  try {
    console.log('✅ Endpoint upcoming accedido');
    
    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }
    
    // Procesar parámetro page de la query string
    const page = parseInt(req.query.page) || 1;
    console.log(`📄 Procesando página: ${page}`);
    
    // Calcular fechas para filtros (igual que la web de TMDB)
    const today = new Date();
    const minDate = today.toISOString().split('T')[0]; // Fecha mínima: hoy
    const maxDate = new Date(today.getTime() + (120 * 24 * 60 * 60 * 1000)).toISOString().split('T')[0]; // Fecha máxima: +4 meses (120 días)
    
    console.log(`📅 Filtros de fecha: ${minDate} a ${maxDate}`);
    
    // Usar endpoint /discover/movie con filtros específicos para próximos estrenos
    // Replica exactamente los parámetros de la web de TMDB
    const response = await axios.get('https://api.themoviedb.org/3/discover/movie', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES',
        page: page,
        'with_release_type': '2|3', // Theatrical Limited | Theatrical
        'release_date.gte': minDate, // Fecha mínima: hoy
        'release_date.lte': maxDate, // Fecha máxima: +4 meses (120 días)
        'sort_by': 'popularity.desc' // Ordenar por popularidad
      },
      timeout: 10000
    });

    console.log(`🎬 Películas encontradas: ${response.data.results.length}`);

    res.json({
      success: true,
      data: response.data.results, // Usar resultados directos de TMDB
      timestamp: new Date().toISOString(),
      filters_applied: {
        language: 'es-ES',
        release_types: '2|3 (Theatrical Limited | Theatrical)',
        date_range: `${minDate} a ${maxDate} (+4 meses)`,
        sort_by: 'popularity.desc',
        note: 'Replica parámetros de la web de TMDB'
      }
    });

  } catch (error) {
    console.error('Error en upcoming:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'UPCOMING_ERROR'
    });
  }
});

// ===== RUTAS CON PARÁMETROS DESPUÉS =====

// Endpoint para detalles de película
app.get('/api/movies/:id', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido' 
      });
    }

    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES'
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en detalles de película:', error.message);
    res.status(500).json({ 
      error: 'Error interno del servidor',
      code: 'MOVIE_DETAILS_ERROR'
    });
  }
});

// Endpoint mejorado para proveedores de streaming (TMDB)
app.get('/api/movies/:id/providers', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    const { region = 'ES' } = req.query; // Permitir región personalizable

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido' 
      });
    }

    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎬 Buscando proveedores para película ${id} en región ${region}`);

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/watch/providers`, {
      params: {
        api_key: process.env.TMDB_API_KEY
      },
      timeout: 10000
    });

    console.log(`📺 Respuesta completa de TMDB:`, JSON.stringify(response.data, null, 2));

    // Procesar los resultados
    const results = response.data.results || {};
    console.log(`🌍 Regiones disponibles:`, Object.keys(results));
    
    // Intentar con diferentes códigos de región para España
    const regionCodes = [region, 'ES', 'Spain'];
    let regionData = null;
    let usedRegion = null;

    for (const code of regionCodes) {
      if (results[code]) {
        regionData = results[code];
        usedRegion = code;
        console.log(`✅ Encontrados datos para región: ${code}`);
        break;
      }
    }

    if (!regionData) {
      console.log(`❌ No se encontraron proveedores para ninguna región española`);
      return res.json({
        success: true,
        data: {
          results: {},
          providers: [],
          message: 'No hay proveedores disponibles para esta región',
          availableRegions: Object.keys(results)
        },
        timestamp: new Date().toISOString()
      });
    }

    // Extraer todos los tipos de proveedores
    const providers = [];
    const providerTypes = ['flatrate', 'rent', 'buy'];

    for (const type of providerTypes) {
      if (regionData[type]) {
        for (const provider of regionData[type]) {
          providers.push({
            name: provider.provider_name,
            logo: `https://image.tmdb.org/t/p/original${provider.logo_path}`,
            type: type, // flatrate = streaming, rent = alquiler, buy = compra
            providerId: provider.provider_id,
            displayPriority: provider.display_priority || 999
          });
        }
      }
    }

    // Ordenar por prioridad de display
    providers.sort((a, b) => a.displayPriority - b.displayPriority);

    console.log(`📺 Proveedores encontrados (${providers.length}):`, providers.map(p => `${p.name} (${p.type})`));

    res.json({
      success: true,
      data: {
        results: response.data.results,
        providers: providers,
        region: usedRegion,
        availableRegions: Object.keys(results)
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error en proveedores:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status
    });
    
    res.status(500).json({ 
      error: 'Error interno del servidor',
      code: 'PROVIDERS_ERROR',
      details: error.message
    });
  }
});

// Endpoint para obtener el reparto de una película
app.get('/api/movies/:id/cast', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;

    if (!id || isNaN(id)) {
      return res.status(400).json({ 
        error: 'ID de película inválido' 
      });
    }

    // Validar API key de TMDB
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get(`https://api.themoviedb.org/3/movie/${id}/credits`, {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES'
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en cast:', error.message);
    res.status(500).json({ 
      error: 'Error interno del servidor',
      code: 'CAST_ERROR'
    });
  }
});

// Nuevo endpoint para obtener regiones disponibles
app.get('/api/watch-providers/regions', validateAppSignature, async (req, res) => {
  try {
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    const response = await axios.get('https://api.themoviedb.org/3/watch/providers/regions', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: 'es-ES'
      },
      timeout: 10000
    });

    res.json({
      success: true,
      data: response.data.results,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error obteniendo regiones:', error.message);
    res.status(500).json({ 
      error: 'Error interno del servidor',
      code: 'REGIONS_ERROR'
    });
  }
});

// Endpoint para búsqueda de películas
app.post('/api/movies/search', validateAppSignature, async (req, res) => {
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

    console.log(`🔍 Buscando: "${query}" (página ${page})`);

    const response = await axios.get('https://api.themoviedb.org/3/search/movie', {
      params: {
        api_key: process.env.TMDB_API_KEY,
        language: language,
        query: query,
        page: page,
        include_adult: false
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
    console.error('Error en búsqueda:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'SEARCH_ERROR'
    });
  }
});

// Endpoint para película aleatoria
app.post('/api/movies/random', validateAppSignature, async (req, res) => {
  try {
    const { 
      genres, 
      language = 'es-ES', 
      yearStart, 
      yearEnd, 
      minVotes = 50, 
      minRating, 
      maxRating, 
      excludeAdult = true 
    } = req.body;

    if (!genres || !Array.isArray(genres) || genres.length === 0) {
      return res.status(400).json({
        error: 'Géneros requeridos',
        code: 'MISSING_GENRES'
      });
    }

    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada',
        code: 'TMDB_API_KEY_MISSING'
      });
    }

    console.log(`🎲 Película aleatoria para géneros: ${genres.join(',')}`);

    // Construir parámetros de búsqueda
    const params = {
      api_key: process.env.TMDB_API_KEY,
      language: language,
      with_genres: genres.join(','),
      sort_by: 'popularity.desc',
      'vote_count.gte': minVotes,
      include_adult: excludeAdult ? 'false' : 'true'
    };

    // Filtros de fecha
    if (yearStart && yearStart > 1900) {
      params['primary_release_date.gte'] = `${yearStart}-01-01`;
    }
    
    const currentYear = new Date().getFullYear();
    const safeYearEnd = (yearEnd && yearEnd <= currentYear) ? yearEnd : currentYear;
    params['primary_release_date.lte'] = `${safeYearEnd}-12-31`;

    // Filtros de puntuación
    if (minRating !== undefined) {
      params['vote_average.gte'] = minRating;
    }
    if (maxRating !== undefined) {
      params['vote_average.lte'] = maxRating;
    }

    // Obtener página aleatoria (máximo 20 páginas)
    const randomPage = Math.floor(Math.random() * 20) + 1;
    params.page = randomPage;

    const response = await axios.get('https://api.themoviedb.org/3/discover/movie', {
      params: params,
      timeout: 10000
    });

    const results = response.data.results || [];
    
    if (results.length === 0) {
      return res.json({
        success: true,
        data: null,
        message: 'No se encontraron películas con los criterios especificados',
        timestamp: new Date().toISOString()
      });
    }

    // Seleccionar película aleatoria de los resultados
    const randomMovie = results[Math.floor(Math.random() * results.length)];

    res.json({
      success: true,
      data: randomMovie,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error en película aleatoria:', error.message);
    res.status(500).json({
      error: 'Error interno del servidor',
      code: 'RANDOM_MOVIE_ERROR'
    });
  }
});

// Endpoint para recomendaciones de IA - CORREGIDO
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
    console.log(`📝 Preferencias: ${userPreferences}`);
    console.log(`📊 Películas calificadas: ${ratedMovies.length}`);
    console.log(`📺 Películas vistas: ${watchedMovies.length}`);

    // Construir prompt mejorado para Groq
    let systemPrompt = 'Eres un experto en recomendaciones de películas. Debes responder SOLO con una lista de títulos de películas separados por comas, sin numeración, sin explicaciones, sin texto adicional.';
    let userPrompt = '';
    
    if (type === 'preferences' && userPreferences) {
      userPrompt = `Basándote en estas preferencias: "${userPreferences}", recomienda exactamente 5 películas. Responde SOLO con los títulos separados por comas.`;
    } else if (type === 'ratings' && ratedMovies.length > 0) {
      const movieTitles = ratedMovies
        .map(m => `"${m.title || m.name}"`)
        .slice(0, 10) // Limitar a 10 películas para no exceder el límite de tokens
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

    console.log(`🎯 Prompt enviado a Groq: ${userPrompt}`);

    // Llamar a Groq API con parámetros correctos
    const groqResponse = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.3-70b-versatile', // Modelo actualizado y recomendado
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
        max_completion_tokens: 300, // Parámetro correcto (antes max_tokens)
        top_p: 1,
        stream: false
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000 // Aumentado a 30 segundos
      }
    );

    console.log(`✅ Respuesta de Groq recibida`);

    // Verificar que la respuesta de Groq sea válida
    if (!groqResponse.data || !groqResponse.data.choices || !groqResponse.data.choices[0]) {
      console.error('❌ Respuesta inválida de Groq:', groqResponse.data);
      throw new Error('Respuesta inválida de Groq API');
    }

    const content = groqResponse.data.choices[0].message.content.trim();
    console.log(`📝 Contenido recibido de Groq: "${content}"`);

    // Procesar las recomendaciones
    const recommendations = content
      .split(',')
      .map(title => title.trim())
      .filter(title => title.length > 0)
      .slice(0, 5); // Asegurar máximo 5 recomendaciones

    console.log(`🎬 Recomendaciones procesadas (${recommendations.length}):`, recommendations);

    // Verificar que tengamos recomendaciones
    if (recommendations.length === 0) {
      console.error('❌ No se generaron recomendaciones');
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
    console.error('❌ Error en recomendaciones:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status
    });
    
    // Proporcionar más detalles del error
    const errorDetails = error.response?.data?.error || error.message;
    
    res.status(500).json({
      error: 'Error al generar recomendaciones',
      code: 'RECOMMENDATIONS_ERROR',
      details: errorDetails
    });
  }
});

// OPCIONAL: Endpoint de prueba para verificar que Groq funciona
app.get('/api/test/groq', validateAppSignature, async (req, res) => {
  try {
    if (!process.env.GROQ_API_KEY) {
      return res.status(500).json({
        error: 'API key de Groq no configurada',
        code: 'GROQ_API_KEY_MISSING'
      });
    }

    console.log('🧪 Probando conexión con Groq...');

    const testResponse = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'system',
            content: 'Eres un asistente útil.'
          },
          {
            role: 'user',
            content: 'Di "Groq funciona correctamente" en una sola línea.'
          }
        ],
        temperature: 0.5,
        max_completion_tokens: 50,
        stream: false
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      }
    );

    res.json({
      success: true,
      message: 'Groq API funcionando correctamente',
      response: testResponse.data.choices[0].message.content,
      model: testResponse.data.model,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error en prueba de Groq:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status
    });

    res.status(500).json({
      success: false,
      error: 'Error al conectar con Groq',
      details: error.response?.data || error.message,
      timestamp: new Date().toISOString()
    });
  }
});
