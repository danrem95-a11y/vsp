# Reverse Engineering: Penyusutan Aktiva Tetap (Fixed Asset Depreciation Module)

**Status:** Reverse Engineering Phase (NOT Implementation)  
**Date:** 2026-06-15  
**Objective:** Understand existing journal architecture and design Fixed Asset module following proven patterns

---

## PART 1: EXISTING JOURNAL ARCHITECTURE

### 1.1 Journal Table Structure

#### PRIMARY TABLES (Core Journal)

**gl_journal** (Main Journal Header + Detail Combined)
```
Key Fields:
  VOUCHER        CHAR(15) - Primary Key: SiteID + YYMM + Type + Sequence
  URUT           LONG     - Primary Key: Line number (1 = header, 2+ = detail)
  SITE_ID        CHAR(4)  - Primary Key: Branch/site identifier
  
Header Fields (urut=1):
  TGL            DATETIME - Transaction date
  VOUCHER_MANUAL CHAR(15) - User-assigned reference number
  MODUL_ID       CHAR(2)  - Module code (GJ=GL Journal, AP, AR, IV, etc.)
  CURR_ID        CHAR(5)  - Currency (IDR, USD, EUR)
  RATE_RP        DECIMAL  - Exchange rate to IDR (default 1 for IDR)
  KET            VARCHAR  - Description/memo
  POSTING        CHAR(1)  - Posting status (Y/N)

Detail Fields (urut=2+):
  ACCOUNT_ID     CHAR(15) - GL Account code
  DEBET          DECIMAL(18,2) - Debit amount in local currency
  KREDIT         DECIMAL(18,2) - Credit amount in local currency
  DEBET_KURS     DECIMAL(18,2) - Debit amount in exchange-rate adjusted currency
  KREDIT_KURS    DECIMAL(18,2) - Credit amount in exchange-rate adjusted currency
  
Optional Detail Fields (for advanced routing):
  DEPART_ID1     CHAR(15) - Primary cost center/department
  DEPART_ID2     CHAR(15) - Secondary cost center/department
  PROJECT_ID1    CHAR(15) - Primary project
  PROJECT_ID2    CHAR(15) - Secondary project
  CF_FLAG        CHAR(1)  - Cash flow transaction flag (Y/N)
  CC_FLAG        CHAR(1)  - Cost center allocation flag (Y/N)
```

#### SUPPORTING TABLES (Referenced)

**gl_acc** (Chart of Accounts)
```
ACCOUNTCODE    CHAR(15) - Primary Key
ACCOUNTDES     VARCHAR  - Account description
DETAILYN       CHAR(1)  - Allows detail posting (1=yes, 0=no)
FINCATCODE     VARCHAR  - Financial category code (type of account)
CURRENCYCODE   CHAR(5)  - Default currency
SHOW_HIDE      CHAR(1)  - Security flag (0=protected, 1=exposed)
CC_FLAG        CHAR(1)  - Cost center required flag
```

**gl_depart** (Department/Cost Center Master)
```
DEPART_ID      CHAR(15) - Primary Key
DEPART_DESC    VARCHAR  - Department description
```

**gl_project** (Project Master)
```
PROJECT_ID     CHAR(15) - Primary Key
PROJECT_DESC   VARCHAR  - Project description
```

**gl_saldo** (Balance/Balance Sheet Summary) - Refreshed during closing
```
(Built from gl_journal during closing process)
```

---

### 1.2 Voucher Numbering Pattern

**Format:** `{SITE_ID} + {YYMM} + {TYPE} + {SEQUENCE}`

**Examples:**
- `101-2601-MEMO-0001` = Site 101, Jan 2026, Manual Memo, Seq 0001
- `RL101202601` = Closing journal (RL=Retain Loss), Site 101, Jan 2026
- `PO262001P001` = AP Payment, Site 262, Jan 2026, Seq P001

**Generation Logic:**
1. Get current period from GL_SETUP table (periode field)
2. Query max(VOUCHER) where LEFT(VOUCHER, 11) = gs_site + YYMM + TYPE
3. Extract sequence number from position 12-15
4. Increment by 1 and pad with zeros
5. Concatenate parts to form new voucher number

**Key Points:**
- VOUCHER_MANUAL: User-assigned number (must be unique per site)
- VOUCHER: System-generated automatic number (preferred in posting)
- Both stored for audit trail and reference

---

### 1.3 Posting Mechanism

**Flow in w_gl_journal.srw (Event: ue_save)**

