namespace Esvika.PrepaymentSolution;

page 60103 "ESV PP Application Log"
{
    CaptionML = ENU = 'Payment Application Log', ETI = 'Makse rakendamise logi';
    PageType = List;
    SourceTable = "ESV PP Application Log";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    layout
    {
        area(Content)
        {
            repeater(History)
            {
                field(EntryNo; Rec."Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the unique application history entry number.'; }
                field(Plan; Rec."Plan ID") { ApplicationArea = All; ToolTip = 'Specifies the source payment allocation plan.'; }
                field(AllocationLine; Rec."Allocation Line No.") { ApplicationArea = All; ToolTip = 'Specifies the allocation row that caused this application.'; }
                field(CreditEntry; Rec."Credit Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the customer payment or credit memo entry applied to the invoice.'; }
                field(InvoiceEntry; Rec."Invoice Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the customer invoice entry that received the application.'; }
                field(Amount; Rec.Amount) { ApplicationArea = All; ToolTip = 'Specifies the amount allocated on this row, in the document currency.'; }
                field(AppliedAt; Rec."Applied At") { ApplicationArea = All; ToolTip = 'Specifies when this standard customer ledger application was recorded.'; }
            }
        }
    }
}
