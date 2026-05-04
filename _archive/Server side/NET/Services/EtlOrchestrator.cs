using System;
using System.Data;
using Oracle.ManagedDataAccess.Client;
using System.Collections.Generic;

namespace Services
{
    public class EtlOrchestrator
    {
        private readonly Logger _logger;
        private readonly OracleService _oracleService;
        private readonly QueryProvider _queries;

        public EtlOrchestrator(Logger logger, OracleService oracleService, QueryProvider queries)
        {
            _logger = logger;
            _oracleService = oracleService;
            _queries = queries;
        }

        public bool Run()
        {
            _logger.LogInfo("ETL Orchestration started.");
            DateTime? effDate = null;

            // 1. Fetch effdate
            try
            {
                effDate = _oracleService.GetEffDate(_logger, _queries);
                if (!effDate.HasValue)
                {
                    _logger.LogError("Effdate could not be retrieved; ETL exiting.");
                    return false;
                }
                _logger.LogInfo($"Fetched effdate: {effDate.Value:yyyy-MM-dd}");
            }
            catch (Exception ex)
            {
                _logger.LogError("Failed to fetch effdate", ex);
                return false;
            }

            using var conn = _oracleService.GetOpenConnection();

            // 2. Update daily_process_stats using :effdate parameter
            if (!Step_UpdateDailyProcessStats(conn, effDate.Value))
                return false;

            // 3. Execute and validate each ETL step (using procs & queries from queries.txt)
            if (!Step_GenericProcAndValidation(conn, effDate.Value, "SP_TRANSF_CREATE_MODELS_D", "SP_TRANSF_CREATE_MODELS_D_Validation", new Dictionary<string, object> { ["RUNDATE"] = effDate.Value }))
                return false;

            if (!Step_GenericProcAndValidation(conn, effDate.Value, "SP_TRANSF_CREATE_MODELS", "SP_TRANSF_CREATE_MODELS_Validation"))
                return false;

            if (!Step_GenericProcAndValidation(conn, effDate.Value, "SP_TRANSF_CORPACTIONS", "SP_TRANSF_CORPACTIONS_Validation"))
                return false;

            if (!Step_GenericProcAndValidation(conn, effDate.Value, "SP_TRANSF_CORPACTIONSEXC", "SP_TRANSF_CORPACTIONSEXC_Validation"))
                return false;

            if (!Step_GenericProcAndValidation(conn, effDate.Value, "SP_LDG_CORPACTEXC_XLS", "SP_LDG_CORPACTEXC_XLS_Validation"))
                return false;

            // 4. Execute SP_TRANSFORM_MAIN and validate process status
            if (!Step_TransformMainAndStatus(conn, effDate.Value))
                return false;

            // 5. Execute SP_VALAT_MAIN
            if (!Step_ValatMain(conn, effDate.Value))
                return false;

            // 6. Final update to daily_process_stats (set status to COMPLETE).
            if (!Step_FinalizeProcessStats(conn, effDate.Value))
                return false;

            _logger.LogInfo("ETL Orchestration completed successfully.");
            return true;
        }

        private bool Step_UpdateDailyProcessStats(OracleConnection conn, DateTime effDate)
        {
            try
            {
                string sql = _queries["UpdateDailyProcessStats"];
                using var cmd = new OracleCommand(sql, conn);
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;
                int affected = cmd.ExecuteNonQuery();
                _logger.LogInfo("Updated daily_process_stats", new { affected, effdate = effDate });
                if (affected == 0)
                {
                    _logger.LogError("No rows updated in daily_process_stats for given effdate. ETL exiting.");
                    return false;
                }
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError("Failed to update daily_process_stats.", ex);
                return false;
            }
        }