```
Step 1: VALIDATION
├─ Check: Debit Total = Credit Total (dw_13)
├─ Check: All detail lines have valid accounts
├─ Check: VOUCHER_MANUAL is unique for this month
└─ Check: No posting conflicts with locked periods

Step 2: VOUCHER NUMBER GENERATION (if new)
├─ IF ls_voucher = '' (new entry)
│  ├─ Query max(voucher) for period
│  ├─ Increment sequence
│  ├─ Store in is_voucher
│  └─ Log: "Add voucher no: " + voucher
└─ ELSE (edit existing)
   ├─ Delete existing gl_journal rows
   └─ Log: "Edit voucher no: " + voucher

Step 3: INSERT HEADER + DETAIL
├─ Set all detail rows:
│  ├─ tgl = transaction date
│  ├─ voucher = generated voucher number
│  ├─ voucher_manual = user reference
│  ├─ modul_id = 'GJ' (GL Journal module)
│  ├─ site_id = gs_site
│  └─ posting = 'N' (not posted yet)
├─ Insert into dw_update (gl_journal3 datawindow)
├─ dw_update.update() - SQL INSERT
└─ Commit transaction

Step 4: OPTIONAL: CASH FLOW ROUTING
├─ IF cf_flag = 'Y'
│  ├─ Identify cash flow accounts
│  ├─ Route to gl_cashflow table (if enabled)
│  └─ Record direction (IN if debit, OUT if credit)
└─ IF cc_flag = 'Y'
   ├─ Identify cost center accounts
   ├─ Route to gl_costcenter table (if enabled)
   └─ Record allocation percentages

Step 5: OPTIONAL: PRINT FORM
└─ IF user confirms print
   ├─ Retrieve dw_cetak (print datawindow)
   └─ Display for printing/preview

Step 6: REFRESH SCREEN
└─ Trigger ue_new event (clear and reset form)
```

**Key Validation Rules:**
1. **Debit-Credit Balance**: Round((Total Debit - Total Credit), 2) = 0
2. **Security**: Protected accounts (show_hide='0') cannot be mixed with exposed accounts
3. **Account Validity**: All account codes must exist in gl_acc with DetailYN='1'
4. **Manual Number Uniqueness**: 
   ```sql
   SELECT COUNT(*) INTO :ll_cek FROM gl_journal 
   WHERE urut=1 AND voucher_manual=:ls_voucher_manual AND site_id=:gs_site
   IF ll_cek >= 1 THEN ERROR "Voucher manual sudah ada"
   ```

---

### 1.4 Posting Status & Reversal

**Posting Field Values:**
- `'N'` = Not posted (editable, can be deleted)
- `'Y'` = Posted (locked, locked in GL balance)
- `'R'` = Reversed (original + reversal entry visible for audit)

**Reversal Process:**
- Not found in current code - uses new journal entries instead
- Recommended approach: Create offsetting journal entry

---

### 1.5 Debit-Credit Validation Implementation

**Location:** w_gl_journal.srw, ue_save event, lines 102-110

```powerbuilder
ld_debet   = idw13.object.ttl_debet[1]
ld_kredit  = idw13.object.ttl_kredit[1]
IF ISNULL(ld_debet) THEN ld_debet = 0
IF ISNULL(ld_kredit) THEN ld_kredit = 0
ld_saldo = ld_debet - ld_kredit
IF ROUND(ld_saldo, 2) <> 0 THEN
    MESSAGEBOX('Error', 'TOTAL debet dan Kredit tidak balance...!')
    RETURN
END IF
```

**Critical:** 
- Uses ROUND(..., 2) for decimal precision
- Validates BEFORE any SQL operations
- Prevents unbalanced entries at UI layer

---

## PART 2: EXISTING CLOSING PROCESS

### 2.1 Monthly Closing Flow

**Location:** w_closing_journal.srw

**Steps:**

