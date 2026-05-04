import { Router, Request, Response } from 'express';
import { execSP } from '../services/sp-executor';
import { verifyPassword, signToken } from '../services/auth';
import { sql } from '../datasources/mssql';

const router = Router();

/**
 * POST /auth/login
 * Body: { loginId: string, password: string }
 */
router.post('/login', async (req: Request, res: Response): Promise<void> => {
  const { loginId, password } = req.body;

  if (!loginId || !password) {
    res.status(400).json({ error: 'loginId and password are required' });
    return;
  }

  try {
    const rows = await execSP('SP_API_LOGIN', [
      { name: 'login_id', type: sql.VarChar(100), value: loginId },
    ]);

    if (!rows || rows.length === 0) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const user = rows[0];
    const isValid = await verifyPassword(password, user.password);

    if (!isValid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const token = signToken({
      userId: user.user_id,
      loginId: user.login_id,
      roleId: user.role_id,
      clientId: user.client_id,
    });

    res.json({
      token,
      user: {
        userId: user.user_id,
        loginId: user.login_id,
        firstName: user.first_name,
        lastName: user.last_name,
        roleId: user.role_id,
        clientId: user.client_id,
      },
    });
  } catch (err: any) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
