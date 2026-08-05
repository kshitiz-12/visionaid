const app = require('./src/app');
const { port } = require('./src/config/env');

app.listen(port, () => {
  console.log(`VisionAid++ backend running on port ${port}`);
});