        private bool Step_GenericProcAndValidation(
            OracleConnection conn, DateTime effDate,
            string procName, string validationQueryName,
            Dictionary<string, object>? procParams = null)
        {
            // Execute stored procedure from queries.txt
            try
            {
                string procText = _queries[procName];
                using var cmd = new OracleCommand(procText, conn)
                {
                    CommandType = CommandType.StoredProcedure
                };
                if (procParams != null)
                {
                    foreach (var kvp in procParams)
                    {
                        cmd.Parameters.Add(kvp.Key, OracleDbType.Date).Value = kvp.Value;
                    }
                }
                cmd.ExecuteNonQuery();
                _logger.LogInfo($"Executed stored procedure: {procName}", new { effdate = effDate });
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failure executing procedure: {procName}", ex);
                return false;
            }

            // Validation query from queries.txt
            try
            {
                string validationText = _queries[validationQueryName];
                using var cmd = new OracleCommand(validationText, conn);
                if (validationText.Contains(":effdate"))
                    cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;

                object result = cmd.ExecuteScalar();
                int count = Convert.ToInt32(result);
                _logger.LogInfo($"Validation after {procName}: {validationQueryName} = {count}");
                if (count < 0)
                {
                    _logger.LogError($"Validation failed after {procName} (unexpected negative count). ETL exiting.");
                    return false;
                }
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Validation error after executing {procName}", ex);
                return false;
            }
        }

        private bool Step_TransformMainAndStatus(OracleConnection conn, DateTime effDate)
        {
            // Execute SP_TRANSFORM_MAIN
            try
            {
                string procText = _queries["SP_TRANSFORM_MAIN"];
                using var cmd = new OracleCommand(procText, conn)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;
                cmd.ExecuteNonQuery();
                _logger.LogInfo("Executed stored procedure: SP_TRANSFORM_MAIN", new { effdate = effDate });
            }
            catch (Exception ex)
            {
                _logger.LogError("Failure executing SP_TRANSFORM_MAIN", ex);
                return false;
            }

            // Status validation: SELECT status query from queries.txt
            try
            {
                string validationText = _queries["SP_TRANSFORM_MAIN_Validation"];
                using var cmd = new OracleCommand(validationText, conn);
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;
                using var rdr = cmd.ExecuteReader();
                if (!rdr.Read())
                {
                    _logger.LogError("Status validation failed: no record for effdate.");
                    return false;
                }
                string? stat = rdr["status"]?.ToString();
                _logger.LogInfo("Status validation after SP_TRANSFORM_MAIN", new { effdate = effDate, status = stat });
                if (!string.Equals(stat, "SUCCESS", StringComparison.InvariantCultureIgnoreCase))
                {
                    _logger.LogError("Status after SP_TRANSFORM_MAIN not successful", new { status = stat });
                    return false;
                }
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError("Status validation failure after SP_TRANSFORM_MAIN", ex);
                return false;
            }
        }

        private bool Step_ValatMain(OracleConnection conn, DateTime effDate)
        {
            // Execute SP_VALAT_MAIN
            try
            {
                string procText = _queries["SP_VALAT_MAIN"];
                using var cmd = new OracleCommand(procText, conn)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;
                cmd.ExecuteNonQuery();
                _logger.LogInfo("Executed stored procedure: SP_VALAT_MAIN", new { effdate = effDate });
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError("Failure executing SP_VALAT_MAIN", ex);
                return false;
            }
        }

        private bool Step_FinalizeProcessStats(OracleConnection conn, DateTime effDate)
        {
            // Final: Mark daily_process_stats as COMPLETE
            try
            {
                string sql = _queries["FinalizeProcessStats"];
                using var cmd = new OracleCommand(sql, conn);
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate;
                int affected = cmd.ExecuteNonQuery();
                _logger.LogInfo("Final updates complete", new { affected, effdate = effDate });
                if (affected == 0)
                {
                    _logger.LogError("Final update affected no rows. ETL exiting.");
                    return false;
                }
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError("Failure during final updates.", ex);
                return false;
            }
        }
    }
}