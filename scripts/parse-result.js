/**
 * parse-result.js
 * Converts Oracle SQL*Plus fixed-width spool output (result.json) into
 * a proper JSON array of PortfolioRow objects for the NipEQ frontend.
 *
 * Strategy:
 *  - SECTOR, SECURITY_NAME, INDEXFLAG use fixed-width (text columns, no overflow)
 *  - Numeric columns can overflow their width in SQL*Plus → use whitespace tokenization
 *  - For security rows: use ISIN code (INE.../CASH/CBLO) as anchor to split tokens
 *  - Sector header rows are detected by SECURITY_NAME === SECTOR
 *
 * Run:  node scripts/parse-result.js
 * Output: frontend/src/assets/portfolio-data.json
 */

const fs   = require('fs');
const path = require('path');

const INPUT  = path.join(__dirname, '../frontend/src/assets/result.json');
const OUTPUT = path.join(__dirname, '../frontend/src/assets/portfolio-data.json');

// ── Helpers ──────────────────────────────────────────────────────────────────
function fld(line, start, len) {
  return (line.substring(start, start + len) || '').trim();
}
function n(v)  { if (v === '' || v == null) return null; const f = parseFloat(v); return isNaN(f) ? null : f; }
function pct(v){ const x = n(v); return x === null ? null : parseFloat((x * 100).toFixed(4)); }
function size(bucket) {
  if (!bucket) return null;
  const b = bucket.toUpperCase();
  if (b.includes('LARGE')) return 'LC';
  if (b.includes('MID'))   return 'MC';
  if (b.includes('SMALL')) return 'SC';
  return null;
}

// Parse the tail section (everything after ISIN value in a security row).
// Tokens (split by whitespace):
//   0: BOOK_VALUE, 1: BONUS_SPLIT, 2: PAYOUT
//   then: SUBSECTOR words..., RNK1, NO_SUBSEC, MCAP_BUCKET words..., AVG_VOL, AVGADVT, RATING
// We parse from the end to handle variable-length text fields.
function parseTail(tailStr) {
  const t = tailStr.trim().split(/\s+/).filter(Boolean);
  if (!t.length) return {};

  const result = {};
  let end = t.length - 1;

  // RATING (last token)
  result.rating  = t[end--] || null;
  // AVGADVT
  result.avgAdvt = n(t[end--]);
  // AVG_VOL
  result.avgVol  = n(t[end--]);

  // MCAP_BUCKET: "LARGE CAP" / "MID CAP" / "SMALL CAP" = 2 words; "NA" / "Sector" = 1 word
  if (t[end] === 'CAP') {
    end--; // skip "CAP"
    const prefix = t[end--]; // "LARGE" / "MID" / "SMALL"
    result.mcapBucket = prefix ? prefix + ' CAP' : 'NA';
  } else {
    result.mcapBucket = t[end--];
  }

  // NO_SUBSEC and RNK1
  result.noSubsec = n(t[end--]);
  result.rnk1     = n(t[end--]);

  // PAYOUT, BONUS_SPLIT, BOOK_VALUE (from the start of tail)
  result.bookValue  = n(t[0]);
  result.bonusSplit = n(t[1]);
  result.payout     = n(t[2]);

  // SUBSECTOR = tokens between index 3 and end (inclusive), joined
  const subTokens = t.slice(3, end + 1);
  result.subSector = subTokens.length ? subTokens.join(' ') : null;

  return result;
}

// ── Parse ────────────────────────────────────────────────────────────────────
const raw   = fs.readFileSync(INPUT, 'utf8');
const lines = raw.split('\n');

const rows = [];

