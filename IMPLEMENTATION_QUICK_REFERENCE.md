# Fixed Asset Module - Implementation Quick Reference Guide

**Purpose:** One-page lookup for developers during implementation  
**Target Audience:** PowerBuilder developers, DBAs, QA team

---

## QUICK LINKS

**Analysis Documents:**
- `todolist_penyusutan_aktiva.md` - Full reverse engineering (13 parts, ~1000 lines)
- `FA_TECHNICAL_SPECIFICATION.md` - Technical design (6 sections, with code)
- `REVERSE_ENGINEERING_SUMMARY.md` - Executive summary & timeline

---

## TABLE STRUCTURE AT A GLANCE

### NEW TABLES TO CREATE

```sql
fa_asset              - Asset master (what assets exist)
fa_depreciation       - Monthly calculations (how much depreciation per month)
fa_disposal           - Disposal records (when assets are sold/retired)
fa_depreciation_audit - Audit trail (who changed what when)
```

### KEY RELATIONSHIPS

```
fa_asset ──┬──→ gl_acc (asset account)
           ├──→ gl_acc (accumulated account)
           ├──→ gl_acc (expense account)
           ├──→ gl_depart (cost center)
           └──→ gl_project (project)

fa_depreciation → fa_asset (which asset)
fa_depreciation → gl_journal (GL entry created)

fa_disposal → fa_asset (which asset disposed)
fa_disposal → gl_journal (gain/loss entry)
```

### USE EXISTING TABLES

```
gl_journal      ← INSERT depreciation journal entries here
gl_acc          ← Link GL accounts here
gl_setup        ← Current period from here
gl_depart       ← Optional: cost center allocation
gl_project      ← Optional: project allocation
```

---

## WINDOW/FORM CHECKLIST

### Windows to Build

- [ ] **w_fa_master.srw** - Asset CRUD operations
  - Retrieve: All assets (filtered by site/category)
  - Create: New asset entry
  - Edit: Modify asset details
  - Delete: Soft delete (set status='D')

- [ ] **w_fa_depreciation.srw** - Monthly depreciation
  - Period selector (YYYY-MM)
  - Calculate button → calls f_fa_calculate_depreciation()
  - Preview grid (dw_depr_calc)
  - Post button → calls f_fa_post_depreciation()
  - Journal preview (dw_depr_preview)

- [ ] **w_fa_disposal.srw** - Asset disposal/sale
  - Asset lookup
  - Disposal date entry
  - Sale price entry
  - Auto-calculate gain/loss
  - Post to GL button

---

## DATAWINDOW CHECKLIST

### Datawindows to Create

| DW Name | Base Table | Purpose | Update? |
|---------|-----------|---------|---------|
| dw_fa_list | fa_asset | List grid | No |
| dw_fa_detail | fa_asset | Entry form | Yes |
| dw_depr_calc | fa_depreciation | Calculation preview | No |
| dw_depr_preview | gl_journal | Journal preview | No |
| dw_depr_post | gl_journal3 | Journal INSERT | Yes |
| dw_disposal | fa_disposal | Disposal entry | Yes |

---

## FUNCTION CHECKLIST

### Critical Functions (Must Implement)

- [ ] **f_fa_calculate_depreciation(as_period_date, as_site_id)**
  - Loop through fa_asset (where status='A' and acq_date <= period)
  - For each asset: monthly_depr = cost / useful_life_month
  - INSERT into fa_depreciation table
  - COMMIT and return record count

- [ ] **f_fa_generate_journal(as_period_date, as_site_id)**
  - Generate voucher: {SITE} + YYMMDD + 'DEPR' + sequence
  - Header entry (urut=1): Summarize total depreciation
  - Detail entries (urut=2+): One per asset category
  - Debit: Depreciation Expense account
  - Credit: Accumulated Depreciation account
  - COMMIT and return voucher number