```
Step 1: SETUP PERIOD
├─ SELECT periode, re_this_year, re_ikhtisar FROM gl_setup
├─ periode = First day of current month (from GL_SETUP)
└─ idate_tgl = DATETIME(DATE(periode))

Step 2: CREATE CLOSING JOURNAL HEADER
├─ Voucher format: 'RL' + gs_site + YYYYMM
├─ Example: RL101202601 (Closing, Site 101, Jan 2026)
├─ DELETE existing closing entries for this period
│  └─ DELETE FROM gl_journal WHERE voucher = :is_voucher
└─ COMMIT

Step 3: PARSE TRIAL BALANCE
├─ dw_2.retrieve(gs_site, ldt_tgl1, ldt_tgl2)
│  └─ Calls d_trial_balance datawindow
│  └─ Retrieves unposted transactions for month
└─ Validates no unposted entries exist

Step 4: BUILD CLOSING ENTRIES
├─ IF Retained Loss Account (re_rl1 or re_rl2) is configured
│  ├─ Calculate profit/loss from P&L accounts
│  ├─ Create offsetting entry to RL account
│  └─ Insert into gl_journal with posting='Y'
└─ IF Statement Accounts (re_ikhtisar) is configured
   ├─ Create summary account rollups
   └─ Insert as separate closing entry

Step 5: VALIDATE CLOSING
├─ dw_1.retrieve() - Calls d_closing_rl datawindow
├─ Check: SUM(debet) = SUM(kredit) for closing entry
├─ IF not balanced
│  ├─ CLOSE window (automatic abort)
│  └─ RETURN error message
└─ IF balanced, CONTINUE

Step 6: MARK PERIOD AS CLOSED
├─ UPDATE gl_setup SET periode_status = 'CLOSED'
└─ COMMIT
```

**Key Points:**
- **Automatic Journal Generation**: Closing entries are auto-created, not manually entered
- **RL Account (Retained Loss)**: Captures profit/loss carryforward
- **Summary Accounts**: Optional account consolidation
- **Posting Status**: Closing entries created with posting='Y' (already posted)

---

### 2.2 Datawindows Used in Closing

| Datawindow | Purpose | Key Logic |
|------------|---------|-----------|
| d_trial_balance | Retrieve unposted transactions | Validates month-end readiness |
| d_parse_journal | Parse detailed GL entries | Lists all journal entries for validation |
| d_closing_rl | Build/validate RL entries | Creates profit/loss closing entries |
| d_closing_summary | Optional summary rollups | Consolidates inter-company entries |

---

## PART 3: GL ACCOUNT STRUCTURE & ROUTING

### 3.1 Account Types & Routing Logic

**From w_gl_journal.srw (dw_2 buttonclicked event):**

**Cash Flow (CF) Routing:**
```
IF cf_flag = 'Y' THEN
  IF ld_debet > 0 THEN
    dw_cf.dataobject = 'd_cf_in_save'      // Cash inflow
  ELSE
    dw_cf.dataobject = 'd_cf_out_save'     // Cash outflow
  END IF
  dw_cf.retrieve()
  [populate gl_cashflow table with transaction details]
END IF
```

**Cost Center (CC) Routing:**
```
IF cc_flag = 'Y' THEN
  IF ld_debet > 0 THEN
    dw_cc.dataobject = 'd_cc_save1'        // Cost center allocation
  ELSE
    dw_cc.dataobject = 'd_cc_save2'        // Cost center allocation reverse
  END IF
  dw_cc.retrieve(gs_site)
  [populate gl_costcenter or sub-ledger with allocation]
END IF
```

**Account Characteristics (from gl_acc):**
- **show_hide = '0'**: Protected/controlled account (limited access)
- **show_hide = '1'**: Open account (general use)
- **cc_flag = 'Y'**: Requires cost center allocation
- **fincatcode**: Financial category (asset, liability, income, expense)
- **detailyn = '1'**: Allows detail posting (most accounts)

---

### 3.2 Multi-Currency Support

**Fields:**
- `curr_id`: Currency code (IDR, USD, EUR)
- `rate_rp`: Exchange rate to IDR

**Calculation:**
```
debet_kurs   = debet * rate_rp          // Debit in reference currency
kredit_kurs  = kredit * rate_rp         // Credit in reference currency
```

**Rules:**
1. All accounts can have multi-currency entries
2. Exchange rate automatically applied on posting
3. Debit/credit amounts stored in TWO forms:
   - Original currency: debet/kredit
   - Reference currency (IDR): debet_kurs/kredit_kurs

---

## PART 4: JOURNAL DATAWINDOW ARCHITECTURE

### 4.1 Datawindow Hierarchy

