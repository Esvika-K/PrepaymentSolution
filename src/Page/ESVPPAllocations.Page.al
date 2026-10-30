namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;

page 60102 "ESV PP Allocations"
{
    CaptionML = ENU = 'Payment Allocations', ETI = 'Makse jaotused';
    PageType = ListPart;
    SourceTable = "ESV PP Allocation";
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = true;
    layout
    {
        area(Content)
        {
            repeater(Allocations)
            {
                field(DocumentType; Rec."Document Type") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies whether the reference identifies an order, invoice or credit memo.'; }
                field(DocumentNo; Rec."Document No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the exact document reference. Open the referenced document to verify the payment allocation.';
                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                        Invoice: Record "Sales Invoice Header";
                        Credit: Record "Sales Cr.Memo Header";
                    begin
                        case Rec."Document Type" of
                            Rec."Document Type"::Order:
                                begin
                                    SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Document No.");
                                    Page.RunModal(Page::"Sales Order", SalesHeader);
                                end;
                            Rec."Document Type"::Invoice:
                                begin
                                    Invoice.Get(Rec."Document No.");
                                    Page.RunModal(Page::"Posted Sales Invoice", Invoice);
                                end;
                            Rec."Document Type"::"Credit Memo":
                                begin
                                    Credit.Get(Rec."Document No.");
                                    Page.RunModal(Page::"Posted Sales Credit Memo", Credit);
                                end;
                        end;
                    end;
                }
                field(ManuallyAdded; Rec."Manually Added")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies that the document was added manually. It is retained when references are detected again.';
                }
                field(Customer; Rec."Customer No.") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies the billing customer whose documents can receive this payment.'; }
                field(OpenAmount; Rec."Open Amount") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies the available amount found when the document was last detected or recalculated.'; }
                field(Amount; Rec.Amount) { ApplicationArea = All; Editable = IsDraft; ToolTip = 'Specifies the amount allocated on this row, in the document currency.'; }
                field(CreditTarget; Rec."Credit Target Invoice No.") { ApplicationArea = All; Editable = IsDraft; ToolTip = 'Specifies which invoice referenced in this payment receives the credit memo.'; }
                field(AppliedAmount; Rec."Applied Amount") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies the amount already applied through standard customer ledger entry applications.'; }
                field(PaymentEntry; Rec."Payment Entry No.") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies the posted customer payment entry funding this allocation.'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(AddDocument)
            {
                CaptionML = ENU = 'Add Document', ETI = 'Lisa dokument';
                ApplicationArea = All;
                Image = NewDocument;
                Enabled = IsDraft;
                ToolTip = 'Select another document of the current row type from a list filtered by billing customer and currency. Existing plan documents are excluded.';
                trigger OnAction()
                var
                    Plan: Record "ESV PP Payment Plan";
                    Mgt: Codeunit "ESV PP Allocation Mgt.";
                    DocumentNo: Code[20];
                begin
                    Plan.Get(Rec."Plan ID");
                    Plan.TestField(Status, Plan.Status::Draft);
                    case Rec."Document Type" of
                        Rec."Document Type"::Order:
                            DocumentNo := SelectOrder(Plan);
                        Rec."Document Type"::Invoice:
                            DocumentNo := SelectInvoice(Plan);
                        Rec."Document Type"::"Credit Memo":
                            DocumentNo := SelectCreditMemo(Plan);
                    end;
                    if DocumentNo = '' then
                        exit;
                    CurrPage.SaveRecord();
                    Mgt.AddDocumentFromLine(Plan.ID, Rec."Line No.", DocumentNo);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    local procedure SelectOrder(Plan: Record "ESV PP Payment Plan"): Code[20]
    var
        SalesHeader: Record "Sales Header";
        OrderList: Page "Sales Order List";
        DocumentFilter: Text;
    begin
        SalesHeader.FilterGroup(2);
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("Bill-to Customer No.", Plan."Customer No.");
        SalesHeader.SetRange("Currency Code", Plan."Currency Code");
        SalesHeader.SetFilter("No.", 'MT*');
        SalesHeader.FilterGroup(0);
        if SalesHeader.FindSet() then
            repeat
                if not IsAlreadyAllocated(Plan.ID, SalesHeader."No.") then
                    AppendDocumentFilter(DocumentFilter, SalesHeader."No.");
            until SalesHeader.Next() = 0;
        if DocumentFilter = '' then begin
            Message(NoDocumentsTxt);
            exit;
        end;
        SalesHeader.FilterGroup(2);
        SalesHeader.SetFilter("No.", DocumentFilter);
        SalesHeader.FilterGroup(0);
        OrderList.SetTableView(SalesHeader);
        OrderList.LookupMode(true);
        if OrderList.RunModal() = Action::LookupOK then begin
            OrderList.GetRecord(SalesHeader);
            exit(SalesHeader."No.");
        end;
    end;

    local procedure SelectInvoice(Plan: Record "ESV PP Payment Plan"): Code[20]
    var
        Invoice: Record "Sales Invoice Header";
        InvoiceList: Page "Posted Sales Invoices";
        DocumentFilter: Text;
    begin
        Invoice.FilterGroup(2);
        Invoice.SetRange("Bill-to Customer No.", Plan."Customer No.");
        Invoice.SetRange("Currency Code", Plan."Currency Code");
        Invoice.SetFilter("No.", 'MA*');
        Invoice.FilterGroup(0);
        if Invoice.FindSet() then
            repeat
                if not IsAlreadyAllocated(Plan.ID, Invoice."No.") and
                   HasOpenCustomerEntry(Plan, Invoice."No.", false) then
                    AppendDocumentFilter(DocumentFilter, Invoice."No.");
            until Invoice.Next() = 0;
        if DocumentFilter = '' then begin
            Message(NoDocumentsTxt);
            exit;
        end;
        Invoice.FilterGroup(2);
        Invoice.SetFilter("No.", DocumentFilter);
        Invoice.FilterGroup(0);
        InvoiceList.SetTableView(Invoice);
        InvoiceList.LookupMode(true);
        if InvoiceList.RunModal() = Action::LookupOK then begin
            InvoiceList.GetRecord(Invoice);
            exit(Invoice."No.");
        end;
    end;

    local procedure SelectCreditMemo(Plan: Record "ESV PP Payment Plan"): Code[20]
    var
        CreditMemo: Record "Sales Cr.Memo Header";
        CreditMemoList: Page "Posted Sales Credit Memos";
        DocumentFilter: Text;
    begin
        CreditMemo.FilterGroup(2);
        CreditMemo.SetRange("Bill-to Customer No.", Plan."Customer No.");
        CreditMemo.SetRange("Currency Code", Plan."Currency Code");
        CreditMemo.SetFilter("No.", 'KK*|KR*');
        CreditMemo.FilterGroup(0);
        if CreditMemo.FindSet() then
            repeat
                if not IsAlreadyAllocated(Plan.ID, CreditMemo."No.") and
                   HasOpenCustomerEntry(Plan, CreditMemo."No.", true) then
                    AppendDocumentFilter(DocumentFilter, CreditMemo."No.");
            until CreditMemo.Next() = 0;
        if DocumentFilter = '' then begin
            Message(NoDocumentsTxt);
            exit;
        end;
        CreditMemo.FilterGroup(2);
        CreditMemo.SetFilter("No.", DocumentFilter);
        CreditMemo.FilterGroup(0);
        CreditMemoList.SetTableView(CreditMemo);
        CreditMemoList.LookupMode(true);
        if CreditMemoList.RunModal() = Action::LookupOK then begin
            CreditMemoList.GetRecord(CreditMemo);
            exit(CreditMemo."No.");
        end;
    end;

    local procedure AppendDocumentFilter(var DocumentFilter: Text; CandidateNo: Code[20])
    var
        Quote: Char;
        DocumentText: Text;
    begin
        Quote := 39;
        DocumentText := CandidateNo;
        if DocumentFilter <> '' then
            DocumentFilter += '|';
        DocumentFilter += Format(Quote) + DocumentText.Replace(Format(Quote), Format(Quote) + Format(Quote)) + Format(Quote);
    end;

    local procedure IsAlreadyAllocated(PlanID: Guid; CandidateNo: Code[20]): Boolean
    var
        Allocation: Record "ESV PP Allocation";
    begin
        Allocation.SetRange("Plan ID", PlanID);
        Allocation.SetRange("Document No.", CandidateNo);
        exit(not Allocation.IsEmpty());
    end;

    local procedure HasOpenCustomerEntry(Plan: Record "ESV PP Payment Plan"; CandidateNo: Code[20]; IsCreditMemo: Boolean): Boolean
    var
        Entry: Record "Cust. Ledger Entry";
    begin
        Entry.SetRange("Customer No.", Plan."Customer No.");
        Entry.SetRange("Currency Code", Plan."Currency Code");
        Entry.SetRange("Document No.", CandidateNo);
        Entry.SetRange(Open, true);
        Entry.SetRange(Reversed, false);
        if IsCreditMemo then
            Entry.SetRange("Document Type", Entry."Document Type"::"Credit Memo")
        else
            Entry.SetRange("Document Type", Entry."Document Type"::Invoice);
        if Entry.Count() <> 1 then
            exit(false);
        Entry.FindFirst();
        Entry.CalcFields("Remaining Amount");
        if IsCreditMemo then
            exit(Entry."Remaining Amount" < 0);
        exit(Entry."Remaining Amount" > 0);
    end;

    trigger OnAfterGetRecord()
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        Plan.Get(Rec."Plan ID");
        IsDraft := Plan.Status = Plan.Status::Draft;
    end;

    var
        IsDraft: Boolean;
        NoDocumentsTxt: Label 'There are no additional eligible documents of this type for the payment customer and currency.';
}
