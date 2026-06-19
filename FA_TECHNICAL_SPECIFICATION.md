# Fixed Asset (Penyusutan Aktiva) Module - Technical Specification

**Document Status:** PRELIMINARY DESIGN (Requires Excel Analysis)  
**Date:** 2026-06-15  
**Target Platform:** PowerBuilder 11.5, SQL Anywhere 9, Windows

---

## TABLE OF CONTENTS

1. [Database Schema](#database-schema)
2. [Window & Form Specifications](#window--form-specifications)
3. [Datawindow Specifications](#datawindow-specifications)
4. [Function Library](#function-library)
5. [Report Specifications](#report-specifications)
6. [Integration Points](#integration-points)

---

## DATABASE SCHEMA

### 1.1 NEW TABLES TO CREATE

#### TABLE: fa_asset (Fixed Asset Master)

**Purpose:** Store all fixed assets under management

**SQL Create Statement:**

```sql
CREATE TABLE fa_asset (
    fa_asset_id         CHAR(20)        NOT NULL,
    site_id             CHAR(4)         NOT NULL,
    asset_category      CHAR(15)        NOT NULL,  -- Building, Vehicle, Equipment, etc.
    asset_description   VARCHAR(100)    NOT NULL,
    asset_serial_number CHAR(50),                  -- Serial/SKU number
    acquisition_date    DATETIME        NOT NULL,  -- Purchase/capitalization date
    acquisition_cost    DECIMAL(18,2)   NOT NULL,  -- Original cost in IDR
    salvage_value       DECIMAL(18,2),             -- Residual value (0 if not used)
    useful_life_month   LONG            NOT NULL,  -- Depreciation period in months
    depreciation_rate   DECIMAL(5,2)    NOT NULL,  -- Annual rate (e.g., 20 = 20% per year)
    depreciation_method CHAR(1)         NOT NULL,  -- S=Straight-line, D=Declining, A=Accelerated
    gl_account_asset    CHAR(15)        NOT NULL,  -- Asset account code (FK -> gl_acc)
    gl_account_accum    CHAR(15)        NOT NULL,  -- Accumulated depreciation account (FK -> gl_acc)
    gl_account_expense  CHAR(15)        NOT NULL,  -- Depreciation expense account (FK -> gl_acc)
    cost_center_id      CHAR(15),                  -- Optional: department/cost center
    project_id          CHAR(15),                  -- Optional: project allocation
    location_id         CHAR(20),                  -- Optional: physical location code
    status              CHAR(1)         NOT NULL DEFAULT 'A',  -- A=Active, D=Disposed, I=Inactive
    notes               VARCHAR(500),              -- Additional notes
    created_date        DATETIME        NOT NULL,
    created_by          CHAR(20)        NOT NULL,
    updated_date        DATETIME,
    updated_by          CHAR(20),
    
    PRIMARY KEY (fa_asset_id),
    CONSTRAINT fk_fa_asset_site FOREIGN KEY (site_id) REFERENCES gl_setup(site_id),
    CONSTRAINT fk_fa_asset_gl_asset FOREIGN KEY (gl_account_asset) REFERENCES gl_acc(accountcode),
    CONSTRAINT fk_fa_asset_gl_accum FOREIGN KEY (gl_account_accum) REFERENCES gl_acc(accountcode),
    CONSTRAINT fk_fa_asset_gl_expense FOREIGN KEY (gl_account_expense) REFERENCES gl_acc(accountcode),
    CONSTRAINT fk_fa_asset_cc FOREIGN KEY (cost_center_id) REFERENCES gl_depart(depart_id),
    CONSTRAINT fk_fa_asset_proj FOREIGN KEY (project_id) REFERENCES gl_project(project_id)
);

CREATE UNIQUE INDEX idx_fa_asset_id ON fa_asset(fa_asset_id);
CREATE INDEX idx_fa_asset_site_status ON fa_asset(site_id, status);
CREATE INDEX idx_fa_asset_category ON fa_asset(asset_category);
CREATE INDEX idx_fa_asset_gl_account ON fa_asset(gl_account_asset, gl_account_accum);
```

---

#### TABLE: fa_depreciation (Monthly Depreciation Calculation)

**Purpose:** Store calculated depreciation for each asset per month

**SQL Create Statement:**

```sql
CREATE TABLE fa_depreciation (
    fa_depr_id          CHAR(20)        NOT NULL,
    fa_asset_id         CHAR(20)        NOT NULL,
    site_id             CHAR(4)         NOT NULL,
    period_date         DATETIME        NOT NULL,  -- Month-end date (e.g., 2026-01-31)
    monthly_depr        DECIMAL(18,2)   NOT NULL,  -- Monthly depreciation amount
    accumulated_depr    DECIMAL(18,2)   NOT NULL,  -- Total accumulated to this month
    book_value          DECIMAL(18,2)   NOT NULL,  -- Cost - accumulated depreciation
    gl_voucher          CHAR(15),                  -- Reference to gl_journal.voucher
    posting_status      CHAR(1)         NOT NULL DEFAULT 'P',  -- P=Pending, D=Posted, R=Reversed
    calculation_date    DATETIME        NOT NULL,  -- When calculated
    calculated_by       CHAR(20),                  -- User who calculated
    posted_date         DATETIME,                  -- When posted to GL
    posted_by           CHAR(20),                  -- User who posted
    notes               VARCHAR(200),              -- Calculation notes
    
    PRIMARY KEY (fa_depr_id),
    CONSTRAINT fk_fa_depr_asset FOREIGN KEY (fa_asset_id) REFERENCES fa_asset(fa_asset_id),
    CONSTRAINT fk_fa_depr_site FOREIGN KEY (site_id) REFERENCES gl_setup(site_id),
    CONSTRAINT fk_fa_depr_gl_voucher FOREIGN KEY (gl_voucher) REFERENCES gl_journal(voucher)
);

CREATE UNIQUE INDEX idx_fa_depr_period ON fa_depreciation(fa_asset_id, period_date);
CREATE INDEX idx_fa_depr_site_period ON fa_depreciation(site_id, period_date);
CREATE INDEX idx_fa_depr_status ON fa_depreciation(posting_status);
```

---

#### TABLE: fa_disposal (Asset Disposal History)

**Purpose:** Track asset disposals and gains/losses

**SQL Create Statement:**

```sql
CREATE TABLE fa_disposal (
    fa_disposal_id      CHAR(20)        NOT NULL,
    fa_asset_id         CHAR(20)        NOT NULL,
    site_id             CHAR(4)         NOT NULL,
    disposal_date       DATETIME        NOT NULL,  -- Sale/retirement date
    disposal_method     CHAR(1)         NOT NULL,  -- S=Sale, R=Retirement, D=Donation, L=Loss
    sale_price          DECIMAL(18,2),             -- Proceeds from sale
    book_value_at_sale  DECIMAL(18,2)   NOT NULL,  -- Cost - accumulated depr at sale date
    gain_loss_amount    DECIMAL(18,2),             -- Sale price - book value
    gl_voucher          CHAR(15),                  -- Reference to gain/loss journal entry
    posting_status      CHAR(1)         NOT NULL DEFAULT 'P',  -- P=Pending, D=Posted
    disposal_notes      VARCHAR(500),              -- Reason for disposal
    created_date        DATETIME        NOT NULL,
    created_by          CHAR(20)        NOT NULL,
    
    PRIMARY KEY (fa_disposal_id),
    CONSTRAINT fk_fa_disposal_asset FOREIGN KEY (fa_asset_id) REFERENCES fa_asset(fa_asset_id),
    CONSTRAINT fk_fa_disposal_site FOREIGN KEY (site_id) REFERENCES gl_setup(site_id),
    CONSTRAINT fk_fa_disposal_gl_voucher FOREIGN KEY (gl_voucher) REFERENCES gl_journal(voucher)
);

CREATE INDEX idx_fa_disposal_asset ON fa_disposal(fa_asset_id);
CREATE INDEX idx_fa_disposal_date ON fa_disposal(disposal_date);
```

---

#### TABLE: fa_depreciation_audit (Change Audit Trail)

**Purpose:** Maintain audit log of all depreciation calculation changes

**SQL Create Statement:**

```sql
CREATE TABLE fa_depreciation_audit (
    audit_id            LONG            NOT NULL PRIMARY KEY,
    fa_depr_id          CHAR(20)        NOT NULL,
    action_type         CHAR(1)         NOT NULL,  -- C=Created, U=Updated, D=Deleted
    old_monthly_depr    DECIMAL(18,2),
    new_monthly_depr    DECIMAL(18,2),
    old_posting_status  CHAR(1),
    new_posting_status  CHAR(1),
    change_reason       VARCHAR(200),
    changed_date        DATETIME        NOT NULL,
    changed_by          CHAR(20)        NOT NULL,
    
    CONSTRAINT fk_fa_audit_depr FOREIGN KEY (fa_depr_id) REFERENCES fa_depreciation(fa_depr_id)
);

CREATE INDEX idx_fa_audit_depr_id ON fa_depreciation_audit(fa_depr_id);
CREATE INDEX idx_fa_audit_date ON fa_depreciation_audit(changed_date);
```

---

### 1.2 NEW GL ACCOUNTS TO ADD

**These account codes should be added to gl_acc table:**

#### Asset Accounts (Debit Balance)

```
101-xxx     Bangunan (Buildings)
101-001     Bangunan - Kantor Pusat (Head Office Building)
101-002     Bangunan - Cabang (Branch Buildings)

102-xxx     Tanah (Land) - Non-depreciable
102-001     Tanah - Kantor Pusat
102-002     Tanah - Cabang

103-xxx     Peralatan Kantor (Office Equipment)
103-001     Peralatan Kantor - Furnitur
103-002     Peralatan Kantor - Elektronik

104-xxx     Kendaraan (Vehicles)
104-001     Kendaraan - Kendaraan Operasional
104-002     Kendaraan - Kendaraan Penjualan

105-xxx     Peralatan Bengkel (Workshop Equipment)
105-001     Peralatan Bengkel - Mesin
105-002     Peralatan Bengkel - Alat Kerja
```

#### Accumulated Depreciation Accounts (Credit Balance)

```
158-001     Akumulasi Penyusutan Bangunan
158-101     Akumulasi Penyusutan Peralatan Kantor
158-301     Akumulasi Penyusutan Kendaraan
158-401     Akumulasi Penyusutan Peralatan Bengkel
(Note: Tanah is non-depreciable, no accumulation account needed)
```

#### Depreciation Expense Accounts (Debit Balance)

```
412-066     Penyusutan Aktiva Tetap
412-066-001 Penyusutan Bangunan
412-066-101 Penyusutan Peralatan Kantor
412-066-301 Penyusutan Kendaraan
412-066-401 Penyusutan Peralatan Bengkel

(Alternative: Use single 412-066 for all, or separate by category as above)
```

#### Gain/Loss on Disposal Accounts

```
411-050     Gain on Asset Disposal (Other Income)
513-050     Loss on Asset Disposal (Other Expense)
```

---

### 1.3 DATA INTEGRITY CONSTRAINTS

**Rules Enforced at Database Level:**

1. **fa_asset.useful_life_month > 0** - Useful life must be positive
2. **fa_asset.acquisition_cost >= 0** - Cost must be non-negative
3. **fa_asset.depreciation_rate > 0 AND <= 100** - Rate between 0-100%
4. **fa_depreciation.monthly_depr >= 0** - No negative depreciation
5. **fa_depreciation.accumulated_depr >= fa_depreciation.monthly_depr** - Accumulation must be >= monthly
6. **fa_depreciation.book_value >= 0** - Book value cannot be negative
7. **fa_depreciation.book_value = acquisition_cost - accumulated_depr** - Enforce calculation

---

## WINDOW & FORM SPECIFICATIONS

### 2.1 W_FA_MASTER.SRW - Fixed Asset Maintenance

**Purpose:** Create, edit, list, and deactivate fixed assets

**Features:**
- Asset listing with search/filter
- Asset detail entry form
- GL account validation
- Bulk import capability (future)
- Asset history view

**Window Properties:**
```powerbuilder
Global Type w_fa_master from w_frame_main
  Integer width = 5000
  Integer height = 3000
  String title = "Fixed Asset Master Maintenance"
  Boolean resizable = true
  
  [Controls to implement]
  dw_fa_list      (Asset list grid)
  dw_fa_detail    (Asset detail form)
  cb_new          (New button)
  cb_edit         (Edit button)
  cb_delete       (Delete button)
  cb_search       (Search button)
  cb_close        (Close button)
End Type
```

**Events to Implement:**

```powerbuilder
event ue_new
  // Clear detail DW
  dw_fa_detail.reset()
  // Enable form for new entry
  dw_fa_detail.setfocus()
End event

event ue_edit
  // Load selected asset into detail form
  IF dw_fa_list.getrow() <= 0 THEN RETURN
  ll_row = dw_fa_list.getrow()
  ls_asset_id = dw_fa_list.getitemstring(ll_row, 'fa_asset_id')
  dw_fa_detail.retrieve(ls_asset_id)
End event

event ue_save
  // Validate GL accounts
  ls_asset_account = dw_fa_detail.object.gl_account_asset[1]
  ls_accum_account = dw_fa_detail.object.gl_account_accum[1]
  ls_exp_account = dw_fa_detail.object.gl_account_expense[1]
  
  ll_result = f_fa_validate_accounts(ls_asset_account, ls_accum_account, ls_exp_account)
  IF ll_result = 0 THEN
    MESSAGEBOX('Error', 'One or more GL accounts are invalid')
    RETURN
  END IF
  
  // Insert or update fa_asset table
  dw_fa_detail.accepttext()
  IF dw_fa_detail.update() = 1 THEN
    COMMIT
    MESSAGEBOX('Info', 'Asset saved successfully')
    ue_refresh()
  ELSE
    ROLLBACK
    MESSAGEBOX('Error', 'Failed to save asset')
  END IF
End event

event ue_refresh
  dw_fa_list.retrieve(gs_site)
End event
```

---

### 2.2 W_FA_DEPRECIATION.SRW - Depreciation Calculator

**Purpose:** Calculate depreciation, preview entries, and post to GL

**Features:**
- Period selection (month/year)
- Depreciation calculation
- Journal entry preview
- Post to GL function
- Calculation validation

**Window Properties:**
```powerbuilder
Global Type w_fa_depreciation from w_frame_main
  Integer width = 5500
  Integer height = 3500
  String title = "Fixed Asset Depreciation Processing"
  
  [Controls to implement]
  sle_period       (Period selector: YYYY-MM)
  cb_calculate     (Calculate depreciation button)
  dw_calc_preview  (Depreciation calculation preview)
  dw_journal_preview (Generated journal entry preview)
  cb_post          (Post to GL button)
  cb_close         (Close button)
End Type
```

**Key Logic:**

```powerbuilder
event ue_calculate
  ldt_period = DATE(sle_period.text + '-01')
  
  // Call calculation function
  ll_count = f_fa_calculate_depreciation(ldt_period, gs_site)
  
  IF ll_count > 0 THEN
    dw_calc_preview.retrieve(gs_site, ldt_period)
    MESSAGEBOX('Info', STRING(ll_count) + ' assets calculated for depreciation')
  ELSE
    MESSAGEBOX('Warning', 'No assets found to depreciate for this period')
  END IF
End event

event ue_post
  IF dw_calc_preview.rowcount() <= 0 THEN
    MESSAGEBOX('Error', 'No depreciation calculations to post')
    RETURN
  END IF
  
  // Generate and post depreciation journal
  ldt_period = DATE(sle_period.text + '-01')
  ls_voucher = f_fa_generate_journal(ldt_period, gs_site)
  
  IF ISNULL(ls_voucher) OR ls_voucher = '' THEN
    MESSAGEBOX('Error', 'Failed to generate depreciation journal')
    RETURN
  END IF
  
  ll_result = f_fa_post_depreciation(ls_voucher)
  IF ll_result = 1 THEN
    MESSAGEBOX('Info', 'Depreciation posted successfully')
    dw_journal_preview.retrieve(ls_voucher)
  ELSE
    MESSAGEBOX('Error', 'Failed to post depreciation')
  END IF
End event
```

---

### 2.3 W_FA_DISPOSAL.SRW - Asset Disposal

**Purpose:** Record asset disposals and generate gain/loss entries

**Features:**
- Disposal entry form
- Automatic gain/loss calculation
- Journal entry generation
- Posting to GL

**Window Properties:**
```powerbuilder
Global Type w_fa_disposal from w_frame_main
  Integer width = 4000
  Integer height = 2500
  String title = "Fixed Asset Disposal"
  
  [Controls to implement]
  cb_asset_lookup  (Asset lookup button)
  st_asset_info    (Display asset info)
  sle_disposal_date (Disposal date)
  ddlb_method      (Disposal method: Sale, Retirement, etc.)
  sle_sale_price   (Sale proceeds)
  st_book_value    (Calculated book value)
  st_gain_loss     (Calculated gain/loss)
  cb_post          (Post disposal entry)
  cb_close         (Close button)
End Type
```

---

## DATAWINDOW SPECIFICATIONS

### 3.1 DW_FA_LIST.SRD - Asset List Grid

**Purpose:** Display all fixed assets with basic information

**Base Table:** fa_asset

**Columns to Display:**
```
fa_asset_id         (10%)  - Asset ID
asset_description   (20%)  - Asset Description
asset_category      (12%)  - Category
acquisition_date    (12%)  - Acquisition Date
acquisition_cost    (12%)  - Acquisition Cost (IDR)
accumulated_depr    (12%)  - Accumulated Depreciation
book_value          (12%)  - Current Book Value
status              (8%)   - Status (A/D/I)
```

**DW Properties:**
```
Dataobject: "dw_fa_list"
Retrieve args: site_id
Sort: asset_category, acquisition_date DESC
Allow: Insert=No, Update=Yes (for status only), Delete=No
```

---

### 3.2 DW_FA_DETAIL.SRD - Asset Detail Entry Form

**Purpose:** Single asset entry/edit form

**Base Table:** fa_asset

**Form Fields:**
```
fa_asset_id              (Read-only for edit mode)
asset_description        (Required, 100 chars)
asset_category           (Dropdown: Building, Vehicle, Equipment, etc.)
asset_serial_number      (Optional, 50 chars)
acquisition_date         (Required, calendar popup)
acquisition_cost         (Required, DECIMAL(18,2))
salvage_value            (Optional, DECIMAL(18,2))
useful_life_month        (Required, positive integer)
depreciation_rate        (Required, 0-100%)
depreciation_method      (Dropdown: S, D, A)
gl_account_asset         (Required, lookup with validation)
gl_account_accum         (Required, lookup with validation)
gl_account_expense       (Required, lookup with validation)
cost_center_id           (Optional, lookup)
project_id               (Optional, lookup)
status                   (Radio: Active, Disposed, Inactive)
notes                    (Optional, 500 chars, multiline)
```

**Validation Rules:**
- acquisition_cost > 0
- useful_life_month > 0
- depreciation_rate between 0-100
- All GL accounts must exist and have DetailYN='1'
- salvage_value < acquisition_cost

---

### 3.3 DW_DEPR_CALC.SRD - Depreciation Calculation Preview

**Purpose:** Display calculated depreciation for current period

**Base Query:**
```sql
SELECT
    fa_depr.fa_asset_id,
    fa_asset.asset_description,
    fa_asset.asset_category,
    fa_depr.acquisition_cost,
    fa_depr.accumulated_depr_prior,
    fa_depr.monthly_depr,
    fa_depr.accumulated_depr_current,
    fa_depr.book_value
FROM fa_depreciation fa_depr
JOIN fa_asset ON fa_depr.fa_asset_id = fa_asset.fa_asset_id
WHERE fa_depr.period_date = :period_date
  AND fa_depr.site_id = :site_id
ORDER BY fa_asset.asset_category, fa_asset.asset_description
```

**Columns:**
```
fa_asset_id            (10%)  - Asset ID
asset_description      (20%)  - Asset Description
asset_category         (10%)  - Category
acquisition_cost       (12%)  - Cost (IDR)
accumulated_prior      (12%)  - Accumulated (Prior)
monthly_depr           (12%)  - Monthly Depreciation
accumulated_current    (12%)  - Accumulated (Current)
book_value             (12%)  - Book Value
```

**DW Properties:**
```
Allow: Insert=No, Update=No, Delete=No
Summary: Total monthly_depr, accumulated_depr_current at bottom
```

---

### 3.4 DW_DEPR_PREVIEW.SRD - Journal Entry Preview

**Purpose:** Show proposed GL journal entries before posting

**Base Query:**
```sql
SELECT
    gl_journal.urut,
    gl_acc.accountcode,
    gl_acc.accountdes,
    CASE WHEN urut = 1 THEN gl_journal.debet ELSE NULL END AS debet,
    CASE WHEN urut > 1 THEN gl_journal.kredit ELSE NULL END AS kredit,
    gl_journal.ket
FROM gl_journal
JOIN gl_acc ON gl_journal.account_id = gl_acc.accountcode
WHERE gl_journal.voucher = :voucher_number
ORDER BY gl_journal.urut
```

**Validation:**
- Display SUM(debet) and SUM(kredit) at bottom
- Highlight if unbalanced

---

### 3.5 DW_DEPR_POST.SRD - Update Datawindow (Internal Use)

**Purpose:** Insert/update gl_journal table with depreciation entries

**Properties:**
```
Dataobject: "dw_journal3"  (Reuse existing journal datawindow pattern)
Allow Insert=Yes, Update=No, Delete=No
Key Columns: voucher, urut, site_id
```

---

## FUNCTION LIBRARY

### 4.1 F_FA_CALCULATE_DEPRECIATION()

**Purpose:** Calculate depreciation for all active assets in a month

**Signature:**
```powerbuilder
FUNCTION long f_fa_calculate_depreciation(
    as_period_date DATETIME,
    as_site_id CHAR(4)
) RETURN long
// Returns: Number of depreciation records created, -1 on error
```

**Algorithm:**

```powerbuilder
FUNCTION long f_fa_calculate_depreciation(as_period_date DATETIME, as_site_id CHAR(4))
    DECLARE LOCAL VARIABLES
    LONG ll_result = 0, ll_row
    DECIMAL ld_monthly_depr, ld_accumulated, ld_book_value, ld_cost
    CHAR(20) ls_asset_id
    DATETIME ldt_period
    
    BEGIN
        // Validate period format (must be end-of-month)
        ldt_period = f_eom(as_period_date)
        
        // Loop through all active assets
        SELECT fa_asset_id, acquisition_cost, useful_life_month
        INTO :ls_asset_id, :ld_cost, :ll_months
        FROM fa_asset
        WHERE site_id = :as_site_id
          AND status = 'A'
          AND acquisition_date <= :ldt_period
        
        WHILE SQLCA.SQLCODE = 0
            // Check if already calculated this month
            SELECT COUNT(*) INTO :ll_row
            FROM fa_depreciation
            WHERE fa_asset_id = :ls_asset_id
              AND period_date = :ldt_period
            
            IF ll_row = 0 THEN  // Not yet calculated
                // Calculate monthly depreciation (straight-line)
                ld_monthly_depr = ld_cost / ll_months
                
                // Get accumulated depreciation to prior month
                SELECT ISNULL(SUM(monthly_depr), 0) INTO :ld_accumulated
                FROM fa_depreciation
                WHERE fa_asset_id = :ls_asset_id
                  AND period_date < :ldt_period
                
                ld_accumulated = ld_accumulated + ld_monthly_depr
                ld_book_value = ld_cost - ld_accumulated
                
                // Insert into fa_depreciation
                INSERT INTO fa_depreciation (
                    fa_depr_id, fa_asset_id, site_id, period_date,
                    monthly_depr, accumulated_depr, book_value,
                    posting_status, calculation_date, calculated_by
                ) VALUES (
                    f_guid(), :ls_asset_id, :as_site_id, :ldt_period,
                    :ld_monthly_depr, :ld_accumulated, :ld_book_value,
                    'P', TODAY(), :gs_userid
                )
                
                ll_result++
            END IF
            
            FETCH NEXT...
        END WHILE
        
        COMMIT
        RETURN ll_result
    END
    
    CATCH (Exception le)
        ROLLBACK
        f_log("6200", "FA", "CALC_ERROR", le.getMessage())
        RETURN -1
    END CATCH
END FUNCTION
```

---

### 4.2 F_FA_GENERATE_JOURNAL()

**Purpose:** Create GL journal entries from fa_depreciation records

**Signature:**
```powerbuilder
FUNCTION string f_fa_generate_journal(
    as_period_date DATETIME,
    as_site_id CHAR(4)
) RETURN string
// Returns: Voucher number (e.g., "101202606DEPR0001"), or empty string on error
```

**Algorithm:**

```powerbuilder
FUNCTION string f_fa_generate_journal(as_period_date DATETIME, as_site_id CHAR(4))
    DECLARE LOCAL VARIABLES
    STRING ls_voucher, ls_key, ls_account_exp, ls_account_accum
    LONG ll_depr_count, i
    DATETIME ldt_period
    DECIMAL ld_total_depr
    
    BEGIN
        // Generate voucher number for depreciation entries
        ldt_period = f_eom(as_period_date)
        ls_key = gs_site + STRING(ldt_period, 'yymmdd') + 'DEPR'
        
        SELECT MAX(voucher)
        INTO :ls_voucher
        FROM gl_journal
        WHERE LEFT(voucher, 13) = :ls_key
        
        IF ISNULL(ls_voucher) THEN
            ls_voucher = ls_key + '0001'
        ELSE
            ls_voucher = ls_key + STRING(LONG(MID(ls_voucher, 14, 4)) + 1, '0000')
        END IF
        
        // Get all pending depreciation for this period
        // Create header entry (urut = 1)
        INSERT INTO gl_journal (
            voucher, urut, site_id, tgl, account_id, modul_id,
            voucher_manual, curr_id, rate_rp, ket, posting, debet, kredit
        ) VALUES (
            :ls_voucher, 1, :as_site_id, :ldt_period, '411-050', 'FA',
            ls_voucher, 'IDR', 1, 'Penyusutan Aktiva Tetap', 'N', 0, 0
        )
        
        // Create detail entries (urut = 2+) for expense and accumulated
        ld_total_depr = 0
        ll_depr_count = 0
        
        FOR i = 1 TO [depreciation_records.rowcount()]
            ls_account_exp = depreciation_records.getitemstring(i, 'gl_account_expense')
            ls_account_accum = depreciation_records.getitemstring(i, 'gl_account_accum')
            ld_depr = depreciation_records.getitemdecimal(i, 'monthly_depr')
            
            // Debit: Depreciation Expense
            INSERT INTO gl_journal (
                voucher, urut, site_id, tgl, account_id, modul_id,
                voucher_manual, curr_id, rate_rp, ket, posting, debet, kredit
            ) VALUES (
                :ls_voucher, 2 + (i-1)*2, :as_site_id, :ldt_period,
                :ls_account_exp, 'FA', '', 'IDR', 1,
                'Depr: ' + [asset_description], 'N', :ld_depr, 0
            )
            
            // Credit: Accumulated Depreciation
            INSERT INTO gl_journal (
                voucher, urut, site_id, tgl, account_id, modul_id,
                voucher_manual, curr_id, rate_rp, ket, posting, debet, kredit
            ) VALUES (
                :ls_voucher, 2 + (i-1)*2 + 1, :as_site_id, :ldt_period,
                :ls_account_accum, 'FA', '', 'IDR', 1,
                'Accum: ' + [asset_description], 'N', 0, :ld_depr
            )
            
            ld_total_depr = ld_total_depr + ld_depr
        END FOR
        
        // Update header with totals
        UPDATE gl_journal
        SET debet = :ld_total_depr, kredit = :ld_total_depr
        WHERE voucher = :ls_voucher AND urut = 1
        
        COMMIT
        RETURN ls_voucher
    END
    
    CATCH (Exception le)
        ROLLBACK
        f_log("6200", "FA", "JOURNAL_GEN_ERROR", le.getMessage())
        RETURN ""
    END CATCH
END FUNCTION
```

---

### 4.3 F_FA_POST_DEPRECIATION()

**Purpose:** Post depreciation journal to GL (mark as posted)

**Signature:**
```powerbuilder
FUNCTION long f_fa_post_depreciation(as_voucher CHAR(15)) RETURN long
// Returns: 1 on success, 0 on failure
```

**Implementation:**

```powerbuilder
FUNCTION long f_fa_post_depreciation(as_voucher CHAR(15))
    BEGIN
        // Update journal posting status
        UPDATE gl_journal
        SET posting = 'Y'
        WHERE voucher = :as_voucher
        
        IF SQLCA.SQLCODE <> 0 THEN RETURN 0
        
        // Update fa_depreciation posting status
        UPDATE fa_depreciation
        SET posting_status = 'D',
            posted_date = TODAY(),
            posted_by = :gs_userid,
            gl_voucher = :as_voucher
        WHERE [period matches voucher period]
        
        IF SQLCA.SQLCODE <> 0 THEN
            ROLLBACK
            RETURN 0
        END IF
        
        COMMIT
        f_log("6200", "FA", "POST_SUCCESS", "Depreciation posted: " + as_voucher)
        RETURN 1
    END
    
    CATCH (Exception le)
        ROLLBACK
        f_log("6200", "FA", "POST_ERROR", le.getMessage())
        RETURN 0
    END CATCH
END FUNCTION
```

---

### 4.4 F_FA_VALIDATE_ACCOUNTS()

**Purpose:** Validate GL account codes for asset, accumulated, and expense

**Signature:**
```powerbuilder
FUNCTION long f_fa_validate_accounts(
    as_asset_acc CHAR(15),
    as_accum_acc CHAR(15),
    as_exp_acc CHAR(15)
) RETURN long
// Returns: 1 if all valid, 0 if any invalid
```

---

### 4.5 F_FA_GET_BOOK_VALUE()

**Purpose:** Calculate current book value of an asset

**Signature:**
```powerbuilder
FUNCTION decimal f_fa_get_book_value(as_asset_id CHAR(20)) RETURN decimal
// Returns: Book value (Cost - Accumulated Depreciation)
```

---

## REPORT SPECIFICATIONS

### 5.1 RP_FA_MASTER_LIST.RSR - Fixed Asset Register

**Purpose:** Complete listing of all fixed assets

**Parameters:**
- p_site_id (Optional: Site filter)
- p_asset_category (Optional: Category filter)
- p_as_of_date (Required: Valuation date)

**Key Columns:**
- Asset ID
- Description
- Category
- Acquisition Date
- Acquisition Cost
- Accumulated Depreciation (as of p_as_of_date)
- Book Value
- GL Account (Asset/Accumulated/Expense)
- Status
- Location/Cost Center

**Totals:**
- Total Acquisition Cost
- Total Accumulated Depreciation
- Total Book Value

---

### 5.2 RP_FA_DEPRECIATION_SCHEDULE.RSR - Depreciation Schedule

**Purpose:** Monthly depreciation activity and schedule

**Parameters:**
- p_period_from (YYYY-MM)
- p_period_to (YYYY-MM)

**Columns:**
- Period
- Asset ID
- Description
- Category
- Monthly Depreciation
- Year-to-Date Depreciation
- Accumulated to Period
- Book Value at Period-End

**Subtotals:**
- Monthly
- By Category

---

### 5.3 RP_FA_DISPOSAL_LOG.RSR - Disposal History

**Purpose:** Record of asset disposals

**Columns:**
- Disposal Date
- Asset ID / Description
- Original Cost
- Accumulated Depreciation
- Book Value at Disposal
- Sale Price
- Gain/(Loss)
- Disposal Method

**Summary:**
- Total Gains
- Total Losses
- Net Gain/(Loss)

---

### 5.4 RP_FA_GL_RECONCILIATION.RSR - GL Reconciliation Report

**Purpose:** Reconcile asset detail to GL accounts

**Three-Way Reconciliation:**

1. **Asset Account Reconciliation**
   - GL Account Balance (from GL trial balance)
   - Total Acquisition Cost (from fa_asset)
   - Variance

2. **Accumulated Depreciation Reconciliation**
   - GL Account Balance (from GL)
   - Total Accumulated Depr (from fa_depreciation)
   - Variance

3. **Depreciation Expense Reconciliation**
   - GL Account Balance (from GL)
   - Total Monthly Depreciation (from fa_depreciation, by month)
   - Variance

---

## INTEGRATION POINTS

### 6.1 Modified w_closing_journal.srw

**New Code in Closing Process:**

```powerbuilder
// AFTER existing closing logic, BEFORE validation close

// NEW: DEPRECIATION PROCESSING
// Retrieve current period from gl_setup
SELECT periode FROM gl_setup INTO :ldt_period

// Calculate depreciation for month
ll_calc_count = f_fa_calculate_depreciation(ldt_period, gs_site)

IF ll_calc_count > 0 THEN
    // Generate journal entry
    ls_depr_voucher = f_fa_generate_journal(ldt_period, gs_site)
    
    IF NOT ISNULL(ls_depr_voucher) THEN
        // Post depreciation
        ll_result = f_fa_post_depreciation(ls_depr_voucher)
        
        IF ll_result = 1 THEN
            f_log("6200", "FA", "CLOSING", "Depreciation posted: " + ls_depr_voucher)
        ELSE
            MESSAGEBOX('Error', 'Depreciation posting failed during closing')
            ROLLBACK
            RETURN
        END IF
    END IF
END IF

// CONTINUE: Existing closing validation
...
```

---

### 6.2 Modified gl_setup Table

**Optional Enhancement to Track FA Parameters:**

```sql
ALTER TABLE gl_setup ADD COLUMN (
    fa_enabled          CHAR(1) DEFAULT 'Y',  -- Enable FA module
    fa_method_default   CHAR(1) DEFAULT 'S',  -- Default depreciation method
    fa_rounding         INTEGER DEFAULT 2     -- Decimal rounding places
)
```

---

### 6.3 User Permissions

**New Permissions to Add:**

```
Permission Code | Description
FA_VIEW        | View fixed assets
FA_CREATE      | Create new fixed assets
FA_EDIT        | Edit fixed assets
FA_DELETE      | Delete fixed assets (soft delete only)
FA_DEPR_CALC   | Calculate depreciation
FA_DEPR_POST   | Post depreciation to GL
FA_DEPR_REVERSE| Reverse depreciation entries
FA_DISPOSAL    | Record asset disposals
FA_REPORT      | Generate FA reports
```

---

## IMPLEMENTATION ROADMAP

**Estimated Effort:** 40-50 days (depending on complexity)

**Phase Timeline:**

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Design & Schema | 3 days | SQL schema, account setup |
| Asset Master | 8 days | w_fa_master, dw_fa_*, functions |
| Depreciation Calc | 10 days | f_fa_calculate, dw_depr_calc |
| Journal Generation | 8 days | f_fa_generate_journal, posting |
| Closing Integration | 5 days | w_closing_journal modifications |
| Disposal & Reporting | 8 days | w_fa_disposal, reports |
| Testing | 10 days | Unit, integration, UAT |
| Deployment | 3 days | Training, go-live |

---

**END OF TECHNICAL SPECIFICATION**