```
dw_journal_entry (SINGLE ROW HEADER FORM)
├─ Purpose: Initial entry form for voucher header
├─ Table: gl_journal (urut=1 only)
└─ Fields: voucher, tgl, voucher_manual, curr_id, rate_rp, ket, flag_oke

dw_journal_entry_detail (MULTIPLE ROWS)
├─ Purpose: Line-item detail entry form
├─ Table: gl_journal (urut=2+)
└─ Fields: account_id, ket, debet, kredit, debet_kurs, kredit_kurs

dw_journal1 (SINGLE JOURNAL DISPLAY)
├─ Purpose: Simple journal display (single voucher)
├─ Table: gl_journal
└─ Used in: Tab 1 of gl_journal window

dw_journal2 (EXTENDED JOURNAL WITH DIMENSIONS)
├─ Purpose: Journal with cost center & project allocation
├─ Tables: gl_journal + gl_depart (2x) + gl_project (2x)
├─ Joins: LEFT JOIN to depart_id1, depart_id2, project_id1, project_id2
└─ Used in: Tab 2 of gl_journal window (entry form)

dw_journal3 (COMPREHENSIVE JOURNAL WITH MULTI-CURRENCY)
├─ Purpose: Full journal with currency & FX details
├─ Tables: gl_journal + lookups
├─ Key Fields: curr_id, rate_rp, debet_kurs, kredit_kurs, cf_flag, cc_flag
└─ Used in: Detail entry (dw_3) in gl_journal window
```

### 4.2 Key Pattern: Single Table, Multiple Views

**IMPORTANT PATTERN:**
- All journal views access **same underlying table** (gl_journal)
- Differences are in **JOINs and computed columns**, not base data
- Updates/Inserts happen through **UPDATE datawindow** (not view DW)

**Update Datawindow Pattern:**
```
Type dw_update FROM w_tree`dw_update
  String dataobject = "dw_journal3"
