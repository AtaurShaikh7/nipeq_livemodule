using Oracle.ManagedDataAccess.Client;
using System;
using System.Data;

namespace Services
{
    public class OracleService
    {
        private readonly string _connectionString;

        public OracleService(string connectionString)
        {
            _connectionString = connectionString;
        }

        public OracleConnection GetOpenConnection()
        {
            var conn = new OracleConnection(_connectionString);
            conn.Open();
            return conn;
        }

        public DateTime? GetEffDate(Logger logger, QueryProvider queryProvider)
        {
            try
            {
                using var conn = GetOpenConnection();
                string sql = queryProvider["GetEffDate"];
                using var cmd = new OracleCommand(sql, conn);

                cmd.Parameters.Add(new OracleParameter("dload", OracleDbType.Int32) { Value = 0 });
                cmd.Parameters.Add(new OracleParameter("bday", OracleDbType.Int32) { Value = 1 });

                var result = cmd.ExecuteScalar();
                if (result != null && result != DBNull.Value)
                {
                    if (result is DateTime dt)
                        return dt;
                }
                return null;
            }
            catch (Exception ex)
            {
                logger.LogError("Error retrieving effdate from business_calendar.", ex);
                return null;
            }
        }
    }
}