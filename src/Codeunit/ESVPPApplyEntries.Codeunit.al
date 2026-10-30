namespace Esvika.PrepaymentSolution;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Sales.Receivables;

codeunit 60102 "ESV PP Apply Entries"
{
    Permissions = tabledata "Cust. Ledger Entry" = rm;
    [CommitBehavior(CommitBehavior::Ignore)]
    procedure ApplyAllocation(var Allocation: Record "ESV PP Allocation"; CreditEntryNo: Integer; InvoiceEntryNo: Integer; Amount: Decimal)
    var
        Credit: Record "Cust. Ledger Entry";
        Invoice: Record "Cust. Ledger Entry";
        MarkEntry: Record "Cust. Ledger Entry";
        Detail: Record "Detailed Cust. Ledg. Entry";
        TempParameters: Record "Apply Unapply Parameters" temporary;
        Log: Record "ESV PP Application Log";
        GLSetup: Record "General Ledger Setup";
        SetApplication: Codeunit "Cust. Entry-SetAppl.ID";
        ApplyEntries: Codeunit "CustEntry-Apply Posted Entries";
        ApplicationContext: Codeunit "ESV PP Application Context";
        ApplicationID: Code[50];
        DetailNoBefore: Integer;
        CreditBalanceBefore: Decimal;
        InvoiceBalanceBefore: Decimal;
    begin
        if Amount <= 0 then
            exit;
        CheckIntegrity(Allocation."Plan ID");
        Credit.ReadIsolation(IsolationLevel::UpdLock);
        Invoice.ReadIsolation(IsolationLevel::UpdLock);
        Credit.Get(CreditEntryNo);
        Invoice.Get(InvoiceEntryNo);
        Credit.TestField("Customer No.", Allocation."Customer No.");
        Invoice.TestField("Customer No.", Allocation."Customer No.");
        Credit.TestField("Currency Code", Allocation."Currency Code");
        Invoice.TestField("Currency Code", Allocation."Currency Code");
        Credit.TestField(Open, true);
        Invoice.TestField(Open, true);
        Credit.TestField(Reversed, false);
        Invoice.TestField(Reversed, false);
        Invoice.TestField("Document Type", Invoice."Document Type"::Invoice);
        if Allocation."Document Type" = Allocation."Document Type"::"Credit Memo" then
            Credit.TestField("Document Type", Credit."Document Type"::"Credit Memo")
        else
            Credit.TestField("Document Type", Credit."Document Type"::Payment);
        Credit.TestField("Applies-to ID", '');
        Invoice.TestField("Applies-to ID", '');
        Credit.CalcFields("Remaining Amount");
        Invoice.CalcFields("Remaining Amount");
        if (Credit."Remaining Amount" > -Amount) or (Invoice."Remaining Amount" < Amount) then
            Error(BalanceChangedErr, Allocation."Document No.");
        CreditBalanceBefore := Credit."Remaining Amount";
        InvoiceBalanceBefore := Invoice."Remaining Amount";
        Detail.SetRange("Cust. Ledger Entry No.", CreditEntryNo);
        Detail.SetRange("Entry Type", Detail."Entry Type"::Application);
        if Detail.FindLast() then
            DetailNoBefore := Detail."Entry No.";
        ApplicationID := CopyStr('PP-' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 50);
        Credit."Applying Entry" := true;
        Credit.Modify();
        MarkEntry.SetRange("Entry No.", CreditEntryNo);
        SetApplication.SetApplId(MarkEntry, Credit, ApplicationID);
        MarkEntry.SetRange("Entry No.", InvoiceEntryNo);
        SetApplication.SetApplId(MarkEntry, Credit, ApplicationID);
        Credit.Get(CreditEntryNo);
        Credit.Validate("Amount to Apply", -Amount);
        Credit.Modify();
        Invoice.Get(InvoiceEntryNo);
        Invoice.Validate("Amount to Apply", Amount);
        Invoice.Modify();
        TempParameters.CopyFromCustLedgEntry(Credit);
        GLSetup.Get();
        if GLSetup."Journal Templ. Name Mandatory" then begin
            GLSetup.TestField("Apply Jnl. Template Name");
            GLSetup.TestField("Apply Jnl. Batch Name");
            TempParameters."Journal Template Name" := GLSetup."Apply Jnl. Template Name";
            TempParameters."Journal Batch Name" := GLSetup."Apply Jnl. Batch Name";
        end;
        TempParameters."Posting Date" := Credit."Posting Date";
        if Invoice."Posting Date" > TempParameters."Posting Date" then
            TempParameters."Posting Date" := Invoice."Posting Date";
        ApplicationContext.SetAllocation(Allocation);
        BindSubscription(ApplicationContext);
        if not ApplyEntries.Apply(Credit, TempParameters) then
            Error(ApplicationFailedErr);
        UnbindSubscription(ApplicationContext);
        Credit.Get(CreditEntryNo);
        Invoice.Get(InvoiceEntryNo);
        Credit.CalcFields("Remaining Amount");
        Invoice.CalcFields("Remaining Amount");
        if (Credit."Remaining Amount" - CreditBalanceBefore <> Amount) or
           (InvoiceBalanceBefore - Invoice."Remaining Amount" <> Amount) then
            Error(UnexpectedAdjustmentErr);
        Detail.SetFilter("Entry No.", '>%1', DetailNoBefore);
        if not Detail.FindLast() then
            Error(ApplicationFailedErr);
        Log.Init();
        Log."Plan ID" := Allocation."Plan ID";
        Log."Allocation Line No." := Allocation."Line No.";
        Log."Credit Entry No." := CreditEntryNo;
        Log."Invoice Entry No." := InvoiceEntryNo;
        Log.Amount := Amount;
        Log."Detailed Entry No." := Detail."Entry No.";
        Log."Applied At" := CurrentDateTime();
        Log.Insert(true);
        Allocation."Applied Amount" += Amount;
        Allocation.Modify(false);
        if Allocation."Document Type" <> Allocation."Document Type"::"Credit Memo" then
            RefreshReservation(Allocation."Plan ID", CreditEntryNo);
    end;

    local procedure RefreshReservation(PlanID: Guid; PaymentEntryNo: Integer)
    var
        Allocation: Record "ESV PP Allocation";
        Payment: Record "Cust. Ledger Entry";
        Reserved: Boolean;
    begin
        Allocation.SetRange("Plan ID", PlanID);
        Allocation.SetFilter("Document Type", '<>%1', Allocation."Document Type"::"Credit Memo");
        if Allocation.FindSet() then
            repeat
                Reserved := Reserved or (Allocation.Amount > Allocation."Applied Amount");
            until Allocation.Next() = 0;
        Payment.Get(PaymentEntryNo);
        Payment."ESV PP Reserved" := Reserved;
        Payment.Modify(false);
    end;

    procedure CheckIntegrity(PlanID: Guid)
    var
        Log: Record "ESV PP Application Log";
        Detail: Record "Detailed Cust. Ledg. Entry";
    begin
        Log.SetRange("Plan ID", PlanID);
        if Log.FindSet() then
            repeat
                if not Detail.Get(Log."Detailed Entry No.") then
                    Error(ManualChangeErr, Log."Entry No.");
                if Detail.Unapplied then
                    Error(ManualChangeErr, Log."Entry No.");
            until Log.Next() = 0;
    end;

    procedure CancelPlan(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
        Log: Record "ESV PP Application Log";
        Detail: Record "Detailed Cust. Ledg. Entry";
        Payment: Record "Cust. Ledger Entry";
    begin
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Posted);
        Log.SetRange("Plan ID", Plan.ID);
        if Log.FindSet() then
            repeat
                Detail.Get(Log."Detailed Entry No.");
                Detail.TestField(Unapplied, true);
            until Log.Next() = 0;
        Payment.ReadIsolation(IsolationLevel::UpdLock);
        Payment.Get(Plan."Payment Entry No.");
        Payment."ESV PP Reserved" := false;
        Payment.Modify(false);
        Plan.Status := Plan.Status::Cancelled;
        Plan.Modify();
    end;

    var
        BalanceChangedErr: Label 'The remaining amount for allocation %1 has changed. Review the payment before continuing.', Comment = '%1 - document reference';
        ApplicationFailedErr: Label 'The standard customer entry application did not complete.';
        ManualChangeErr: Label 'Application log entry %1 has been unapplied or changed externally. Review the allocation history before continuing.', Comment = '%1 - application history entry number';
        UnexpectedAdjustmentErr: Label 'The standard application changed balances beyond the allocated amount. Review payment discounts or tolerances before continuing.';
}
