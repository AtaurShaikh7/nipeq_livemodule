import { getPool, sql } from '../datasources/mssql';

export interface SpParam {
  name: string;
  type: sql.ISqlTypeFactoryWithNoParams | sql.ISqlTypeFactoryWithLength | sql.ISqlTypeFactoryWithPrecisionScale | any;
  value: any;
}

/**
 * Execute a stored procedure and return all rows from the first result set.
 */
export async function execSP(spName: string, params: SpParam[] = []): Promise<any[]> {
  const pool = await getPool();
  const request = pool.request();

  for (const p of params) {
    request.input(p.name, p.type, p.value);
  }

  const result = await request.execute(spName);
  return result.recordset || [];
}

/**
 * Execute a stored procedure and return all result sets.
 */
export async function execSPMulti(spName: string, params: SpParam[] = []): Promise<any[][]> {
  const pool = await getPool();
  const request = pool.request();

  for (const p of params) {
    request.input(p.name, p.type, p.value);
  }

  const result = await request.execute(spName);
  return (result.recordsets as any[][]) || [];
}