for (const rawLine of lines) {
  const line = rawLine.replace(/\r$/, ''); // strip CR

  if (!line.trim()) continue;
  if (line.startsWith('PL/SQL'))           continue;
  if (line.trimStart().startsWith('SECT')) continue; // header
  if (line.trimStart().startsWith('----')) continue; // separator
  if (line.length < 51)                    continue;

  const sector   = fld(line, 0,   50);
  const secName  = fld(line, 51,  50);
  const indexFlg = fld(line, 102, 128);

  if (!sector || !secName) continue;

  // Sector headers: SECURITY_NAME === SECTOR *and* INDEXFLAG is blank.
  // The CASH security has SECURITY_NAME="CASH"=SECTOR but INDEXFLAG="No" → security row.
  const isSector = (sector === secName) && !indexFlg;

  // Everything after INDEXFLAG (pos 231 onwards)
  const restRaw = line.substring(231);

  // ── Sector header row ────────────────────────────────────────────────────
  if (isSector) {
    // Sector rows: FUND, RET_1D..RET_YTD (7), FUND_MTM, FUND_MTM_CHG, FUND_WTS, INDEX_WTS, ...
    // No FUNDQTY, CMP, or ISIN
    const t = restRaw.trim().split(/\s+/).filter(Boolean);
    // t[0] = "FUND" or blank
    // t[1..7] = 7 returns (already in %)
    // t[8] = FUND_MTM, t[9] = FUND_MTM_CHG, t[10] = FUND_WTS (%), t[11] = INDEX_WTS (decimal)
    let i = 0;
    const fund = (t[i] === 'FUND') ? 'FUND' : null;
    if (t[i] === 'FUND' || t[i] === 'No') i++;

    rows.push({
      sector:          sector,
      sub_sector:      null,
      instrument_type: null,
      security_name:   secName,
      isin_code:       '',
      index_flag:      null,
      fund_flag:       fund,
      fund_qty:        null,
      cmp:             null,
      ret_1d:          n(t[i++]),
      ret_5d:          n(t[i++]),
      ret_1m:          n(t[i++]),
      ret_3m:          n(t[i++]),
      ret_6m:          n(t[i++]),
      ret_1y:          n(t[i++]),
      ret_ytd:         n(t[i++]),
      fund_mtm:        n(t[i++]),
      fund_mtm_chg:    n(t[i++]),
      fund_wts:        pct(t[i++]),  // sector row: fund_wts in decimal ratio here
      index_wts:       null,
      fund_aum:        null,
      mcap:            null,
      close_price:     null,
      size:            null,
      avg_vol:         null,
      rating:          null,
      is_sector_row:   1,
    });
    continue;
  }

  // ── Security row ─────────────────────────────────────────────────────────
  // Find ISIN anchor: standard ISINs start with INE (12 chars), or are CASH/CBLO
  const isinMatch = restRaw.match(/\b(INE[A-Z0-9]{9}|CASH|CBLO)\b/);

  let isin      = '';
  let beforeTokens = [];
  let tail      = '';

  if (isinMatch) {
    isin = isinMatch[1];
    const isinPos = isinMatch.index;
    // Tokens before ISIN
    beforeTokens = restRaw.substring(0, isinPos).trim().split(/\s+/).filter(Boolean);
    // Everything after the matched ISIN (skip any trailing spaces in the 40-char padded field)
    const afterIsinStart = isinPos + isinMatch[0].length;
    // ISIN field is 40 chars wide; skip remaining padding
    const fieldEnd = isinPos + 40;
    tail = restRaw.substring(Math.max(afterIsinStart, fieldEnd));
  } else {
    // No ISIN found — parse what we can
    beforeTokens = restRaw.trim().split(/\s+/).filter(Boolean);
  }

  // Map beforeTokens:
  // [0] = FUND ("FUND" / "No")
  // If FUND: [1]=FUNDQTY, [2]=CMP, [3-9]=returns, [10]=FUND_MTM, [11]=FUND_MTM_CHG, [12]=FUND_WTS, [13]=INDEX_WTS, [14]=FUND_AUM, [15]=MCAP, [16]=RNK
  // If No:   [1]=CMP, [2-8]=returns, [9]=INDEX_WTS, [10]=FUND_AUM, [11]=MCAP, [12]=RNK
  let bi = 0;
  const fundStr = beforeTokens[bi++] || '';
  const isFund  = fundStr === 'FUND';

  let fundQty, cmp, ret1d, ret5d, ret1m, ret3m, ret6m, ret1y, retYtd;
  let fundMtm, fundMtmChg, fundWts, indexWts, fundAum, mcap;

  if (isFund) {
    fundQty    = n(beforeTokens[bi++]);
    cmp        = n(beforeTokens[bi++]);
    ret1d      = pct(beforeTokens[bi++]);
    ret5d      = pct(beforeTokens[bi++]);
    ret1m      = pct(beforeTokens[bi++]);
    ret3m      = pct(beforeTokens[bi++]);
    ret6m      = pct(beforeTokens[bi++]);
    ret1y      = pct(beforeTokens[bi++]);
    retYtd     = pct(beforeTokens[bi++]);
    fundMtm    = n(beforeTokens[bi++]);
    fundMtmChg = n(beforeTokens[bi++]);
    fundWts    = pct(beforeTokens[bi++]);
    // INDEX_WTS field is empty for fund-only securities.
    // Empty field collapses in tokenisation → next token is FUND_AUM (52329).
    // Detect: a valid INDEX_WTS ratio is always < 1.0; FUND_AUM is ~52329.
    const peekIndexWts = n(beforeTokens[bi]);
    if (peekIndexWts !== null && peekIndexWts > 1.0) {
      // Field was absent — fund-only security
      indexWts = null;
    } else {
      indexWts = pct(beforeTokens[bi++]);
    }
    fundAum    = n(beforeTokens[bi++]);
    mcap       = n(beforeTokens[bi++]);
    // RNK = beforeTokens[bi] (ignored)
  } else {
    // "No" fund — FUNDQTY, FUND_MTM, FUND_MTM_CHG, FUND_WTS are absent
    fundQty    = null;
    cmp        = n(beforeTokens[bi++]);
    ret1d      = pct(beforeTokens[bi++]);
    ret5d      = pct(beforeTokens[bi++]);
    ret1m      = pct(beforeTokens[bi++]);
    ret3m      = pct(beforeTokens[bi++]);
    ret6m      = pct(beforeTokens[bi++]);
    ret1y      = pct(beforeTokens[bi++]);
    retYtd     = pct(beforeTokens[bi++]);
    fundMtm    = null;
    fundMtmChg = null;
    fundWts    = null;
    indexWts   = pct(beforeTokens[bi++]);
    fundAum    = n(beforeTokens[bi++]);
    mcap       = n(beforeTokens[bi++]);
    // RNK = beforeTokens[bi] (ignored)
  }

  const tailParsed = isinMatch ? parseTail(tail) : {};

  rows.push({
    sector:          sector,
    sub_sector:      tailParsed.subSector  || null,
    instrument_type: null,
    security_name:   secName,
    isin_code:       isin,
    index_flag:      (indexFlg && indexFlg !== 'No') ? indexFlg : null,
    fund_flag:       isFund ? 'FUND' : null,
    fund_qty:        fundQty,
    cmp:             cmp,
    ret_1d:          ret1d,
    ret_5d:          ret5d,
    ret_1m:          ret1m,
    ret_3m:          ret3m,
    ret_6m:          ret6m,
    ret_1y:          ret1y,
    ret_ytd:         retYtd,
    fund_mtm:        fundMtm,
    fund_mtm_chg:    fundMtmChg,
    fund_wts:        fundWts,
    index_wts:       indexWts,
    fund_aum:        fundAum,
    mcap:            mcap,
    close_price:     cmp,
    size:            size(tailParsed.mcapBucket || ''),
    avg_vol:         tailParsed.avgVol  || null,
    rating:          tailParsed.rating  || null,
    is_sector_row:   0,
  });
}

