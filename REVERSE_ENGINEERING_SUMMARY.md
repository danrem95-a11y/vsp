# Penyusutan Aktiva (Fixed Asset Depreciation) - Reverse Engineering Summary

**Executive Summary**  
**Date:** 2026-06-15  
**Status:** ✅ REVERSE ENGINEERING COMPLETE - READY FOR IMPLEMENTATION PLANNING

---

## KEY FINDINGS

### ✅ What We Discovered

The existing BTV accounting system uses a **proven, battle-tested journal framework** that has been refined through multiple modules (AP, AR, Inventory). The Fixed Asset module should follow this established pattern exactly.

---

## CORE ARCHITECTURE VERIFIED

### 1. Journal System (gl_journal table)

```
Structure:  Single table with header (urut=1) + detail lines (urut=2+)
Validation: Debit Total = Credit Total (enforced at UI layer)
Posting:    Manual via datawindow update (SQL INSERT/UPDATE)
Numbering:  {SITE} + {YYMM} + {TYPE} + {SEQUENCE}
```

**Pattern Applied to FA:**
- Voucher format: `{SITE} + {YYMMDD} + 'DEPR' + {SEQ}` → e.g., "101202606DEPR0001"
- Each depreciation run = one voucher with multiple line items
- Header (urut=1) summarizes; detail (urut=2+) lists individual assets

### 2. Closing Process (w_closing_journal.srw)

```
Flow:    Month-end → Delete old closing → Calculate → Insert entries → Post
Auto:    All entries created automatically (NOT manual)
Pattern: Uses same gl_journal table, validates debit-credit balance
```

**Pattern Applied to FA:**
- Call `f_fa_calculate_depreciation()` during closing
- Call `f_fa_generate_journal()` to create entries
- Call `f_fa_post_depreciation()` to mark as posted
- No new closing mechanism needed

### 3. Multi-Currency Support

```
Fields:  curr_id (currency code), rate_rp (exchange rate to IDR)
Storage: Dual amounts (original + converted to IDR)
Pattern: Applied automatically to all transactions
```

**Pattern Applied to FA:**
- All amounts in IDR (most likely)
- If multi-currency assets exist: Include rate_rp in depreciation calculation

### 4. Datawindow Strategy

```
Read:    Multiple views of same table (dw_journal1/2/3) with JOINs + lookups
Update:  Single update datawindow (dw_update) with base structure
Pattern: Display views are read-only; updates happen through dedicated DW
```

**Pattern Applied to FA:**
- dw_fa_detail.srd for entry (base)
- dw_depr_preview.srd for display (with GL account joins)
- dw_depr_post.srd for insertion

---

## CRITICAL SUCCESS FACTORS

### ✅ MUST DO

1. **Debit-Credit Validation**: Every journal entry must satisfy `SUM(DEBET) = SUM(KREDIT)`
   - Enforced at UI layer (BEFORE posting)
   - Validated in closing (automatic abort if unbalanced)

2. **Voucher Numbering**: Follow existing format exactly
   - Query max(voucher) for period
   - Increment sequence
   - Store both auto (voucher) and manual (voucher_manual)

3. **Use gl_journal Table**: Do NOT create separate FA journal table
   - Use existing table with modul_id = 'FA'
   - Follow existing column structure (voucher, urut, tgl, account_id, debet, kredit, etc.)

4. **Integrate into Closing**: Depreciation should be automatic calculation during month-end
   - Not optional, not manual
   - Called from w_closing_journal.srw

5. **GL Account Mapping**: Use existing gl_acc table
   - fa_asset.gl_account_asset → asset balance sheet account
   - fa_asset.gl_account_accum → accumulated depreciation contra-asset
   - fa_asset.gl_account_expense → depreciation expense P&L account

### ❌ MUST NOT DO

1. **Do NOT create new journal engine** - Use existing posting mechanism
2. **Do NOT create new voucher numbering** - Extend existing pattern
3. **Do NOT create new closing logic** - Integrate with existing process
4. **Do NOT create separate FA journal table** - Use gl_journal
5. **Do NOT bypass debit-credit validation** - Apply strict validation

---

## RECOMMENDED APPROACH

### Step 1: Create New FA Tables (3 tables)

**fa_asset** - Asset master data
- Track: asset ID, description, category, cost, useful life, GL accounts

**fa_depreciation** - Monthly depreciation records
- Track: asset, period, monthly amount, accumulated, book value, GL voucher reference

**fa_disposal** - Asset retirement/sale
- Track: asset, disposal date, proceeds, gain/loss, GL voucher reference

### Step 2: Add GL Accounts (3 categories)

**Asset Accounts** (101-105): Buildings, Equipment, Vehicles, etc.
**Accumulated Depreciation** (158-xxx): Contra-assets
**Depreciation Expense** (412-066): P&L accounts

### Step 3: Create Functions (5 functions)

**f_fa_calculate_depreciation()** - Calculate depreciation for period
**f_fa_generate_journal()** - Create GL journal entries
**f_fa_post_depreciation()** - Mark journal as posted
**f_fa_validate_accounts()** - Verify GL accounts exist
**f_fa_get_book_value()** - Calculate asset value

