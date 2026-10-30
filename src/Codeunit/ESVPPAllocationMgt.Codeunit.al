namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;
using Microsoft.Finance.Currency;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;

codeunit 60101 "ESV PP Allocation Mgt."
{
    procedure Detect(var BankLine: Record "Bank Acc. Reconciliation Line")
    var
        Plan: Record "ESV PP Payment Plan";
        Allocation: Record "ESV PP Allocation";
        Parser: Codeunit "ESV PP Reference Parser";
        References: List of [Text];
        ManualReferences: List of [Text];
        Reference: Text;
        LineNo: Integer;
    begin
        CheckIncomingLine(BankLine);
        Parser.Parse(GetPaymentText(BankLine), References);
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        if Plan.Get(BankLine.SystemId) then begin
            Plan.TestField(Status, Plan.Status::Draft);
            Allocation.SetRange("Plan ID", Plan.ID);
            Allocation.SetRange("Manually Added", true);
            if Allocation.FindSet() then
                repeat
                    ManualReferences.Add(Allocation."Document No.");
                    if not References.Contains(Allocation."Document No.") then
                        References.Add(Allocation."Document No.");
                until Allocation.Next() = 0;
            Allocation.Reset();
            Plan.Delete(true);
        end;
        if References.Count() = 0 then
            Error(NoReferencesErr);
        CheckDuplicateTransaction(BankLine);
        IdentifyCustomer(BankLine, References);
        CheckBankLine(BankLine);
        Plan.Init();
        Plan.ID := BankLine.SystemId;
        Plan."Bank Account No." := BankLine."Bank Account No.";
        Plan."Statement No." := BankLine."Statement No.";
        Plan."Statement Line No." := BankLine."Statement Line No.";
        Plan."Customer No." := BankLine."Account No.";
        Plan."Currency Code" := BankLine.GetCurrencyCode();
        Plan."Payment Date" := BankLine."Transaction Date";
        Plan."Payment Amount" := BankLine."Statement Amount";
        Plan."Payment Text" := CopyStr(GetPaymentText(BankLine), 1, MaxStrLen(Plan."Payment Text"));
        Plan."Transaction ID" := BankLine."Transaction ID";
        Plan.Insert(true);
        foreach Reference in References do begin
            LineNo += 10000;
            Allocation.Init();
            Allocation."Plan ID" := Plan.ID;
            Allocation."Line No." := LineNo;
            Allocation."Document No." := CopyStr(Reference, 1, 20);
            Allocation."Customer No." := Plan."Customer No.";
            Allocation."Currency Code" := Plan."Currency Code";
            Allocation."Manually Added" := ManualReferences.Contains(Reference);
            ResolveDocument(Allocation);
            Allocation.Amount := Allocation."Open Amount";
            Allocation.Insert(true);
        end;
        ProposeCreditTargets(Plan.ID);
        Recalculate(Plan.ID);
    end;

    procedure AddDocumentFromLine(PlanID: Guid; SourceLineNo: Integer; DocumentNo: Code[20])
    var
        Plan: Record "ESV PP Payment Plan";
        SourceAllocation: Record "ESV PP Allocation";
        MatchingType: Boolean;
    begin
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Draft);
        SourceAllocation.Get(PlanID, SourceLineNo);
        case SourceAllocation."Document Type" of
            SourceAllocation."Document Type"::Order:
                MatchingType := CopyStr(DocumentNo, 1, 2) = 'MT';
            SourceAllocation."Document Type"::Invoice:
                MatchingType := CopyStr(DocumentNo, 1, 2) = 'MA';
            SourceAllocation."Document Type"::"Credit Memo":
                MatchingType := CopyStr(DocumentNo, 1, 2) in ['KK', 'KR'];
        end;
        if not MatchingType then
            Error(SameDocumentTypeErr, SourceAllocation."Document Type");
        AddDocument(PlanID, DocumentNo);
    end;

    procedure AddDocument(PlanID: Guid; DocumentNo: Code[20])
    var
        Plan: Record "ESV PP Payment Plan";
        BankLine: Record "Bank Acc. Reconciliation Line";
        Allocation: Record "ESV PP Allocation";
        Parser: Codeunit "ESV PP Reference Parser";
        References: List of [Text];
        RemainingCash: Decimal;
        NextLineNo: Integer;
    begin
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Draft);
        Plan.TestField("Payment Entry No.", 0);
        BankLine.GetBySystemId(Plan.ID);
        CheckSnapshot(Plan, BankLine);
        Parser.Parse(DocumentNo, References);
        if References.Count() <> 1 then
            Error(FullDocumentNoErr);
        if References.Get(1) <> DocumentNo then
            Error(FullDocumentNoErr);
        Allocation.SetRange("Plan ID", Plan.ID);
        Allocation.SetRange("Document No.", DocumentNo);
        if not Allocation.IsEmpty() then
            Error(DuplicateDocumentErr, DocumentNo);
        Allocation.SetRange("Document No.");
        if Allocation.FindLast() then
            NextLineNo := Allocation."Line No.";
        Plan.CalcFields("Cash Allocated");
        RemainingCash := Maximum(0, Plan."Payment Amount" - Plan."Cash Allocated");
        Allocation.Init();
        Allocation."Plan ID" := Plan.ID;
        Allocation."Line No." := NextLineNo + 10000;
        Allocation."Document No." := DocumentNo;
        Allocation."Customer No." := Plan."Customer No.";
        Allocation."Currency Code" := Plan."Currency Code";
        Allocation."Manually Added" := true;
        ResolveDocument(Allocation);
        Allocation.Amount := Allocation."Open Amount";
        if Allocation."Document Type" <> Allocation."Document Type"::"Credit Memo" then
            if Allocation.Amount > RemainingCash then
                Allocation.Amount := RemainingCash;
        Allocation.Insert(true);
        // Keep previously reviewed amounts. Approval validates the complete cash/credit allocation.
        ProposeCreditTargets(Plan.ID);
    end;

    procedure Recalculate(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
        Allocation: Record "ESV PP Allocation";
        Credit: Record "ESV PP Allocation";
        CreditAmount: Decimal;
    begin
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Draft);
        Allocation.SetRange("Plan ID", PlanID);
        if Allocation.FindSet() then
            repeat
                ResolveDocument(Allocation);
                Allocation.Amount := Allocation."Open Amount";
                Allocation.Modify(true);
            until Allocation.Next() = 0;
        Allocation.SetRange("Document Type", Allocation."Document Type"::Invoice);
        if Allocation.FindSet() then
            repeat
                if Allocation."Document Type" = Allocation."Document Type"::Invoice then begin
                    CreditAmount := 0;
                    Credit.SetRange("Plan ID", PlanID);
                    Credit.SetRange("Document Type", Credit."Document Type"::"Credit Memo");
                    Credit.SetRange("Credit Target Invoice No.", Allocation."Document No.");
                    if Credit.FindSet() then
                        repeat
                            CreditAmount += Credit.Amount;
                        until Credit.Next() = 0;
                    Allocation.Amount := Maximum(0, Allocation.Amount - CreditAmount);
                end;
                Allocation.Modify(true);
            until Allocation.Next() = 0;
        LimitSingleCashAllocation(Plan);
    end;

    local procedure LimitSingleCashAllocation(Plan: Record "ESV PP Payment Plan")
    var
        Allocation: Record "ESV PP Allocation";
    begin
        Allocation.SetRange("Plan ID", Plan.ID);
        Allocation.SetFilter("Document Type", '<>%1', Allocation."Document Type"::"Credit Memo");
        if Allocation.Count() <> 1 then
            exit;
        Allocation.FindFirst();
        if Allocation.Amount > Plan."Payment Amount" then begin
            Allocation.Amount := Plan."Payment Amount";
            Allocation.Modify(true);
        end;
    end;

    procedure Approve(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
        BankLine: Record "Bank Acc. Reconciliation Line";
        Allocation: Record "ESV PP Allocation";
        Fresh: Record "ESV PP Allocation";
        Currency: Record Currency;
        CashAmount: Decimal;
        CreditAmount: Decimal;
    begin

        Allocation.ReadIsolation(IsolationLevel::UpdLock);
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Draft);
        Currency.Initialize(Plan."Currency Code");
        BankLine.GetBySystemId(Plan.ID);
        CheckSnapshot(Plan, BankLine);
        Allocation.SetRange("Plan ID", Plan.ID);
        if not Allocation.FindSet() then
            Error(NoReferencesErr);
        repeat
            if Allocation.Amount < 0 then
                Error(NegativeErr);
            if Allocation.Amount <> Round(Allocation.Amount, Currency."Amount Rounding Precision") then
                Error(PrecisionErr, Allocation."Document No.");
            Fresh := Allocation;
            ResolveDocument(Fresh);
            if (Fresh."Target Entry No." <> Allocation."Target Entry No.") or
               (Fresh."Order SystemId" <> Allocation."Order SystemId") then
                Error(DocumentChangedErr, Allocation."Document No.");
            if Allocation.Amount > Fresh."Open Amount" then
                Error(AmountExceededErr, Allocation."Document No.", Fresh."Open Amount");
            if Allocation."Document Type" = Allocation."Document Type"::"Credit Memo" then
                ValidateCredit(Allocation)
            else begin
                CashAmount += Allocation.Amount;
                if Allocation."Document Type" = Allocation."Document Type"::Invoice then begin
                    CreditAmount := GetCreditsForInvoice(Plan.ID, Allocation."Document No.");
                    if Allocation.Amount + CreditAmount > Fresh."Open Amount" then
                        Error(AmountExceededErr, Allocation."Document No.", Fresh."Open Amount" - CreditAmount);
                end;
            end;
        until Allocation.Next() = 0;
        if CashAmount > Plan."Payment Amount" then
            Error(PaymentExceededErr, CashAmount, Plan."Payment Amount");
        // Rejecting native suggestions clears Account No.; CheckSnapshot already validated it.
        BankLine.RejectAppliedPayment();
        BankLine.GetBySystemId(Plan.ID);
        Plan.Status := Plan.Status::Approved;
        Plan."Approved By" := CopyStr(UserId(), 1, MaxStrLen(Plan."Approved By"));
        Plan."Approved At" := CurrentDateTime();
        Plan.Modify();
        // Replace native suggestions only after an explicit approval of this plan.
        BankLine.Validate("Account Type", BankLine."Account Type"::Customer);
        BankLine.Validate("Account No.", Plan."Customer No.");
        BankLine.Modify(true);
        BankLine.TransferRemainingAmountToAccount();
        BankLine.GetBySystemId(Plan.ID);
        BankLine.AcceptApplication();
    end;

    procedure Reopen(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
        BankLine: Record "Bank Acc. Reconciliation Line";
    begin
        Plan.Get(PlanID);
        Plan.TestField(Status, Plan.Status::Approved);
        Plan.TestField("Payment Entry No.", 0);
        Plan.Status := Plan.Status::Draft;
        Clear(Plan."Approved At");
        Clear(Plan."Approved By");
        Plan.Modify();
        if BankLine.GetBySystemId(Plan.ID) then begin
            BankLine.RejectAppliedPayment();
            BankLine.GetBySystemId(Plan.ID);
            BankLine.Validate("Account Type", BankLine."Account Type"::Customer);
            BankLine.Validate("Account No.", Plan."Customer No.");
            BankLine.Modify(true);
        end;
    end;

    procedure ClearUnpostedPlan(PlanID: Guid)
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        Plan.ReadIsolation(IsolationLevel::UpdLock);
        if not Plan.Get(PlanID) then
            exit;
        Plan.TestField("Payment Entry No.", 0);
        if not (Plan.Status in [Plan.Status::Draft, Plan.Status::Approved]) then
            Error(UnpostedPlanErr);
        Plan.Status := Plan.Status::Draft;
        Plan.Modify();
        Plan.Delete(true);
    end;

    procedure RemoveAllocation(var BankLine: Record "Bank Acc. Reconciliation Line")
    begin
        CheckIncomingLine(BankLine);
        ClearUnpostedPlan(BankLine.SystemId);
        BankLine.RejectAppliedPayment();
        BankLine.GetBySystemId(BankLine.SystemId);
    end;

    procedure CheckReady(Plan: Record "ESV PP Payment Plan"; BankLine: Record "Bank Acc. Reconciliation Line")
    var
        AppliedEntry: Record "Applied Payment Entry";
    begin
        Plan.TestField(Status, Plan.Status::Approved);
        CheckSnapshot(Plan, BankLine);
        AppliedEntry.FilterAppliedPmtEntry(BankLine);
        if not AppliedEntry.FindSet() then
            Error(NativeApplicationErr);
        repeat
            AppliedEntry.TestField("Account Type", AppliedEntry."Account Type"::Customer);
            AppliedEntry.TestField("Account No.", Plan."Customer No.");
            AppliedEntry.TestField("Applies-to Entry No.", 0);
            AppliedEntry.TestField("Applied Pmt. Discount", 0);
        until AppliedEntry.Next() = 0;
    end;

    procedure GetPaymentText(BankLine: Record "Bank Acc. Reconciliation Line"): Text
    begin
        exit(BankLine."Transaction Text" + ' ' + BankLine."Additional Transaction Info" + ' ' + BankLine."Payment Reference No.");
    end;

    procedure OrderAvailable(SalesHeader: Record "Sales Header"; ExcludePlanID: Guid): Decimal
    var
        SalesLine: Record "Sales Line";
        Reserved: Record "ESV PP Allocation";
        Plan: Record "ESV PP Payment Plan";
        LegacyPayment: Record "Cust. Ledger Entry";
        Currency: Record Currency;
        Available: Decimal;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                if SalesLine.Quantity <> 0 then begin
                    if SalesLine."Prepmt. Amt. Inv." <> 0 then
                        Error(PrepaymentOrderErr, SalesHeader."No.");
                    Available += SalesLine."Amount Including VAT" *
                        (SalesLine.Quantity - SalesLine."Quantity Invoiced") / SalesLine.Quantity;
                end;
            until SalesLine.Next() = 0;
        Reserved.SetRange("Document Type", Reserved."Document Type"::Order);
        Reserved.SetRange("Document No.", SalesHeader."No.");
        Reserved.SetRange("Customer No.", SalesHeader."Bill-to Customer No.");
        Reserved.SetRange("Currency Code", SalesHeader."Currency Code");
        if Reserved.FindSet() then
            repeat
                if (Reserved."Plan ID" <> ExcludePlanID) and Plan.Get(Reserved."Plan ID") then
                    if Plan.Status in [Plan.Status::Approved, Plan.Status::Posted] then
                        Available -= Reserved.Amount - Reserved."Applied Amount";
            until Reserved.Next() = 0;
        LegacyPayment.SetRange("Customer No.", SalesHeader."Bill-to Customer No.");
        LegacyPayment.SetRange("Sales Order No.", SalesHeader."No.");
        LegacyPayment.SetRange("Currency Code", SalesHeader."Currency Code");
        LegacyPayment.SetRange(Open, true);
        LegacyPayment.SetRange(Reversed, false);
        if LegacyPayment.FindSet() then
            repeat
                LegacyPayment.CalcFields("Remaining Amount");
                if LegacyPayment."Remaining Amount" < 0 then
                    Available += LegacyPayment."Remaining Amount";
            until LegacyPayment.Next() = 0;
        Currency.Initialize(SalesHeader."Currency Code");
        exit(Maximum(0, Round(Available, Currency."Amount Rounding Precision")));
    end;

    procedure GetOrderReceived(OrderNo: Code[20]; CustomerNo: Code[20]; CurrencyCode: Code[10]): Decimal
    var
        Allocation: Record "ESV PP Allocation";
        Plan: Record "ESV PP Payment Plan";
        Payment: Record "Cust. Ledger Entry";
        ApplyEntries: Codeunit "ESV PP Apply Entries";
        Total: Decimal;
    begin
        Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
        Allocation.SetRange("Document No.", OrderNo);
        Allocation.SetRange("Customer No.", CustomerNo);
        Allocation.SetRange("Currency Code", CurrencyCode);
        if Allocation.FindSet() then
            repeat
                if Plan.Get(Allocation."Plan ID") then
                    if Plan.Status = Plan.Status::Posted then begin
                        ApplyEntries.CheckIntegrity(Plan.ID);
                        Payment.Get(Plan."Payment Entry No.");
                        Payment.TestField(Reversed, false);
                        Total += Allocation.Amount;
                    end;
            until Allocation.Next() = 0;
        exit(Total);
    end;

    local procedure CheckBankLine(BankLine: Record "Bank Acc. Reconciliation Line")
    begin
        CheckIncomingLine(BankLine);
        BankLine.TestField("Account Type", BankLine."Account Type"::Customer);
        BankLine.TestField("Account No.");
    end;

    local procedure CheckIncomingLine(BankLine: Record "Bank Acc. Reconciliation Line")
    begin
        BankLine.TestField("Statement Type", BankLine."Statement Type"::"Payment Application");
        BankLine.TestField("Transaction Date");
        if BankLine."Statement Amount" <= 0 then
            Error(IncomingOnlyErr);
        if BankLine.IsTransactionPostedAndReconciled() then
            Error(PostedErr);
    end;

    local procedure IdentifyCustomer(var BankLine: Record "Bank Acc. Reconciliation Line"; References: List of [Text])
    var
        SalesHeader: Record "Sales Header";
        Entry: Record "Cust. Ledger Entry";
        Customer: Record Customer;
        AppliedEntry: Record "Applied Payment Entry";
        Reference: Text;
        CustomerNo: Code[20];
    begin
        // Resolve orders first, independently of generic private-customer bank matching.
        foreach Reference in References do
            if CopyStr(Reference, 1, 2) = 'MT' then begin
                if not SalesHeader.Get(SalesHeader."Document Type"::Order, Reference) then
                    Error(DocumentMissingErr, Reference);
                SalesHeader.TestField("Bill-to Customer No.");
                SalesHeader.TestField("Currency Code", BankLine.GetCurrencyCode());
                CheckSameCustomer(CustomerNo, SalesHeader."Bill-to Customer No.");
            end;
        foreach Reference in References do
            if CopyStr(Reference, 1, 2) in ['MA', 'KR', 'KK'] then begin
                Entry.Reset();
                Entry.SetRange("Document No.", Reference);
                Entry.SetRange("Currency Code", BankLine.GetCurrencyCode());
                Entry.SetRange(Open, true);
                Entry.SetRange(Reversed, false);
                if CopyStr(Reference, 1, 2) = 'MA' then
                    Entry.SetRange("Document Type", Entry."Document Type"::Invoice)
                else
                    Entry.SetRange("Document Type", Entry."Document Type"::"Credit Memo");
                if CustomerNo <> '' then
                    Entry.SetRange("Customer No.", CustomerNo)
                else

                    if Entry.Count() > 1 then
                        if (BankLine."Account Type" = BankLine."Account Type"::Customer) and (BankLine."Account No." <> '') then
                            Entry.SetRange("Customer No.", BankLine."Account No.");
                if Entry.Count() <> 1 then
                    Error(DocumentMissingErr, Reference);
                Entry.FindFirst();
                CheckSameCustomer(CustomerNo, Entry."Customer No.");
            end;
        if CustomerNo = '' then
            Error(NoReferencesErr);
        Customer.Get(CustomerNo);

        AppliedEntry.FilterAppliedPmtEntry(BankLine);
        if not AppliedEntry.IsEmpty() then begin
            BankLine.TestField("Account Type", BankLine."Account Type"::Customer);
            BankLine.TestField("Account No.", CustomerNo);
        end;
        if (BankLine."Account Type" <> BankLine."Account Type"::Customer) or (BankLine."Account No." <> CustomerNo) then begin
            BankLine.Validate("Account Type", BankLine."Account Type"::Customer);
            BankLine.Validate("Account No.", CustomerNo);
            BankLine.Modify(true);
        end;
    end;

    local procedure CheckSameCustomer(var CustomerNo: Code[20]; DocumentCustomerNo: Code[20])
    begin
        if (CustomerNo <> '') and (CustomerNo <> DocumentCustomerNo) then
            Error(MixedCustomersErr);
        CustomerNo := DocumentCustomerNo;
    end;

    procedure GetDocumentReferences(PlanID: Guid): Text
    var
        Allocation: Record "ESV PP Allocation";
        References: Text;
    begin
        Allocation.SetRange("Plan ID", PlanID);
        if Allocation.FindSet() then
            repeat
                if References <> '' then
                    References += ', ';
                References += Allocation."Document No.";
            until Allocation.Next() = 0;
        exit(References);
    end;

    procedure GetSingleOrderNo(PlanID: Guid): Code[20]
    var
        Allocation: Record "ESV PP Allocation";
    begin
        Allocation.SetRange("Plan ID", PlanID);
        Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
        if Allocation.Count() = 1 then begin
            Allocation.FindFirst();
            exit(Allocation."Document No.");
        end;
    end;

    local procedure CheckSnapshot(Plan: Record "ESV PP Payment Plan"; BankLine: Record "Bank Acc. Reconciliation Line")
    begin
        CheckBankLine(BankLine);
        if (Plan."Customer No." <> BankLine."Account No.") or
           (Plan."Currency Code" <> BankLine.GetCurrencyCode()) or
           (Plan."Payment Amount" <> BankLine."Statement Amount") or
           (Plan."Payment Date" <> BankLine."Transaction Date") or
           (Plan."Payment Text" <> GetPaymentText(BankLine)) or
           (Plan."Transaction ID" <> BankLine."Transaction ID") then
            Error(SourceChangedErr);
    end;

    local procedure CheckDuplicateTransaction(BankLine: Record "Bank Acc. Reconciliation Line")
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        if BankLine."Transaction ID" = '' then
            exit;
        Plan.SetRange("Bank Account No.", BankLine."Bank Account No.");
        Plan.SetRange("Transaction ID", BankLine."Transaction ID");
        Plan.SetFilter(ID, '<>%1', BankLine.SystemId);
        if not Plan.IsEmpty() then
            Error(DuplicateTransactionErr, BankLine."Transaction ID");
    end;

    local procedure ResolveDocument(var Allocation: Record "ESV PP Allocation")
    var
        SalesHeader: Record "Sales Header";
        Entry: Record "Cust. Ledger Entry";
    begin
        case CopyStr(Allocation."Document No.", 1, 2) of
            'MT':
                begin
                    Allocation."Document Type" := Allocation."Document Type"::Order;
                    SalesHeader.ReadIsolation(IsolationLevel::UpdLock);
                    if not SalesHeader.Get(SalesHeader."Document Type"::Order, Allocation."Document No.") then
                        Error(DocumentMissingErr, Allocation."Document No.");
                    SalesHeader.TestField("Bill-to Customer No.", Allocation."Customer No.");
                    SalesHeader.TestField("Currency Code", Allocation."Currency Code");
                    Allocation."Order SystemId" := SalesHeader.SystemId;
                    Allocation."Order Created At" := SalesHeader.SystemCreatedAt;
                    Allocation."Open Amount" := OrderAvailable(SalesHeader, Allocation."Plan ID");
                end;
            'MA', 'KR', 'KK':
                begin
                    Entry.ReadIsolation(IsolationLevel::UpdLock);
                    Entry.SetRange("Customer No.", Allocation."Customer No.");
                    Entry.SetRange("Document No.", Allocation."Document No.");
                    Entry.SetRange("Currency Code", Allocation."Currency Code");
                    Entry.SetRange(Open, true);
                    Entry.SetRange(Reversed, false);
                    if CopyStr(Allocation."Document No.", 1, 2) = 'MA' then begin
                        Allocation."Document Type" := Allocation."Document Type"::Invoice;
                        Entry.SetRange("Document Type", Entry."Document Type"::Invoice);
                    end else begin
                        Allocation."Document Type" := Allocation."Document Type"::"Credit Memo";
                        Entry.SetRange("Document Type", Entry."Document Type"::"Credit Memo");
                    end;
                    if Entry.Count() <> 1 then
                        Error(DocumentMissingErr, Allocation."Document No.");
                    Entry.FindFirst();
                    Entry.CalcFields("Remaining Amount");
                    if ((Allocation."Document Type" = Allocation."Document Type"::Invoice) and (Entry."Remaining Amount" <= 0)) or
                       ((Allocation."Document Type" = Allocation."Document Type"::"Credit Memo") and (Entry."Remaining Amount" >= 0)) then
                        Error(SignErr, Allocation."Document No.");
                    Allocation."Target Entry No." := Entry."Entry No.";
                    Allocation."Open Amount" := Maximum(0, Abs(Entry."Remaining Amount") - GetReservedEntryAmount(Allocation, Entry."Entry No."));
                end;
        end;
    end;

    local procedure ProposeCreditTargets(PlanID: Guid)
    var
        Credit: Record "ESV PP Allocation";
        Invoice: Record "ESV PP Allocation";
        CreditHeader: Record "Sales Cr.Memo Header";
    begin
        Credit.SetRange("Plan ID", PlanID);
        Credit.SetRange("Document Type", Credit."Document Type"::"Credit Memo");
        if Credit.FindSet() then
            repeat
                Invoice.SetRange("Plan ID", PlanID);
                Invoice.SetRange("Document Type", Invoice."Document Type"::Invoice);
                if CreditHeader.Get(Credit."Document No.") then
                    if CreditHeader."Applies-to Doc. Type" = CreditHeader."Applies-to Doc. Type"::Invoice then
                        Invoice.SetRange("Document No.", CreditHeader."Applies-to Doc. No.");
                if Invoice.Count() = 1 then begin
                    Invoice.FindFirst();
                    Credit."Credit Target Invoice No." := Invoice."Document No.";
                    Credit.Modify(true);
                end;
                Invoice.Reset();
            until Credit.Next() = 0;
    end;

    local procedure ValidateCredit(Credit: Record "ESV PP Allocation")
    var
        Invoice: Record "ESV PP Allocation";
        Entry: Record "Cust. Ledger Entry";
    begin
        if Credit.Amount = 0 then
            exit;
        Credit.TestField("Credit Target Invoice No.");
        Invoice.SetRange("Plan ID", Credit."Plan ID");
        Invoice.SetRange("Document Type", Invoice."Document Type"::Invoice);
        Invoice.SetRange("Document No.", Credit."Credit Target Invoice No.");
        if not Invoice.FindFirst() then
            Error(CreditTargetErr, Credit."Document No.");
        Entry.Get(Invoice."Target Entry No.");
        Entry.CalcFields("Remaining Amount");
        if GetCreditsForInvoice(Credit."Plan ID", Invoice."Document No.") > Entry."Remaining Amount" then
            Error(AmountExceededErr, Credit."Document No.", Entry."Remaining Amount");
    end;

    local procedure GetCreditsForInvoice(PlanID: Guid; InvoiceNo: Code[20]): Decimal
    var
        Credit: Record "ESV PP Allocation";
    begin
        Credit.SetRange("Plan ID", PlanID);
        Credit.SetRange("Document Type", Credit."Document Type"::"Credit Memo");
        Credit.SetRange("Credit Target Invoice No.", InvoiceNo);
        Credit.CalcSums(Amount);
        exit(Credit.Amount);
    end;

    local procedure Maximum(First: Decimal; Second: Decimal): Decimal
    begin
        if First > Second then
            exit(First);
        exit(Second);
    end;

    local procedure GetReservedEntryAmount(CurrentAllocation: Record "ESV PP Allocation"; EntryNo: Integer): Decimal
    var
        Other: Record "ESV PP Allocation";
        Plan: Record "ESV PP Payment Plan";
        Reserved: Decimal;
    begin
        Other.SetRange("Customer No.", CurrentAllocation."Customer No.");
        Other.SetRange("Currency Code", CurrentAllocation."Currency Code");
        if Other.FindSet() then
            repeat
                if (Other."Plan ID" <> CurrentAllocation."Plan ID") and Plan.Get(Other."Plan ID") then
                    if Plan.Status in [Plan.Status::Approved, Plan.Status::Posted] then
                        if (Other."Target Entry No." = EntryNo) or
                           ((CurrentAllocation."Document Type" = CurrentAllocation."Document Type"::Invoice) and
                            (Other."Document Type" = Other."Document Type"::"Credit Memo") and
                            (Other."Credit Target Invoice No." = CurrentAllocation."Document No.")) then
                            Reserved += Other.Amount - Other."Applied Amount";
            until Other.Next() = 0;
        exit(Reserved);
    end;

    var
        MixedCustomersErr: Label 'The referenced documents belong to different billing customers. Review the payment manually.';
        UnpostedPlanErr: Label 'Only unposted draft or approved plans can be removed from the payment journal.';
        SameDocumentTypeErr: Label 'Select a document of the same type as the current allocation row: %1.', Comment = '%1 - allocation document type';
        FullDocumentNoErr: Label 'Enter one complete document number with its MT, MA or KK prefix.';
        DuplicateDocumentErr: Label 'Document %1 already exists in this payment allocation plan.', Comment = '%1 - document number';
        NoReferencesErr: Label 'No MT, MA, KR or KK document references were found.';
        NegativeErr: Label 'Allocation amounts cannot be negative.';
        DocumentChangedErr: Label 'The target of reference %1 has changed. Detect references again.', Comment = '%1 - document reference';
        AmountExceededErr: Label 'The allocation for %1 exceeds the currently available amount %2.', Comment = '%1 - document reference, %2 - available amount';
        PaymentExceededErr: Label 'Allocated cash %1 exceeds the payment amount %2. Enter the intended partial amounts.', Comment = '%1 - total cash allocated, %2 - bank payment amount';
        NativeApplicationErr: Label 'The standard on-account payment application is missing. Reopen and approve the plan again.';
        IncomingOnlyErr: Label 'This feature supports incoming customer payments with a positive statement amount.';
        PostedErr: Label 'This bank transaction has already been posted.';
        SourceChangedErr: Label 'The bank line has changed. Reopen the plan and detect the references again.';
        DuplicateTransactionErr: Label 'Bank transaction %1 already has another allocation plan.', Comment = '%1 - bank transaction identifier';
        DocumentMissingErr: Label 'Reference %1 does not identify exactly one eligible document for this customer and currency.', Comment = '%1 - document reference';
        SignErr: Label 'Document %1 has an unexpected remaining amount sign.', Comment = '%1 - document number';
        CreditTargetErr: Label 'Select an invoice referenced in this payment as the target for credit memo %1.', Comment = '%1 - credit memo number';
        PrecisionErr: Label 'The allocation for %1 does not match the currency rounding precision.', Comment = '%1 - document reference';
        PrepaymentOrderErr: Label 'Order %1 already uses posted standard prepayment invoices. Apply its payment to the posted prepayment invoice instead.', Comment = '%1 - sales order number';
}
