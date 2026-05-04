"""
oracle_steps.py — Executes oracle_steps.json against an open Oracle connection.

Each step:
  - Has a ProcedureBlock (raw SQL or PL/SQL BEGIN...END block)
  - Has Validations (NonZeroCount or MustBeNull)
  - Has Enabled flag (skip if false)

Returns (True, exit_code=0) on full success, (False, exit_code) on first failure.
"""

import json
from datetime import date, datetime
from pathlib import Path
from time import perf_counter

import oracledb
from logger import Logger


def run_oracle_steps(
    conn: oracledb.Connection,
    steps_file: Path,
    effdate: date,
    log: Logger,
) -> tuple[bool, int]:
    """
    Loads and executes all steps from oracle_steps.json.
    Returns (success: bool, exit_code: int).
    """
    # Load steps file
    if not steps_file.exists():
        log.error(f"Oracle steps file not found: {steps_file}")
        return False, 25

    try:
        with open(steps_file, "r", encoding="utf-8") as f:
            steps_doc = json.load(f)
    except json.JSONDecodeError as e:
        log.error(f"Failed to parse oracle_steps.json: {e}")
        return False, 26
    except Exception as e:
        log.error(f"Failed to read oracle_steps.json: {e}")
        return False, 26

    steps = steps_doc.get("Steps", [])
    if not steps:
        log.error("oracle_steps.json has no steps defined.")
        return False, 27

    total_start = perf_counter()

    for step in steps:
        name = step.get("Name", "(unnamed)")
        enabled = step.get("Enabled", True)
        proc_block = step.get("ProcedureBlock") or ""
        validations = step.get("Validations") or []

        log.separator(f"STEP: {name}")

        if not enabled:
            log.info("  SKIPPED (Enabled: false)")
            continue

        # Execute procedure / SQL block
        if proc_block.strip():
            log.info(f"  Executing: {proc_block.strip()[:120]}")
            step_start = perf_counter()
            try:
                cur = conn.cursor()
                cur.execute(proc_block)
                rows_affected = cur.rowcount  # -1 for PL/SQL blocks, >= 0 for DML
                cur.close()
                elapsed = perf_counter() - step_start
                if rows_affected >= 0:
                    log.info(f"  Done. Rows affected: {rows_affected}  [{elapsed:.1f}s]")
                else:
                    log.info(f"  Done. [{elapsed:.1f}s]")
                # Commit after each step so parallel DML objects can be read in validations
                conn.commit()
                log.info("  Committed.")
            except oracledb.Error as e:
                log.error(f"  Oracle error in step '{name}': {e}")
                return False, 20
            except Exception as e:
                log.error(f"  Unexpected error in step '{name}': {e}")
                return False, 21
        else:
            log.info("  No procedure for this step (validation-only).")

        # Run validations
        if not validations:
            log.info("  No validations configured.")
            continue

        for v in validations:
            v_name = v.get("Name", "(unnamed validation)")
            v_sql = (v.get("Sql") or "").strip()
            v_type = (v.get("Type") or "").strip()

            log.info(f"  Validation: {v_name}")

            if not v_sql:
                log.info("    SKIP: validation SQL is empty.")
                continue

            try:
                cur = conn.cursor()
                # Bind :effdate if referenced
                if ":effdate" in v_sql.lower():
                    cur.execute(v_sql, effdate=effdate)
                else:
                    cur.execute(v_sql)
                row = cur.fetchone()
                cur.close()
                scalar = row[0] if row else None
            except oracledb.Error as e:
                log.error(f"    Oracle error in validation '{v_name}': {e}")
                return False, 20
            except Exception as e:
                log.error(f"    Unexpected error in validation '{v_name}': {e}")
                return False, 21

            if v_type.lower() == "nonzerocount":
                count = 0 if scalar is None else int(scalar)
                log.info(f"    COUNT(*) = {count}")
                if count <= 0:
                    log.error(f"    FAILED: count is 0 (expected > 0). ETL stopping.")
                    return False, 23
                log.info("    PASSED.")

            elif v_type.lower() == "mustbenull":
                is_null = (scalar is None)
                log.info(f"    Result: {'NULL' if is_null else scalar}")
                if not is_null:
                    log.error(f"    FAILED: expected NULL but got '{scalar}'. ETL stopping.")
                    return False, 24
                log.info("    PASSED.")

            else:
                log.info(f"    Result: {scalar}  (type '{v_type}' — no pass/fail rule applied)")

    total_elapsed = perf_counter() - total_start
    log.separator()
    log.info(f"All Oracle steps completed. Total elapsed: {total_elapsed:.1f}s")
    return True, 0