End Type
```
- Base DW: dw_journal3 (comprehensive, read-only in display)
- Update DW: dw_update (insert/update only)
- Read DW: dw_journal1/2/3 (display with joins/lookups)

---

## PART 5: EXCEL DEPRECIATION ANALYSIS

### 5.1 File Location & Structure

**File:** `WP_Aset tetap_TAM 2026.xlsx`

**Current Status:** BINARY FILE - Cannot be directly analyzed in SQL/PowerBuilder context

**Extraction Needed:**
- [ ] Manually review Excel file for:
  - Asset categories used
  - Depreciation rate per category
  - Depreciation method (straight-line, accelerated, etc.)
  - Useful life in months/years
  - Salvage value treatment
  - Accumulated depreciation calculations
  - Period-end asset valuations

### 5.2 Assumed Depreciation Categories (To Be Verified)

From file name "Aset tetap" (Fixed Assets):

**Likely Categories:**
1. **Bangunan (Buildings)**
   - Typical rate: 4% p.a. (25-year life)
   - Account: 101-xxx (Asset) / 158-001 (Accumulation)

2. **Kendaraan (Vehicles)**
   - Typical rate: 10% p.a. (10-year life)
   - Account: 105-xxx (Asset) / 158-301 (Accumulation)

3. **Peralatan Kantor (Office Equipment)**
   - Typical rate: 10% p.a. (10-year life)
   - Account: 104-xxx (Asset) / 158-101 (Accumulation)

4. **Peralatan Bengkel (Workshop Equipment)**
   - Typical rate: 10% p.a. (10-year life)
   - Account: 106-xxx (Asset) / 158-201 (Accumulation)

5. **Tanah (Land)**
   - Typical rate: 0% (non-depreciable)
   - Account: 102-xxx (Asset) / No accumulation

**TO VERIFY:** Read Excel file and confirm actual rates, accounts, and calculations

---

## PART 6: EXISTING POSTING PATTERNS IN OTHER MODULES

### 6.1 AP (Accounts Payable) Module Pattern

**Voucher Format:** `{SITE} + {YYMM} + 'P' + {SEQ}` (e.g., 26011003P027)

**Journal Flow:**
1. PO Line Item → AP Header created → Tentative voucher
2. Receipt → Update PO, create voucher movement
3. Invoice Match → Confirm GL posting
4. Payment → Create payment voucher, debit payable, credit bank

**Key Pattern:**
- Multiple related entries per business transaction
- Header-detail structure preserved
- Debit/Credit always balanced before posting

---

### 6.2 AR (Accounts Receivable) Module Pattern

**Voucher Format:** `{SITE} + {YYMM} + 'AR' + {SEQ}`

**Journal Flow:**
1. SO → Invoice → Tentative AR voucher
2. Receipt/Payment → Deduct from AR
3. Adjustment → Manual adjustment journal entry

**Pattern Parallel:** 
- Same debit-credit validation
- Same voucher numbering
- Same posting status management

---

## PART 7: INVENTORY IMPACT ON GL

### 7.1 Inventory to GL Posting

**Flow:**
1. Inventory transaction recorded in sub-ledger (IV module)
2. **w_refresh_journal.srw** (Refresh Transaction) batch process:
   - Collects inventory movements from sub-ledgers
   - Creates summary GL journal entries
   - Posts to GL with debit-credit balancing
3. Monthly closing:
   - Updates inventory valuation accounts
   - Reconciles physical vs. accounting records

**Key Pattern for Fixed Assets:**
- Can follow similar "batch refresh" pattern
- Monthly depreciation calculation
- Automatic GL posting (not manual entry)

---

## PART 8: PROPOSED FIXED ASSET MODULE ARCHITECTURE

### 8.1 Design Principles

**✅ MUST FOLLOW EXISTING PATTERNS:**
1. Voucher numbering: {SITE} + {YYMM} + {TYPE} + {SEQ}
2. Debit-credit validation: SUM(DEBET) = SUM(KREDIT)
3. Posting mechanism: Same as GL journal (dw_update pattern)
4. Closing process: Auto-generate depreciation entries
5. Table structure: Header + Detail in single table (or separate detail table)

**❌ MUST NOT CREATE:**
- New journal engine
- New posting mechanism
- New voucher numbering system
- New closing procedure
- New chart of accounts structure

**✅ USE EXISTING:**
- gl_journal table (or add FA-specific detail table with fk to gl_journal)
- gl_acc accounts (add depreciation-related accounts)
- Posting validation rules (apply debit-credit validation)
- Closing process (integrate depreciation entry generation)

---

### 8.2 Proposed Table Structure

**NEW TABLE: fa_asset (Fixed Asset Master)**

```sql
fa_asset_id       CHAR(20)    PRIMARY KEY
site_id           CHAR(4)     FOREIGN KEY -> gl_setup.site_id
asset_category    CHAR(15)    (Building, Vehicle, Equipment, Land, etc.)
asset_description VARCHAR(100)
acquisition_date  DATETIME    Asset purchase date
acquisition_cost  DECIMAL(18,2) Original cost (IDR)
salvage_value     DECIMAL(18,2) Residual value after useful life
useful_life_month LONG        Depreciation period in months
depreciation_rate DECIMAL(5,2) Annual rate % (20%, 10%, etc.)
depreciation_method CHAR(1)   (S=Straight-line, D=Declining, A=Accelerated)
gl_account_asset  CHAR(15)    FOREIGN KEY -> gl_acc.accountcode (Asset account)
gl_account_accum  CHAR(15)    FOREIGN KEY -> gl_acc.accountcode (Accumulated depreciation)
gl_account_exp    CHAR(15)    FOREIGN KEY -> gl_acc.accountcode (Depreciation expense)
status            CHAR(1)     (A=Active, D=Disposed, I=Inactive)
created_date      DATETIME
created_by        CHAR(20)
updated_date      DATETIME
updated_by        CHAR(20)
```

**NEW TABLE: fa_depreciation (Monthly Depreciation Calculated)**

```sql
fa_depr_id        CHAR(20)    PRIMARY KEY
fa_asset_id       CHAR(20)    FOREIGN KEY
period_date       DATETIME    Month-end date (last day of month)
monthly_depr      DECIMAL(18,2) Monthly depreciation amount
accumulated_depr  DECIMAL(18,2) Cumulative depreciation to date
book_value        DECIMAL(18,2) Asset cost - accumulated depreciation
gl_voucher        CHAR(15)    FOREIGN KEY -> gl_journal.voucher (posting reference)
posting_status    CHAR(1)     (P=Pending, D=Posted, R=Reversed)
```

---

### 8.3 Proposed Windows & Forms

**PRIMARY FORMS:**

1. **w_fa_master.srw** - Fixed Asset Maintenance
   - Purpose: Create/edit asset master records
   - Functions:
     - Lookup accounts for asset/accumulated/expense
     - Validate GL account codes
     - Set depreciation parameters
   - Datawindows:
     - dw_fa_list - List of all assets
     - dw_fa_detail - Asset detail entry form

2. **w_fa_depreciation.srw** - Depreciation Calculator & Posting
   - Purpose: Monthly depreciation processing
   - Functions:
     - Calculate depreciation for all active assets
     - Generate depreciation journal entries
     - Preview entries before posting
   - Datawindows:
     - dw_depr_calc - Calculated depreciation lines
     - dw_depr_preview - Journal entry preview

3. **w_fa_disposal.srw** - Asset Disposal/Retirement
   - Purpose: Record asset disposal
   - Functions:
     - Deactivate asset
     - Create gain/loss journal entry
     - Update GL
   - Datawindows:
     - dw_disposal_entry - Disposal transaction entry

---

### 8.4 Proposed Datawindows

| DW Name | Table(s) | Purpose | Type |
|---------|----------|---------|------|
| dw_fa_list | fa_asset | List all assets with status | Read-only grid |
| dw_fa_detail | fa_asset + gl_acc | Asset detail with account lookups | Entry form |
| dw_depr_calc | fa_asset + fa_depreciation | Depreciation calculation | Read-only summary |
| dw_depr_preview | gl_journal | Preview depreciation journal entries | Read-only journal view |
| dw_depr_post | gl_journal | Journal posting (update datawindow) | Insert/Update |
| dw_disposal | fa_asset | Disposal entry form | Entry form |

---

### 8.5 Proposed Functions/Procedures

**PowerBuilder Functions:**

1. **f_fa_calculate_depreciation(as_period_date, as_site_id) -> ll_records_created**
   - Calculate depreciation for all active assets in month
   - Store in fa_depreciation table
   - Return count of records created

2. **f_fa_generate_journal(as_period_date, as_site_id) -> ls_voucher**
   - Convert fa_depreciation records into gl_journal entries
   - Create single voucher with multiple lines (one per asset)
   - Return generated voucher number for posting

3. **f_fa_post_depreciation(as_voucher) -> ll_result**
   - Post depreciation journal (update posting='Y')
   - Update gl_saldo accounts
   - Return: 1=success, 0=failure

4. **f_fa_validate_accounts(as_asset_account, as_accum_account, as_exp_account) -> ll_valid**
   - Verify accounts exist in gl_acc
   - Verify accounts have DetailYN='1'
   - Return: 1=valid, 0=invalid

5. **f_fa_get_book_value(as_asset_id) -> ld_book_value**
   - Calculate current book value (cost - accumulated depreciation)
   - Used for asset listing and reporting

**SQL Functions (Optional, for complex calculations):**

```sql
-- Calculate accumulated depreciation to date
SELECT SUM(monthly_depr) INTO :ld_accum
  FROM fa_depreciation
 WHERE fa_asset_id = :ls_asset_id
   AND period_date <= :ldt_cutoff_date