- [ ] **f_fa_post_depreciation(as_voucher)**
  - UPDATE gl_journal SET posting='Y' WHERE voucher=:as_voucher
  - UPDATE fa_depreciation SET posting_status='D' (mark as posted)
  - UPDATE fa_depreciation SET gl_voucher=:as_voucher (link to journal)
  - COMMIT and return 1 (success) or 0 (failure)

- [ ] **f_fa_validate_accounts(as_asset_acc, as_accum_acc, as_exp_acc)**
  - Check: Accounts exist in gl_acc
  - Check: DetailYN = '1' (allows detail posting)
  - Return: 1 (valid) or 0 (invalid)

- [ ] **f_fa_get_book_value(as_asset_id)**
  - book_value = cost - accumulated_depreciation
  - Return decimal value

---

## JOURNAL ENTRY PATTERN

### Depreciation Journal Structure

**Header (urut=1):**
```
voucher:        '101202606DEPR0001'
urut:           1
account_id:     '412-066'         (or category-specific: 412-066-001, etc.)
debet:          [SUM of all depreciation]
kredit:         [Same as debet]
ket:            'Penyusutan Aktiva Tetap'
modul_id:       'FA'
posting:        'N'               (will be 'Y' after posting)
```

**Detail Lines (urut=2+):**
```
For each asset:
  Line A (urut=2):
    account_id:   gl_account_expense     (e.g., '412-066-001')
    debet:        monthly_depreciation   (e.g., 100,000)
    kredit:       0
    ket:          'Depr: [Asset Name]'

  Line B (urut=3):
    account_id:   gl_account_accum       (e.g., '158-001')
    debet:        0
    kredit:       monthly_depreciation   (100,000)
    ket:          'Accum: [Asset Name]'
```

**Balance Check:**
```
SUM(debet)  = SUM(all Line A debets) + SUM(Header debet)
SUM(kredit) = SUM(all Line B credits) + SUM(Header kredit)

Must satisfy: SUM(debet) = SUM(kredit)
```

---

## GL ACCOUNT SETUP

### Required GL Accounts

**Template - Fill in with actual codes from your chart of accounts:**

```
Asset Accounts:
  [ ] ___-___ = Building
  [ ] ___-___ = Vehicle
  [ ] ___-___ = Equipment
  [ ] ___-___ = Land (non-depreciable)

Accumulated Depreciation Accounts:
  [ ] ___-___ = Accumulated: Building
  [ ] ___-___ = Accumulated: Vehicle
  [ ] ___-___ = Accumulated: Equipment

Depreciation Expense Accounts:
  [ ] ___-___ = Depreciation Expense (consolidated)
  [ ] ___-___ = Depreciation: Building (if split)
  [ ] ___-___ = Depreciation: Vehicle (if split)
  [ ] ___-___ = Depreciation: Equipment (if split)

Disposal Accounts:
  [ ] ___-___ = Gain on Asset Sale (Other Income)
  [ ] ___-___ = Loss on Asset Disposal (Other Expense)
```

### Add Accounts to gl_acc Table

```sql
INSERT INTO gl_acc (accountcode, accountdes, detailyn, fincatcode, ...)
VALUES ('101-001', 'Bangunan', '1', 'ASSET', ...)

All new accounts must have:
  - accountcode: Unique
  - accountdes: Clear description
  - detailyn: '1' (allows detail posting)
  - fincatcode: Asset/Liability/Income/Expense
```

---

## INTEGRATION WITH CLOSING

### Modify w_closing_journal.srw

**Location:** After existing closing logic (after RL/summary entries), before validation

**Add These Lines:**

