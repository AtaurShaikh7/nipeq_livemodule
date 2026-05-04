import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { execSP } from './services/sp-executor';
import { jwtMiddleware } from './middleware/jwt.middleware';

import authRouter      from './controllers/auth.controller';
import fundRouter      from './controllers/fund.controller';
import portfolioRouter from './controllers/portfolio.controller';
import layoutRouter    from './controllers/layout.controller';
import logRouter       from './controllers/log.controller';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/auth',         authRouter);
app.use('/funds',        fundRouter);
app.use('/portfolio',    portfolioRouter);
app.use('/layouts',      layoutRouter);
app.use('/activity-log', logRouter);

// GET /indices — standalone route (same as /funds/indices but at top level)
app.get('/indices', jwtMiddleware, async (_req, res): Promise<void> => {
  try {
    const rows = await execSP('SP_API_INDEXLIST');
    res.json(rows);
  } catch (err: any) {
    console.error('Index list error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check
app.get('/health', (_req, res) => res.json({ status: 'ok', timestamp: new Date() }));

app.listen(PORT, () => {
  console.log(`\nNipEQ API running on http://localhost:${PORT}`);
  console.log(`  POST   /auth/login`);
  console.log(`  GET    /funds`);
  console.log(`  GET    /funds/:id/params`);
  console.log(`  GET    /indices`);
  console.log(`  GET    /portfolio?fundId=&indexId=&runDate=`);
  console.log(`  GET    /portfolio/return?fundId=&indexId=&effDate=`);
  console.log(`  GET    /portfolio/live-prices?fundId=&indexId=&runDate=`);
  console.log(`  GET    /layouts?widgetId=`);
  console.log(`  POST   /layouts`);
  console.log(`  PUT    /layouts/:id`);
  console.log(`  POST   /activity-log\n`);
});

export default app;