-- Book value calculation
ld_book_value = (acquisition_cost - ld_accum)
```

---

### 8.6 Proposed Reports

1. **rp_fa_master_list.rsr** - Fixed Asset Register
   - Lists all assets with acquisition details
   - Shows GL accounts mapping
   - Export to Excel

2. **rp_fa_depreciation_schedule.rsr** - Depreciation Schedule
   - Monthly depreciation by asset category
   - Accumulated depreciation by month
   - Year-to-date totals

3. **rp_fa_disposal_log.rsr** - Asset Disposals
   - Historical disposals
   - Gain/loss analysis
   - Proceeds summary

4. **rp_fa_gl_reconciliation.rsr** - GL Account Reconciliation
   - Asset accounts vs. detail ledger
   - Accumulated depreciation reconciliation
   - Depreciation expense reconciliation

---

## PART 9: INTEGRATION WITH EXISTING CLOSING PROCESS

### 9.1 Modified w_closing_journal.srw Flow

**NEW STEPS (after existing closing logic):**

```powerbuilder
// EXISTING CLOSING LOGIC (RL, Summary entries)
...

// NEW: DEPRECIATION PROCESSING
// Step: Calculate and post depreciation
ls_period_date = DATE(idt_tgl)
ll_calc_count = f_fa_calculate_depreciation(ldt_tgl, gs_site)

IF ll_calc_count > 0 THEN
    // Generate depreciation journal
    ls_voucher_depr = f_fa_generate_journal(ldt_tgl, gs_site)
    
    // Post depreciation (same as manual posting)
    ll_result = f_fa_post_depreciation(ls_voucher_depr)
    
    IF ll_result = 1 THEN
        f_log("6100", "FA", "POSTING", "Depreciation posted: " + ls_voucher_depr, ls_voucher_depr)
    ELSE
        MESSAGEBOX('Error', 'Depreciation posting failed')
        RETURN
    END IF
END IF

