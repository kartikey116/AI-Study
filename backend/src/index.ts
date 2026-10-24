import 'dotenv/config'; // must stay first: later imports read process.env at load time
import { app } from './app';
import { assertJwtSecrets } from './utils/jwt.util';

assertJwtSecrets();

const port = Number(process.env.PORT) || 3000;

// Start Server
app.listen(port, '0.0.0.0', () => {
  console.log(`[server]: Server is running at http://0.0.0.0:${port}`);
});