```powerbuilder
// ===== DEPRECIATION PROCESSING =====
// Calculate depreciation for month
ll_calc_count = f_fa_calculate_depreciation(idt_tgl, gs_site)

IF ll_calc_count > 0 THEN
    // Generate depreciation journal
    ls_depr_voucher = f_fa_generate_journal(idt_tgl, gs_site)
    
    IF NOT ISNULL(ls_depr_voucher) THEN
        // Post depreciation
        ll_result = f_fa_post_depreciation(ls_depr_voucher)
        
        IF ll_result <> 1 THEN
            MESSAGEBOX('Error', 'Depreciation posting failed')
            ROLLBACK
            RETURN
        END IF
        
        f_log("6200", "FA", "CLOSING_DEPR", "Posted: " + ls_depr_voucher)
    ELSE
        MESSAGEBOX('Error', 'Failed to generate depreciation journal')
        ROLLBACK
        RETURN
    END IF
END IF
// ===== END DEPRECIATION =====
```

---

## TESTING CHECKLIST

### Unit Tests

- [ ] f_fa_calculate_depreciation()
  - Test: Straight-line depreciation (100k asset, 10 years = 10k/month)
  - Test: Asset acquired mid-period
  - Test: Asset with salvage value
  - Test: Non-depreciable asset (land)

- [ ] f_fa_generate_journal()
  - Test: Voucher number generation
  - Test: Debit-credit balance in generated entries
  - Test: Correct number of detail lines

- [ ] f_fa_post_depreciation()
  - Test: gl_journal.posting field updates to 'Y'
  - Test: fa_depreciation.posting_status updates to 'D'
  - Test: GL voucher reference populated

- [ ] f_fa_validate_accounts()
  - Test: Valid accounts return 1
  - Test: Non-existent account returns 0
  - Test: Account without DetailYN='1' returns 0

### Integration Tests

- [ ] Asset Creation
  - Create asset with GL accounts
  - Verify accounts exist in gl_acc
  - Verify book value calculated correctly

- [ ] Depreciation Calculation
  - Create test asset (100,000 IDR, 10 year useful life)
  - Call f_fa_calculate_depreciation()
  - Verify fa_depreciation table has entry with monthly_depr = 10,000

- [ ] Journal Generation
  - Generate depreciation journal
  - Verify gl_journal entries created
  - Verify debit = credit
  - Verify modul_id = 'FA'

- [ ] Posting to GL
  - Post depreciation journal
  - Verify posting='Y' in gl_journal
  - Verify GL balances updated

- [ ] Month-End Closing
  - Run month-end closing process (w_closing_journal)
  - Verify depreciation processing completed
  - Verify GL balances reflect depreciation

### Reconciliation Tests

- [ ] GL Account Reconciliation
  - Asset account balance = SUM(acquisition_cost) from fa_asset
  - Accumulated account balance = SUM(accumulated_depr) from fa_depreciation
  - Expense account balance = SUM(monthly_depr) from fa_depreciation

- [ ] Excel Reconciliation
  - Calculate depreciation manually from Excel
  - Compare with FA module results (should match ±0.01)

---

## DEPLOYMENT CHECKLIST

### Pre-Deployment (DEV/TEST)

- [ ] All tables created and indexed
- [ ] All GL accounts added
- [ ] All PowerBuilder objects compiled
- [ ] All reports tested
- [ ] Unit tests passed
- [ ] Integration tests passed
- [ ] UAT completed

### Deployment Day

- [ ] Database backup
- [ ] Deploy SQL schema changes
- [ ] Deploy PowerBuilder PBL
- [ ] Run data validation queries
- [ ] Verify GL account setup
- [ ] Test user login & permissions
- [ ] Run sample depreciation
- [ ] Verify GL posting
- [ ] Document any issues

### Post-Deployment (UAT)

- [ ] User training completed
- [ ] Month-end closing test run
- [ ] GL reconciliation verification
- [ ] Backup procedures verified
- [ ] Support plan established

---

## TROUBLESHOOTING QUICK GUIDE

### Problem: Depreciation Not Calculating

**Causes:**
1. No assets with status='A'
2. Asset acquisition_date is in the future
3. fa_asset table not populated

**Fix:**
```sql
SELECT COUNT(*) FROM fa_asset WHERE status='A' AND acquisition_date <= GETDATE()
```

### Problem: Journal Entry Unbalanced

