import { Router, Request, Response } from 'express';
import { execSP } from '../services/sp-executor';
import { jwtMiddleware } from '../middleware/jwt.middleware';
import { sql } from '../datasources/mssql';

const router = Router();
router.use(jwtMiddleware);

/**
 * GET /funds
 * Returns funds accessible by the authenticated user.
 */
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const userId = (req as any).user.userId;
  try {
    const rows = await execSP('SP_API_FUNDLIST', [
      { name: 'user_id', type: sql.Int, value: userId },
    ]);
    res.json(rows);
  } catch (err: any) {
    console.error('Fund list error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /funds/indices
 * Returns all active indices.
 * NOTE: must be declared before /:id/params to avoid param match.
 */
router.get('/indices', async (_req: Request, res: Response): Promise<void> => {
  try {
    const rows = await execSP('SP_API_INDEXLIST');
    res.json(rows);
  } catch (err: any) {
    console.error('Index list error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /funds/:id/params
 * Returns max effective date and default index for a fund.
 */
router.get('/:id/params', async (req: Request, res: Response): Promise<void> => {
  const fundId = parseInt(req.params.id);
  if (isNaN(fundId)) {
    res.status(400).json({ error: 'Invalid fund id' });
    return;
  }
  try {
    const rows = await execSP('SP_API_FUND_PARAMS', [
      { name: 'fund_id', type: sql.Int, value: fundId },
    ]);
    res.json(rows[0] || null);
  } catch (err: any) {
    console.error('Fund params error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