### Step 4: Create Forms (3 windows)

**w_fa_master.srw** - Asset maintenance
**w_fa_depreciation.srw** - Depreciation calculator + poster
**w_fa_disposal.srw** - Asset retirement

### Step 5: Create Datawindows (6 datawindows)

**dw_fa_list.srd** - Asset list grid
**dw_fa_detail.srd** - Asset entry form
**dw_depr_calc.srd** - Depreciation calculation preview
**dw_depr_preview.srd** - Journal entry preview
**dw_depr_post.srd** - Journal update (INSERT to gl_journal)
**dw_disposal.srd** - Disposal entry

### Step 6: Create Reports (4 reports)

**rp_fa_master_list.rsr** - Asset register
**rp_fa_depreciation_schedule.rsr** - Monthly depreciation
**rp_fa_disposal_log.rsr** - Disposal history
**rp_fa_gl_reconciliation.rsr** - GL reconciliation

### Step 7: Integrate with Closing (1 modification)

**Modify w_closing_journal.srw:**
- Add call to f_fa_calculate_depreciation()
- Add call to f_fa_generate_journal()
- Add call to f_fa_post_depreciation()

---

## ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────┐
│              FIXED ASSET DEPRECIATION MODULE                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ USER INTERFACES (PowerBuilder Windows)                       │
├─────────────────────────────────────────────────────────────┤
│  w_fa_master         │  w_fa_depreciation    │ w_fa_disposal │
│  ├─ dw_fa_list       │  ├─ dw_depr_calc      │ ├─ Entry form │
│  └─ dw_fa_detail     │  ├─ dw_depr_preview   │ └─ GL Journal │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ BUSINESS LOGIC (PowerBuilder Functions)                     │
├─────────────────────────────────────────────────────────────┤
│ f_fa_calculate_depreciation() → fa_depreciation table       │
│ f_fa_generate_journal()       → gl_journal table (entries)  │
│ f_fa_post_depreciation()      → gl_journal (posting='Y')    │
│ f_fa_validate_accounts()      → gl_acc validation           │
│ f_fa_get_book_value()         → Cost - Accumulated          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ DATABASES (SQL Anywhere 9)                                   │
├─────────────────────────────────────────────────────────────┤
│  fa_asset             fa_depreciation      fa_disposal       │
│  ├─ Asset master      ├─ Monthly calcs     ├─ Sale/retire    │
│  ├─ Categories        ├─ Accumulated       └─ Gain/loss      │
│  ├─ GL accounts       └─ GL voucher refs                     │
│  └─ Useful life                                              │
│                                                               │
│  gl_journal (existing)                     gl_acc (existing) │
│  ├─ Header: urut=1                        ├─ Asset accounts │
│  └─ Detail: urut=2+    ←─ Depr entries ─→ ├─ Accumulated    │
│                                            └─ Expense        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ CLOSING PROCESS INTEGRATION                                  │
├─────────────────────────────────────────────────────────────┤
│  w_closing_journal.srw                                      │
│  ├─ Existing: RL entries, summary accounts                 │
│  ├─ NEW: f_fa_calculate_depreciation()                     │
│  ├─ NEW: f_fa_generate_journal()                           │
│  └─ NEW: f_fa_post_depreciation()                          │
└─────────────────────────────────────────────────────────────┘
```

---

## TIMELINE ESTIMATE

| Phase | Effort | Start | End |
|-------|--------|-------|-----|
| Database Design | 3 days | Mon | Wed |
| Asset Master | 8 days | Thu | Thu+7 |
| Depreciation Calc & Journal | 10 days | Fri+7 | Mon+17 |
| Closing Integration | 5 days | Tue+17 | Sat+17 |
| Disposal & Reporting | 8 days | Sun+17 | Tue+24 |
| Testing (Unit, Integration, UAT) | 10 days | Wed+24 | Sat+30 |
| Deployment & Training | 3 days | Sun+30 | Tue+30 |
| **TOTAL** | **47 days** | **Mon** | **Tue+30** |

---

## CRITICAL DECISIONS NEEDED FROM USER

**Before implementation begins, user must clarify:**

### 1. Depreciation Rates & Methods

- [ ] What are actual rates per category? (Extract from Excel)
- [ ] Straight-line or declining-balance or accelerated?
- [ ] Do salvage values apply? If yes, depreciation on (Cost - Salvage)?

### 2. Asset Categories

- [ ] Confirm actual categories in use (Building, Vehicle, Equipment, etc.)
- [ ] Are there sub-categories? (e.g., Vehicle = Car, Truck, Motorcycle)
- [ ] Any category-specific business rules?

### 3. GL Account Structure

- [ ] Which accounts exist for assets, accumulated, expense?
- [ ] Should depreciation expense be single account (412-066) or split by category?
- [ ] What about gains/losses on disposal? (411-050 income, 513-050 expense?)

### 4. Depreciation Timing

- [ ] Which day of month is depreciation recorded?
- [ ] For assets acquired mid-month, depreciate full month or partial?
- [ ] For disposed assets, depreciate to disposal date or month-end?

### 5. Current Excel Reconciliation

- [ ] Has user been manually posting depreciation from Excel to GL?
- [ ] Should FA module takeover from Excel going forward?
- [ ] Do we need to backfill historical depreciation data?

---

## KNOWLEDGE BANK

### Two Analysis Documents Created

**1. todolist_penyusutan_aktiva.md** (Comprehensive Analysis)
   - Parts 1-7: Reverse engineering findings
   - Parts 8-13: Module design, architecture, approval criteria
   - 12 sections, ~1000 lines, ready for team review

**2. FA_TECHNICAL_SPECIFICATION.md** (Implementation Guide)
   - Database schema with CREATE TABLE statements
   - Window & form specifications with PowerBuilder code
   - Complete function signatures and algorithms
   - Report specifications
   - Integration points with existing code
   - Implementation roadmap with effort estimates

### Both Documents Located At

- `C:\BTV\debug\todolist_penyusutan_aktiva.md`
- `C:\BTV\debug\FA_TECHNICAL_SPECIFICATION.md`

---

## WHAT HAPPENS NEXT

### Phase 1: User Review & Clarification
1. User reviews both documents
2. User extracts/clarifies Excel depreciation rules
3. User confirms GL account structure
4. User approves design approach

### Phase 2: Implementation
1. Create database schema
2. Build asset master maintenance form
3. Implement depreciation calculation engine
4. Generate GL journal entries
5. Integrate with closing process
6. Create reports
7. Comprehensive testing
8. User training and go-live

### Phase 3: Production
1. Deploy to live database
2. Initial data load (if backfilling)
3. First month depreciation run
4. GL reconciliation
5. Month-end closing validation

---

## VERIFICATION CHECKLIST FOR USER

Before proceeding, verify these findings are correct:

- [ ] **Journal Pattern**: All transaction types (AP, AR, GL) use same gl_journal table?
- [ ] **Voucher Format**: Pattern of {SITE} + {YYMM} + {TYPE} + {SEQ} is standard?
- [ ] **Debit-Credit**: All modules enforce Debit Total = Credit Total?
- [ ] **Closing Process**: Closing happens monthly and is automated in w_closing_journal.srw?
- [ ] **GL Accounts**: Chart of accounts includes depreciation-related accounts?
- [ ] **Multi-Currency**: System supports multi-currency transactions with exchange rates?

---

## QUESTIONS FOR IMPLEMENTATION TEAM

1. **Database**: Is SQL Anywhere 9 still the target? (Need to verify data types)
2. **PowerBuilder**: Is version 11.5 current? (Confirm feature availability)
3. **Code Style**: Should FA module follow naming conventions of existing modules?
4. **Testing**: Should FA module have unit tests? (Existing code has manual testing only)
5. **Performance**: Are there large asset bases that require optimization?

---

## SUMMARY: WHAT'S DIFFERENT FROM EXCEL

| Aspect | Current (Excel) | Proposed (FA Module) |
|--------|-----------------|----------------------|
| **Depreciation Calc** | Manual formula | Automated function |
| **Data Entry** | Spreadsheet cells | Structured data table |
| **GL Posting** | Manual journal entry | Automatic GL journal |
| **Audit Trail** | Excel change history | Database audit log |
| **Reporting** | Static Excel sheets | Dynamic SQL reports |
| **Integration** | Copy-paste to GL | Direct GL posting |
| **Reconciliation** | Manual comparison | Automated validation |
| **Month-End** | Separate Excel process | Integrated with GL closing |

---

## ALIGNMENT WITH BUSINESS RULES

**Principle 1: No Framework Duplication**
✅ FA module uses existing journal table (gl_journal)
✅ FA module uses existing posting mechanism
✅ FA module integrates with existing closing process

**Principle 2: Consistency with Existing Modules**
✅ AP, AR, Inventory all follow same journal pattern
✅ FA module will follow identical pattern
✅ Common functions and validation rules apply

**Principle 3: Data Integrity**
✅ Debit-credit balance enforced at UI and closing layers
✅ GL account validation prevents invalid postings
✅ Audit trails capture all changes

**Principle 4: Audit & Compliance**
✅ All depreciation calculation records preserved
✅ GL journal entries fully traceable
✅ Period integrity enforced

---

## SUCCESS CRITERIA (Ready for Sign-Off)

The Fixed Asset module implementation will be considered complete when:

1. ✅ Depreciation calculations match Excel workbook (±0.01 tolerance)
2. ✅ All GL journal entries are balanced (debit = credit)
3. ✅ Integration with month-end closing is seamless
4. ✅ GL account reconciliation proves accurate
5. ✅ Asset disposal logic correctly computes gain/loss
6. ✅ All reports reconcile to GL accounts
7. ✅ System works on SQL Anywhere 9
8. ✅ Code compiles on PowerBuilder 11.5
9. ✅ User training completed
10. ✅ Accounting team approves for production use

---

**REVERSE ENGINEERING COMPLETE**

All analysis documents ready for review.
Implementation can begin upon user approval and clarifications.

---

**Prepared by:** Reverse Engineering Analysis  
**Date:** 2026-06-15  
**Status:** ✅ Ready for Implementation Planning