// CONTINUE: Existing closing validation
...
```

---

## PART 10: GAP ANALYSIS

### 10.1 What Exists (VERIFIED)

**VERIFIED FROM SOURCE CODE:**

| Item | Status | Evidence |
|------|--------|----------|
| Voucher numbering system | ✅ VERIFIED | w_gl_journal.srw lines 165-172 |
| Debit-credit validation | ✅ VERIFIED | w_gl_journal.srw lines 102-110 |
| Journal posting mechanism | ✅ VERIFIED | w_gl_journal.srw ue_save event |
| Multi-table views of GL journal | ✅ VERIFIED | dw_journal1/2/3 datawindows |
| Cost center routing | ✅ VERIFIED | w_gl_journal.srw dw_2 buttonclicked |
| Cash flow routing | ✅ VERIFIED | w_gl_journal.srw dw_2 buttonclicked |
| Closing process | ✅ VERIFIED | w_closing_journal.srw |
| Account lookup with validation | ✅ VERIFIED | w_gl_journal.srw dw_2 buttonclicked |
| Multi-currency support | ✅ VERIFIED | dw_journal3 with curr_id, rate_rp |

---

### 10.2 What is ASSUMED (Needs Verification)

**ASSUMPTION FROM EXCEL FILE NAME:**

| Item | Assumption | Action Required |
|------|-----------|-----------------|
| Depreciation categories | 5 categories (Building, Vehicle, Office Equip, Workshop Equip, Land) | [ ] Extract Excel and verify |
| Depreciation rates | Straight-line, 4-25 years depending on category | [ ] Extract Excel and verify |
| GL account mapping | Pattern: 10x-xxx (asset), 158-xxx (accumulated) | [ ] Extract Excel and verify |
| Expense accounts | Pattern: 412-xxx (depreciation expense) | [ ] Extract Excel and verify |
| Calculation method | Monthly depreciation = Cost / Useful Life (months) | [ ] Extract Excel and verify |
| Current accumulated values | In fa_depreciation table or recalculated | [ ] Determine calculation approach |

---

### 10.3 What Needs to be CREATED

**NEW DATABASE TABLES:**
- [ ] fa_asset (asset master)
- [ ] fa_depreciation (monthly calculations)
- [ ] fa_disposal (disposal history)
- [ ] fa_depreciation_audit (change log)

**NEW POWERBUILDER WINDOWS:**
- [ ] w_fa_master.srw (asset maintenance)
- [ ] w_fa_depreciation.srw (depreciation calculator)
- [ ] w_fa_disposal.srw (asset disposal)
- [ ] w_fa_ledger.srw (asset ledger/detail)

**NEW DATAWINDOWS:**
- [ ] dw_fa_list.srd
- [ ] dw_fa_detail.srd
- [ ] dw_depr_calc.srd
- [ ] dw_depr_preview.srd
- [ ] dw_depr_post.srd
- [ ] dw_disposal.srd

**NEW FUNCTIONS:**
- [ ] f_fa_calculate_depreciation()
- [ ] f_fa_generate_journal()
- [ ] f_fa_post_depreciation()
- [ ] f_fa_validate_accounts()
- [ ] f_fa_get_book_value()

**MODIFIED FUNCTIONS:**
- [ ] w_closing_journal.srw - Add depreciation processing step

**NEW REPORTS:**
- [ ] rp_fa_master_list.rsr
- [ ] rp_fa_depreciation_schedule.rsr
- [ ] rp_fa_disposal_log.rsr
- [ ] rp_fa_gl_reconciliation.rsr

---

## PART 11: IMPLEMENTATION CHECKLIST

### Phase 0: Planning (CURRENT)
- [x] Reverse engineer journal architecture
- [x] Analyze closing process
- [x] Identify patterns in AP, AR, IV modules
- [ ] Extract and analyze Excel depreciation file
- [ ] Verify GL account structure for FA accounts

### Phase 1: Database Schema
- [ ] Create fa_asset table
- [ ] Create fa_depreciation table
- [ ] Create fa_disposal table
- [ ] Create fa_depreciation_audit table
- [ ] Add new GL accounts for depreciation
- [ ] Test schema with sample data

### Phase 2: Asset Master Maintenance
- [ ] Build w_fa_master.srw window
- [ ] Create dw_fa_list.srd (asset listing)
- [ ] Create dw_fa_detail.srd (asset detail entry)
- [ ] Implement f_fa_validate_accounts() function
- [ ] Test asset creation and editing

### Phase 3: Depreciation Calculation
- [ ] Implement f_fa_calculate_depreciation() function
- [ ] Create dw_depr_calc.srd (calculation preview)
- [ ] Test calculation accuracy against Excel baseline
- [ ] Validate period-end calculations

### Phase 4: Journal Generation & Posting
- [ ] Implement f_fa_generate_journal() function
- [ ] Implement f_fa_post_depreciation() function
- [ ] Create dw_depr_preview.srd (journal preview)
- [ ] Create dw_depr_post.srd (update datawindow)
- [ ] Test journal posting to gl_journal table

### Phase 5: Integration with Closing
- [ ] Modify w_closing_journal.srw to call depreciation functions
- [ ] Test depreciation posting during month-end closing
- [ ] Validate GL balance updates
- [ ] Verify debit-credit balance in closing entries

### Phase 6: Asset Disposal
- [ ] Create w_fa_disposal.srw window
- [ ] Implement disposal logic
- [ ] Create gain/loss journal entries
- [ ] Test disposal posting

### Phase 7: Reporting
- [ ] Create rp_fa_master_list.rsr
- [ ] Create rp_fa_depreciation_schedule.rsr
- [ ] Create rp_fa_disposal_log.rsr
- [ ] Create rp_fa_gl_reconciliation.rsr

### Phase 8: Testing & Validation
- [ ] Unit test: Depreciation calculations
- [ ] Integration test: GL posting
- [ ] Reconciliation test: Excel vs. FA module
- [ ] Month-end closing test
- [ ] User acceptance testing

### Phase 9: Production Deployment
- [ ] Database backup
- [ ] Deploy schema changes
- [ ] Deploy PowerBuilder objects
- [ ] Run initial data load (if applicable)
- [ ] User training
- [ ] Go-live

---

## PART 12: APPROVAL CRITERIA

**Before Fixed Asset module is approved for production:**

- [ ] **Calculation Accuracy**: Module generates same depreciation values as current Excel workbook (±0.01 tolerance)
- [ ] **Journal Format**: Generated journals match existing gl_journal structure and validation rules
- [ ] **Posting Status**: Depreciation entries post correctly to GL with posting='Y'
- [ ] **GL Reconciliation**: Asset accounts balance (cost - accumulated = book value)
- [ ] **Debit-Credit Balance**: All depreciation entries have sum(debit) = sum(credit)
- [ ] **Period Integrity**: No overlapping depreciation calculations across months
- [ ] **Database Safety**: Works correctly with SQL Anywhere 9
- [ ] **PowerBuilder Compatibility**: Compiles and runs on PowerBuilder 11.5
- [ ] **Month-End Closing**: Integrates seamlessly with existing closing process
- [ ] **Audit Trail**: All depreciation entries traceable to source (fa_depreciation table)
- [ ] **Disposal Functionality**: Asset disposal creates correct gain/loss entries
- [ ] **Report Accuracy**: All reports reconcile to GL accounts
- [ ] **User Training**: Documentation and training completed
- [ ] **Go-Live Readiness**: Approved by accounting and IT teams

---

## PART 13: KNOWLEDGE BASE LINKS

**Related Memories & Documentation:**
- [[refresh-journal-ap-selisih-kurs]] - Journal refresh mechanism for AP module
- [[ekspedisi-pembelian-jurnal-mismatch]] - Journal reconciliation issues

**Key Files (This Analysis):**
- C:\BTV\debug\w_gl_journal.srw (Primary journal window)
- C:\BTV\debug\w_closing_journal.srw (Closing mechanism)
- C:\BTV\debug\w_refresh_journal.srw (Batch refresh pattern)
- C:\BTV\debug\dw_journal*.srd (Journal datawindows)

---

## QUESTIONS FOR USER

**Before proceeding to implementation, clarify:**

1. **Excel File**: Can you manually review `WP_Aset tetap_TAM 2026.xlsx` and provide:
   - Actual depreciation rates per asset category?
   - GL accounts currently used for each category?
   - Depreciation method (straight-line, declining, accelerated)?

2. **Useful Life**: What is the useful life assumption for each category?
   - Buildings: ___ years?
   - Vehicles: ___ years?
   - Equipment: ___ years?

3. **Accumulated Depreciation**: How is it currently tracked?
   - Is it manually calculated in Excel and entered to GL?
   - Or auto-calculated based on fixed depreciation rate?

4. **Month of Depreciation**: When in the month is depreciation recorded?
   - First day of month (for upcoming month)?
   - Last day of month (for current month)?
   - Specific day in month?

5. **Salvage Value**: Are salvage values in use?
   - If yes: Are they depreciated on (Cost - Salvage) or full Cost?

6. **Disposal Accounting**: For asset sales:
   - Book value = Cost - Accumulated Depreciation?
   - Gain/Loss = Sale Price - Book Value?

---

**END OF REVERSE ENGINEERING ANALYSIS**

*Document prepared: 2026-06-15*
*Status: Ready for implementation planning*
