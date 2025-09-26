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

// Endpoint para próximos estrenos (upcoming) - RUTA ESPECÍFICA
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
    
    const response = await axios.get('https://api.themoviedb.org/3/movie/upcoming', {
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

// Endpoint de prueba para un ID de película específico
app.get('/api/debug/providers/:id', validateAppSignature, async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!process.env.TMDB_API_KEY) {
      return res.status(500).json({
        error: 'API key de TMDB no configurada'
      });
    }

    // Probar con una película popular para debug
    const testResponse = await axios.get(`https://api.themoviedb.org/3/movie/${id}/watch/providers`, {
      params: {
        api_key: process.env.TMDB_API_KEY
      }
    });

    res.json({
      movieId: id,
      rawResponse: testResponse.data,
      hasResults: !!testResponse.data.results,
      regionCount: Object.keys(testResponse.data.results || {}).length,
      availableRegions: Object.keys(testResponse.data.results || {}),
      esData: testResponse.data.results?.ES || null,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    res.status(500).json({ 
      error: error.message,
      details: error.response?.data 
    });
  }
});

// Middleware de manejo de errores
app.use((err, req, res, next) => {
  console.error('Error no manejado:', err);
  res.status(500).json({
    error: 'Error interno del servidor',
    code: 'INTERNAL_ERROR'
  });
});

// Middleware para rutas no encontradas
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint no encontrado',
    code: 'NOT_FOUND'
  });
});

// Iniciar servidor
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor Randomovie ejecutándose en puerto ${PORT}`);
  console.log(`📊 Entorno: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔒 Rate limit: ${process.env.RATE_LIMIT_MAX_REQUESTS || 100} requests por ${Math.ceil((parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000) / 60000)} minutos`);
  console.log(`🌐 Servidor escuchando en: http://0.0.0.0:${PORT}`);
});

// Manejo de errores del servidor
server.on('error', (error) => {
  console.error('❌ Error del servidor:', error);
  process.exit(1);
});

// Manejo de cierre graceful
process.on('SIGTERM', () => {
  console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
  server.close(() => {
    console.log('✅ Servidor cerrado correctamente');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
  server.close(() => {
    console.log('✅ Servidor cerrado correctamente');
    process.exit(0);
  });
});

