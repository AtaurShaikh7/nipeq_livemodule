import { Router, Request, Response } from 'express';
import { execSP } from '../services/sp-executor';
import { jwtMiddleware } from '../middleware/jwt.middleware';
import { sql } from '../datasources/mssql';

const router = Router();
router.use(jwtMiddleware);

/**
 * GET /layouts?widgetId=
 * Returns saved layouts for the authenticated user.
 */
router.get('/', async (req: Request, res: Response): Promise<void> => {
  const userId   = (req as any).user.userId;
  const widgetId = parseInt(req.query.widgetId as string) || 19;
  try {
    const rows = await execSP('SP_API_LAYOUTS', [
      { name: 'user_id',   type: sql.Int, value: userId },
      { name: 'widget_id', type: sql.Int, value: widgetId },
    ]);
    res.json(rows);
  } catch (err: any) {
    console.error('Get layouts error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /layouts
 * Body: { widgetId, layoutName, layoutString, layoutState, isDefault }
 */
router.post('/', async (req: Request, res: Response): Promise<void> => {
  const userId = (req as any).user.userId;
  const { widgetId = 19, layoutName, layoutString, layoutState, isDefault = 0 } = req.body;

  if (!layoutName) {
    res.status(400).json({ error: 'layoutName is required' });
    return;
  }

  try {
    const rows = await execSP('SP_API_SAVE_LAYOUT', [
      { name: 'user_id',       type: sql.Int,          value: userId },
      { name: 'widget_id',     type: sql.Int,          value: widgetId },
      { name: 'layout_name',   type: sql.VarChar(200), value: layoutName },
      { name: 'layout_string', type: sql.NVarChar(sql.MAX), value: layoutString || '' },
      { name: 'layout_state',  type: sql.NVarChar(sql.MAX), value: layoutState || '' },
      { name: 'is_default',    type: sql.Bit,          value: isDefault ? 1 : 0 },
    ]);
    res.status(201).json(rows[0] || { success: true });
  } catch (err: any) {
    console.error('Save layout error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * PUT /layouts/:id
 * Body: { layoutString, layoutState, isDefault }
 */
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  const layoutId = parseInt(req.params.id);
  const { layoutString, layoutState, isDefault = 0 } = req.body;

  if (isNaN(layoutId)) {
    res.status(400).json({ error: 'Invalid layout id' });
    return;
  }

  const userId = (req as any).user.userId;
  try {
    await execSP('SP_API_UPDATE_LAYOUT', [
      { name: 'layout_id',     type: sql.Int,               value: layoutId },
      { name: 'user_id',       type: sql.Int,               value: userId },
      { name: 'layout_string', type: sql.NVarChar(sql.MAX),  value: layoutString || null },
      { name: 'layout_state',  type: sql.NVarChar(sql.MAX),  value: layoutState || null },
      { name: 'is_default',    type: sql.Bit,               value: isDefault ? 1 : 0 },
    ]);
    res.json({ success: true });
  } catch (err: any) {
    console.error('Update layout error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
