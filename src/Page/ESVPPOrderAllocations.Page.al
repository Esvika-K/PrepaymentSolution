namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Document;

page 60104 "ESV PP Order Allocations"
{
    CaptionML = ENU = 'Order Payment Allocations', ETI = 'Makse jaotused tellimusele';
    PageType = List;
    SourceTable = "ESV PP Allocation";
    ApplicationArea = All;
    Editable = false;
    layout
    {
        area(Content)
        {
            repeater(Allocations)
            {
                field(DocumentNo; Rec."Document No.") { ApplicationArea = All; ToolTip = 'Specifies the exact document reference found in the payment text.'; }
                field(Customer; Rec."Customer No.") { ApplicationArea = All; ToolTip = 'Specifies the billing customer whose documents can receive this payment.'; }
                field(Amount; Rec.Amount) { ApplicationArea = All; ToolTip = 'Specifies the amount allocated on this row, in the document currency.'; }
                field(Applied; Rec."Applied Amount") { ApplicationArea = All; ToolTip = 'Specifies the allocated amount already applied to posted invoices.'; }
                field(PaymentEntry; Rec."Payment Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the posted customer payment entry funding this allocation.'; }
            }
        }
    }
}
