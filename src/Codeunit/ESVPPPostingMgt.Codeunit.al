namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Posting;
using Microsoft.Sales.Receivables;

codeunit 60103 "ESV PP Posting Mgt."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeInsertDtldCustLedgEntryUnapply', '', false, false)]
    local procedure CopyUnapplicationReference(var NewDtldCustLedgEntry: Record "Detailed Cust. Ledg. Entry"; OldDtldCustLedgEntry: Record "Detailed Cust. Ledg. Entry")
    begin
        NewDtldCustLedgEntry."ESV PP Plan ID" := OldDtldCustLedgEntry."ESV PP Plan ID";
        NewDtldCustLedgEntry."Sales Order No." := OldDtldCustLedgEntry."Sales Order No.";
        NewDtldCustLedgEntry."ESV PP Document References" := OldDtldCustLedgEntry."ESV PP Document References";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Bank Acc. Reconciliation Post", 'OnPostPaymentApplicationsOnBeforeValidateApplyRequirements', '', false, false)]
    local procedure PreparePayment(BankAccReconciliationLine: Record "Bank Acc. Reconciliation Line"; var GenJournalLine: Record "Gen. Journal Line")
    var
        Plan: Record "ESV PP Payment Plan";
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        if not Plan.Get(BankAccReconciliationLine.SystemId) then
            exit;
        Mgt.CheckReady(Plan, BankAccReconciliationLine);
        GenJournalLine."ESV PP Plan ID" := Plan.ID;
        // A multi-order receipt must not be consumed in full by the legacy FindFirst subscriber.
        GenJournalLine."Sales Order No." := '';
        GenJournalLine."Allow Application" := false;
        GenJournalLine.TestField("Applies-to ID", '');
        GenJournalLine.TestField("Applies-to Doc. No.", '');
        GenJournalLine.TestField("Document Type", GenJournalLine."Document Type"::Payment);
        GenJournalLine.TestField("Account No.", Plan."Customer No.");
        GenJournalLine.TestField("Currency Code", Plan."Currency Code");
        GenJournalLine.TestField(Amount, -Plan."Payment Amount");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeInsertDtldCustLedgEntry', '', false, false)]
    local procedure SetInitialPaymentReference(var DtldCustLedgEntry: Record "Detailed Cust. Ledg. Entry"; GenJournalLine: Record "Gen. Journal Line")
    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        if IsNullGuid(GenJournalLine."ESV PP Plan ID") or
           (DtldCustLedgEntry."Entry Type" <> DtldCustLedgEntry."Entry Type"::"Initial Entry") then
            exit;
        DtldCustLedgEntry."ESV PP Plan ID" := GenJournalLine."ESV PP Plan ID";
        DtldCustLedgEntry."Sales Order No." := Mgt.GetSingleOrderNo(GenJournalLine."ESV PP Plan ID");
        DtldCustLedgEntry."ESV PP Document References" :=
            CopyStr(Mgt.GetDocumentReferences(GenJournalLine."ESV PP Plan ID"), 1, MaxStrLen(DtldCustLedgEntry."ESV PP Document References"));
    end;

    [EventSubscriber(ObjectType::Table, Database::"Bank Acc. Reconciliation Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure ClearDeletedUnpostedLine(var Rec: Record "Bank Acc. Reconciliation Line"; RunTrigger: Boolean)
    var
        Plan: Record "ESV PP Payment Plan";
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        if Rec.IsTemporary() then
            exit;
        if Plan.Get(Rec.SystemId) then
            if Plan."Payment Entry No." = 0 then
                Mgt.ClearUnpostedPlan(Plan.ID);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Applied Payment Entry", 'OnAfterDeleteEvent', '', false, false)]
    local procedure ClearRemovedApprovedApplication(var Rec: Record "Applied Payment Entry"; RunTrigger: Boolean)
    var
        BankLine: Record "Bank Acc. Reconciliation Line";
        RemainingApplication: Record "Applied Payment Entry";
        Plan: Record "ESV PP Payment Plan";
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        if Rec.IsTemporary() then
            exit;
        if not BankLine.Get(Rec."Statement Type", Rec."Bank Account No.", Rec."Statement No.", Rec."Statement Line No.") then
            exit;
        if not Plan.Get(BankLine.SystemId) then
            exit;
        // Approval/reopening rejects native suggestions while the plan is still a draft.
        // Financial posting has already captured Payment Entry No. before native cleanup.
        if (Plan.Status <> Plan.Status::Approved) or (Plan."Payment Entry No." <> 0) then
            exit;
        RemainingApplication.FilterAppliedPmtEntry(BankLine);
        if RemainingApplication.IsEmpty() then
            Mgt.ClearUnpostedPlan(Plan.ID);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeCustLedgEntryInsert', '', false, false)]
    local procedure MarkManagedPayment(var CustLedgerEntry: Record "Cust. Ledger Entry"; var GenJournalLine: Record "Gen. Journal Line")
    var
        Allocation: Record "ESV PP Allocation";
    begin
        if IsNullGuid(GenJournalLine."ESV PP Plan ID") then
            exit;
        CustLedgerEntry."ESV PP Plan ID" := GenJournalLine."ESV PP Plan ID";
        Allocation.SetRange("Plan ID", GenJournalLine."ESV PP Plan ID");
        Allocation.SetFilter("Document Type", '<>%1', Allocation."Document Type"::"Credit Memo");
        Allocation.SetFilter(Amount, '>0');
        CustLedgerEntry."ESV PP Reserved" := not Allocation.IsEmpty();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnPrepareTempCustLedgEntryOnAfterSetFiltersByAppliesToId', '', false, false)]
    local procedure ExcludeReservedReceipts(var OldCustLedgerEntry: Record "Cust. Ledger Entry"; GenJournalLine: Record "Gen. Journal Line")
    begin
        if CopyStr(GenJournalLine."Applies-to ID", 1, 3) <> 'PP-' then
            OldCustLedgerEntry.SetRange("ESV PP Reserved", false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnPrepareTempCustLedgEntryOnBeforeTempOldCustLedgEntryInsert', '', false, false)]
    local procedure PreventExplicitReservedReceipt(var CustLedgerEntry: Record "Cust. Ledger Entry"; GenJournalLine: Record "Gen. Journal Line")
    begin
        if (CopyStr(GenJournalLine."Applies-to ID", 1, 3) <> 'PP-') and CustLedgerEntry."ESV PP Reserved" then
            Error(ReservedPaymentErr);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeApplyCustLedgEntry', '', false, false)]
    local procedure PreventApplyingReservedReceipt(var NewCVLedgEntryBuf: Record "CV Ledger Entry Buffer"; var GenJnlLine: Record "Gen. Journal Line")
    var
        Entry: Record "Cust. Ledger Entry";
    begin
        if CopyStr(GenJnlLine."Applies-to ID", 1, 3) = 'PP-' then
            exit;
        if Entry.Get(NewCVLedgEntryBuf."Entry No.") then
            if Entry."ESV PP Reserved" then
                Error(ReservedPaymentErr);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnAfterCustLedgEntryInsert', '', false, false)]
    local procedure CapturePayment(var CustLedgerEntry: Record "Cust. Ledger Entry"; GenJournalLine: Record "Gen. Journal Line"; PreviewMode: Boolean)
    var
        Plan: Record "ESV PP Payment Plan";
        Allocation: Record "ESV PP Allocation";
    begin
        if IsNullGuid(GenJournalLine."ESV PP Plan ID") or PreviewMode then
            exit;
        Plan.Get(GenJournalLine."ESV PP Plan ID");
        Plan.TestField(Status, Plan.Status::Approved);
        Plan.TestField("Payment Entry No.", 0);
        Plan."Payment Entry No." := CustLedgerEntry."Entry No.";
        Plan.Modify();
        Allocation.SetRange("Plan ID", Plan.ID);
        Allocation.ModifyAll("Payment Entry No.", CustLedgerEntry."Entry No.", false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Bank Acc. Reconciliation Post", 'OnBeforeFinalizePost', '', false, false)]
    local procedure FinalizeBank(var BankAccReconciliation: Record "Bank Acc. Reconciliation")
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        if BankAccReconciliation."Statement Type" <> BankAccReconciliation."Statement Type"::"Payment Application" then
            exit;
        Plan.SetRange("Bank Account No.", BankAccReconciliation."Bank Account No.");
        Plan.SetRange("Statement No.", BankAccReconciliation."Statement No.");
        Plan.SetRange(Status, Plan.Status::Approved);
        Plan.SetFilter("Payment Entry No.", '<>0');
        if Plan.FindSet() then
            repeat
                ProcessPlan(Plan.ID);
            until Plan.Next() = 0;
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure ProcessPlan(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
        Allocation: Record "ESV PP Allocation";
        Invoice: Record "ESV PP Allocation";
        ApplyEntries: Codeunit "ESV PP Apply Entries";
        CreditEntryNo: Integer;
    begin
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        Plan.Get(PlanID);
        Plan.TestField("Payment Entry No.");
        if not (Plan.Status in [Plan.Status::Approved, Plan.Status::Posted]) then
            Error(PlanStateErr);
        ApplyEntries.CheckIntegrity(Plan.ID);
        CheckReservation(Plan);
        // Credits are consumed first, so invoice cash allocations see the reduced balance.
        Allocation.SetRange("Plan ID", Plan.ID);
        Allocation.SetRange("Document Type", Allocation."Document Type"::"Credit Memo");
        if Allocation.FindSet() then
            repeat
                if Allocation.Amount > Allocation."Applied Amount" then begin
                    Invoice.SetRange("Plan ID", Plan.ID);
                    Invoice.SetRange("Document Type", Invoice."Document Type"::Invoice);
                    Invoice.SetRange("Document No.", Allocation."Credit Target Invoice No.");
                    Invoice.FindFirst();
                    CreditEntryNo := Allocation."Target Entry No.";
                    ApplyEntries.ApplyAllocation(Allocation, CreditEntryNo, Invoice."Target Entry No.", Allocation.Amount - Allocation."Applied Amount");
                end;
            until Allocation.Next() = 0;
        Allocation.SetRange("Document Type", Allocation."Document Type"::Invoice);
        if Allocation.FindSet() then
            repeat
                ApplyEntries.ApplyAllocation(Allocation, Plan."Payment Entry No.", Allocation."Target Entry No.", Allocation.Amount - Allocation."Applied Amount");
            until Allocation.Next() = 0;
        Plan.Status := Plan.Status::Posted;
        Plan.Modify();
        ApplyExistingOrderInvoices(Plan.ID);
    end;

    local procedure ApplyExistingOrderInvoices(PlanID: Guid)
    var
        Allocation: Record "ESV PP Allocation";
        InvoiceLine: Record "Sales Invoice Line";
        InvoiceHeader: Record "Sales Invoice Header";
        Plan: Record "ESV PP Payment Plan";
        InvoiceNumbers: List of [Code[20]];
        InvoiceNo: Code[20];
    begin
        Plan.Get(PlanID);
        Allocation.SetRange("Plan ID", PlanID);
        Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
        if Allocation.FindSet() then
            repeat
                InvoiceLine.SetRange("Order No.", Allocation."Document No.");
                if InvoiceLine.FindSet() then
                    repeat
                        if InvoiceHeader.Get(InvoiceLine."Document No.") then
                            if (InvoiceHeader."Bill-to Customer No." = Allocation."Customer No.") and
                               (InvoiceHeader."Currency Code" = Allocation."Currency Code") and
                               (InvoiceHeader.SystemCreatedAt >= Allocation."Order Created At") and
                               (InvoiceHeader.SystemCreatedAt >= Plan."Approved At") and
                               not InvoiceNumbers.Contains(InvoiceHeader."No.") then
                                InvoiceNumbers.Add(InvoiceHeader."No.");
                    until InvoiceLine.Next() = 0;
            until Allocation.Next() = 0;
        foreach InvoiceNo in InvoiceNumbers do
            ApplyInvoice(InvoiceNo);
    end;

    procedure CheckReservation(Plan: Record "ESV PP Payment Plan")
    var
        Payment: Record "Cust. Ledger Entry";
        Allocation: Record "ESV PP Allocation";
        Reserved: Decimal;
    begin
        Payment.ReadIsolation(IsolationLevel::UpdLock);
        Payment.Get(Plan."Payment Entry No.");
        Payment.TestField("Customer No.", Plan."Customer No.");
        Payment.TestField("Currency Code", Plan."Currency Code");
        Payment.TestField("Document Type", Payment."Document Type"::Payment);
        Payment.TestField(Reversed, false);
        Payment.CalcFields("Remaining Amount");
        Allocation.SetRange("Plan ID", Plan.ID);
        Allocation.SetFilter("Document Type", '<>%1', Allocation."Document Type"::"Credit Memo");
        if Allocation.FindSet() then
            repeat
                Reserved += Allocation.Amount - Allocation."Applied Amount";
            until Allocation.Next() = 0;
        if -Payment."Remaining Amount" < Reserved then
            Error(ReservationErr, Payment."Document No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnRunOnBeforeFinalizePosting', '', false, false)]
    local procedure ApplyPostedOrder(var SalesHeader: Record "Sales Header"; var SalesInvoiceHeader: Record "Sales Invoice Header"; PreviewMode: Boolean)
    begin
        if PreviewMode or (SalesInvoiceHeader."No." = '') then
            exit;
        ApplyInvoice(SalesInvoiceHeader."No.");
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure ApplyInvoice(InvoiceNo: Code[20])
    var
        InvoiceHeader: Record "Sales Invoice Header";
        InvoiceEntry: Record "Cust. Ledger Entry";
        InvoiceLine: Record "Sales Invoice Line";
        Allocation: Record "ESV PP Allocation";
        Plan: Record "ESV PP Payment Plan";
        SalesHeader: Record "Sales Header";
        ApplyEntries: Codeunit "ESV PP Apply Entries";
        OrderNumbers: List of [Code[20]];
        OrderNo: Code[20];
        OrderCap: Decimal;
        ToApply: Decimal;
    begin
        InvoiceHeader.Get(InvoiceNo);
        InvoiceEntry.SetRange("Document Type", InvoiceEntry."Document Type"::Invoice);
        InvoiceEntry.SetRange("Document No.", InvoiceNo);
        InvoiceEntry.SetRange("Customer No.", InvoiceHeader."Bill-to Customer No.");
        InvoiceEntry.SetRange(Open, true);
        if not InvoiceEntry.FindFirst() then
            exit;
        InvoiceLine.SetRange("Document No.", InvoiceNo);
        InvoiceLine.SetFilter("Order No.", '<>%1', '');
        if InvoiceLine.FindSet() then
            repeat
                if not OrderNumbers.Contains(InvoiceLine."Order No.") then
                    OrderNumbers.Add(InvoiceLine."Order No.");
            until InvoiceLine.Next() = 0;
        if (OrderNumbers.Count() = 0) and (InvoiceHeader."Order No." <> '') then
            OrderNumbers.Add(InvoiceHeader."Order No.");
        foreach OrderNo in OrderNumbers do begin
            InvoiceEntry.Get(InvoiceEntry."Entry No.");
            InvoiceEntry.CalcFields("Remaining Amount");
            OrderCap := InvoiceEntry."Remaining Amount";
            if OrderNumbers.Count() > 1 then begin
                InvoiceLine.SetRange("Order No.", OrderNo);
                InvoiceLine.CalcSums("Amount Including VAT");
                OrderCap := Minimum(OrderCap, InvoiceLine."Amount Including VAT");
            end;
            Allocation.ReadIsolation(IsolationLevel::UpdLock);
            Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
            Allocation.SetRange("Document No.", OrderNo);
            Allocation.SetRange("Customer No.", InvoiceHeader."Bill-to Customer No.");
            Allocation.SetRange("Currency Code", InvoiceHeader."Currency Code");
            Allocation.SetFilter("Payment Entry No.", '<>0');
            if Allocation.FindSet() then
                repeat
                    Plan.Get(Allocation."Plan ID");
                    if (Plan.Status = Plan.Status::Posted) and (InvoiceHeader.SystemCreatedAt >= Plan."Approved At") then begin
                        if InvoiceHeader.SystemCreatedAt < Allocation."Order Created At" then
                            Error(ReusedOrderErr, OrderNo);
                        ApplyEntries.CheckIntegrity(Plan.ID);
                        CheckReservation(Plan);
                        if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
                            if SalesHeader.SystemId <> Allocation."Order SystemId" then
                                Error(ReusedOrderErr, OrderNo);
                        ToApply := Minimum(OrderCap, Allocation.Amount - Allocation."Applied Amount");
                        if ToApply > 0 then begin
                            ApplyEntries.ApplyAllocation(Allocation, Plan."Payment Entry No.", InvoiceEntry."Entry No.", ToApply);
                            OrderCap -= ToApply;
                        end;
                    end;
                until Allocation.Next() = 0;
        end;
    end;

    local procedure Minimum(First: Decimal; Second: Decimal): Decimal
    begin
        if First < Second then
            exit(First);
        exit(Second);
    end;

    var
        PlanStateErr: Label 'Only approved or posted allocation plans can be processed.';
        ReservationErr: Label 'Payment %1 no longer covers its reserved allocations. Review manual applications or reversals.', Comment = '%1 - payment document number';
        ReusedOrderErr: Label 'Order number %1 now belongs to a different order record.', Comment = '%1 - sales order number';
        ReservedPaymentErr: Label 'This receipt is reserved for specific payment allocations. Use the allocation plan instead of a separate customer entry application.';
}
