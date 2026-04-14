const http = require('http');

const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  
  if (req.url === '/health') {
    res.end(JSON.stringify({ status: 'healthy', service: 'backend' }));
  } else {
    res.end(JSON.stringify({ 
        message: 'Hello from the GreenDevCorp Node.js Backend Container!',
        timestamp: new Date().toISOString()
    }));
  }
});

server.listen(port, () => {
  console.log(`Backend server running at port ${port}`);
});