// ── Write output ──────────────────────────────────────────────────────────────
fs.writeFileSync(OUTPUT, JSON.stringify(rows, null, 2), 'utf8');

const secCount    = rows.filter(r => r.is_sector_row === 0).length;
const sectorCount = rows.filter(r => r.is_sector_row === 1).length;
console.log(`✅ Done — ${rows.length} total rows (${sectorCount} sector headers + ${secCount} securities)`);

// Quick sanity check
const sample = rows.filter(r => r.is_sector_row === 0 && r.isin_code === 'INE885A01032')[0];
if (sample) {
  console.log('\nSample: Amara Raja Batteries');
  console.log('  fund_wts :', sample.fund_wts, '  (expect ≈ 0.2269)');
  console.log('  index_wts:', sample.index_wts,'  (expect ≈ 0.1257)');
  console.log('  ret_1d   :', sample.ret_1d,   '  (expect ≈ 0.757)');
  console.log('  ret_6m   :', sample.ret_6m,   '  (expect ≈ -18.92)');
  console.log('  cmp      :', sample.cmp,      '  (expect 778.55)');
  console.log('  sub_sector:', sample.sub_sector);
  console.log('  size     :', sample.size,     '  (expect SC)');
  console.log('  rating   :', sample.rating);
}
console.log(`\n   Output: ${OUTPUT}`);