**Causes:**
1. Missing detail line
2. Wrong debit/credit amounts
3. Rounding errors

**Check:**
```sql
SELECT voucher, SUM(debet) AS debet_total, SUM(kredit) AS kredit_total
FROM gl_journal
WHERE voucher = 'XXXX'
GROUP BY voucher
```

### Problem: GL Accounts Not Found

**Causes:**
1. Account doesn't exist in gl_acc
2. Account is not available for detail posting (DetailYN='0')

**Fix:**
```sql
SELECT * FROM gl_acc WHERE accountcode = 'XXX-XXX'
-- Verify DetailYN = '1'
```

### Problem: Posting Failed

**Causes:**
1. Permission denied (user doesn't have FA_DEPR_POST permission)
2. Period is locked
3. GL transaction lock

**Check:**
```sql
SELECT * FROM gl_setup WHERE site_id = 'XX'
-- Verify periode is not locked
```

---

## PERFORMANCE CONSIDERATIONS

### Indexes Needed

```sql
CREATE INDEX idx_fa_asset_site_status ON fa_asset(site_id, status)
CREATE INDEX idx_fa_depr_period ON fa_depreciation(fa_asset_id, period_date)
CREATE INDEX idx_gl_journal_voucher_urut ON gl_journal(voucher, urut)
```

### Query Optimization

**Avoid:**
- SELECT * (use specific columns)
- Repeated lookups in loops (cache lookups)
- DISTINCT without necessity

**Use:**
- Indexed columns in WHERE clauses
- BULK INSERT for multiple rows
- Parameterized queries

---

## CODE STYLE GUIDELINES

### Naming Conventions (Match Existing Code)

**Variables:**
- `ls_` prefix for STRING
- `ll_` prefix for LONG
- `ld_` prefix for DECIMAL
- `ldt_` prefix for DATETIME
- `lb_` prefix for BOOLEAN

**Functions:**
- `f_` prefix for functions
- Verb-object naming: `f_fa_calculate_depreciation()`
- Lowercase with underscores

**Datawindows:**
- `d_` prefix for internal/hidden datawindows
- `dw_` prefix for window controls
- Descriptive names: `d_depreciation_detail`

---

## WHAT NOT TO DO

❌ **DO NOT:**
- Create separate journal table for FA
- Bypass debit-credit validation
- Hardcode GL account codes
- Ignore decimal rounding
- Forget to COMMIT transactions
- Leave orphaned depreciation records
- Mix manual and automatic entries

✅ **DO:**
- Use gl_journal for all entries
- Enforce debit-credit validation
- Use GL account lookups
- Use DECIMAL(18,2) for amounts
- Always COMMIT or ROLLBACK
- Link fa_depreciation to gl_journal
- Keep manual/auto entries separate via modul_id

---

## REFERENCE DOCUMENTATION

**Key Files to Study:**

```
w_gl_journal.srw       ← Journal posting pattern (learn from this)
w_closing_journal.srw  ← Closing integration (insert code here)
w_refresh_journal.srw  ← Batch processing pattern (optional reference)
dw_journal3.srd        ← Comprehensive journal DW (reference pattern)
gl_journal table       ← Core table schema (must use this)
```

**Key Functions to Reference:**

```
f_eom()                ← End of month calculation
f_bom()                ← Beginning of month calculation
f_lock_trx()           ← Transaction locking (use in closing)
f_log()                ← Audit logging (use for all changes)
```

---

## HANDOFF CHECKLIST

**From Analysis Team to Development Team:**

- [x] ✅ Reverse engineering complete
- [x] ✅ Architecture documented
- [x] ✅ Database schema provided
- [x] ✅ Function signatures defined
- [x] ✅ Integration points identified
- [x] ✅ Closing process integration planned
- [ ] ⏳ User to clarify Excel depreciation rules
- [ ] ⏳ User to confirm GL account structure
- [ ] ⏳ User approval to proceed with implementation

---

**Last Updated:** 2026-06-15  
**Status:** Ready for Development
