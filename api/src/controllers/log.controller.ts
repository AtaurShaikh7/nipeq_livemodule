import { Router, Request, Response } from 'express';
import { execSP } from '../services/sp-executor';
import { jwtMiddleware } from '../middleware/jwt.middleware';
import { sql } from '../datasources/mssql';

const router = Router();
router.use(jwtMiddleware);

/**
 * POST /activity-log
 * Body: { pageId, fundId, fromDate?, toDate? }
 */
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const userId = (req as any).user.userId;
  const { pageId, fundId, fromDate, toDate } = req.body;

  try {
    await execSP('SP_API_LOG_ACTIVITY', [
      { name: 'user_id',   type: sql.Int,     value: userId },
      { name: 'page_id',   type: sql.Int,     value: pageId || 19 },
      { name: 'fund_id',   type: sql.Int,     value: fundId || null },
      { name: 'from_date', type: sql.Date,    value: fromDate || null },
      { name: 'to_date',   type: sql.Date,    value: toDate || null },
    ]);
    res.json({ success: true });
  } catch (err: any) {
    console.error('Activity log error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
