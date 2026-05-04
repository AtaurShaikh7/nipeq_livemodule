import { Router, Request, Response } from 'express';
import { execSP } from '../services/sp-executor';
import { jwtMiddleware } from '../middleware/jwt.middleware';
import { sql } from '../datasources/mssql';

const router = Router();
router.use(jwtMiddleware);

/**
 * GET /portfolio?fundId=&indexId=&runDate=
 * Returns full portfolio grid data (securities + sector summaries).
 */
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const userId = (req as any).user.userId;
  const fundId = parseInt(req.query.fundId as string);
  const indexId = parseInt(req.query.indexId as string) || -1;
  const runDate = req.query.runDate as string;

  if (isNaN(fundId) || !runDate) {
    res.status(400).json({ error: 'fundId and runDate are required' });
    return;
  }

  try {
    const rows = await execSP('SP_API_LIVE_PORTFOLIO', [
      { name: 'fund_id',   type: sql.Int,      value: fundId },
      { name: 'index_id',  type: sql.Int,      value: indexId },
      { name: 'run_date',  type: sql.Date,     value: runDate },
      { name: 'user_id',   type: sql.Int,      value: userId },
    ]);
    res.json(rows);
  } catch (err: any) {
    console.error('Portfolio error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /portfolio/return?fundId=&indexId=&effDate=
 * Returns 1D return for a fund and its benchmark index.
 */
router.get('/return', async (req: Request, res: Response): Promise<void> => {
  const fundId  = parseInt(req.query.fundId as string);
  const indexId = parseInt(req.query.indexId as string) || -1;
  const effDate = req.query.effDate as string;

  if (isNaN(fundId) || !effDate) {
    res.status(400).json({ error: 'fundId and effDate are required' });
    return;
  }

  try {
    const rows = await execSP('SP_API_FUND_IDX_RETURN', [
      { name: 'fund_id',  type: sql.Int,  value: fundId },
      { name: 'index_id', type: sql.Int,  value: indexId },
      { name: 'eff_date', type: sql.Date, value: effDate },
    ]);
    res.json(rows[0] || null);
  } catch (err: any) {
    console.error('Fund return error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /portfolio/live-prices?fundId=&indexId=&runDate=
 * Returns live DION prices for the fund's holdings.
 */
router.get('/live-prices', async (req: Request, res: Response): Promise<void> => {
  const fundId  = parseInt(req.query.fundId as string);
  const indexId = parseInt(req.query.indexId as string) || -1;
  const runDate = req.query.runDate as string;

  if (isNaN(fundId) || !runDate) {
    res.status(400).json({ error: 'fundId and runDate are required' });
    return;
  }

  try {
    const rows = await execSP('SP_API_LIVE_PRICES', [
      { name: 'fund_id',  type: sql.Int,  value: fundId },
      { name: 'index_id', type: sql.Int,  value: indexId },
      { name: 'run_date', type: sql.Date, value: runDate },
    ]);
    res.json(rows);
  } catch (err: any) {
    console.error('Live prices error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
