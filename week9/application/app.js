const http = require('http');
const client = require('prom-client');

const port = process.env.PORT || 3000;

// Prometheus: recollir mètriques per defecte de Node.js (heap, CPU, lag del event loop, etc.)
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Comptador personalitzat: total de peticions HTTP per mètode, codi d'estat i ruta
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests received',
  labelNames: ['method', 'status_code', 'path'],
  registers: [register],
});

// Histograma personalitzat: durada de les peticions en segons
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2],
  registers: [register],
});

const server = http.createServer(async (req, res) => {
  // Servir mètriques Prometheus — scraping per Prometheus cada 15s
  if (req.url === '/metrics') {
    res.setHeader('Content-Type', register.contentType);
    res.end(await register.metrics());
    return;
  }

  const endTimer = httpRequestDuration.startTimer({ method: req.method, path: req.url });

  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');

  if (req.url === '/health') {
    res.end(JSON.stringify({ status: 'healthy', service: 'backend' }));
  } else {
    res.end(JSON.stringify({
      message: 'Hello from the GreenDevCorp Node.js Backend Container!',
      timestamp: new Date().toISOString(),
    }));
  }

  httpRequestsTotal.inc({ method: req.method, status_code: res.statusCode, path: req.url });
  endTimer();
});

server.listen(port, () => {
  console.log(`Backend server running at port ${port}`);
});
