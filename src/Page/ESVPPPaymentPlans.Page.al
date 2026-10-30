namespace Esvika.PrepaymentSolution;

page 60100 "ESV PP Payment Plans"
{
    CaptionML = ENU = 'Payment Allocation Plans', ETI = 'Makse jaotamise plaan';
    PageType = List;
    SourceTable = "ESV PP Payment Plan";
    CardPageId = "ESV PP Payment Plan";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            repeater(Plans)
            {
                field(BankAccount; Rec."Bank Account No.") { ApplicationArea = All; ToolTip = 'Specifies the bank account of the original bank transaction.'; }
                field(Statement; Rec."Statement No.") { ApplicationArea = All; ToolTip = 'Specifies the source bank statement number.'; }
                field(LineNo; Rec."Statement Line No.") { ApplicationArea = All; ToolTip = 'Specifies the source bank statement line number.'; }
                field(Customer; Rec."Customer No.") { ApplicationArea = All; ToolTip = 'Specifies the billing customer whose documents can receive this payment.'; }
                field(PaymentDate; Rec."Payment Date") { ApplicationArea = All; ToolTip = 'Specifies the transaction date supplied by the bank.'; }
                field(PaymentAmount; Rec."Payment Amount") { ApplicationArea = All; ToolTip = 'Specifies the total incoming bank payment, including any unallocated cash.'; }
                field(Currency; Rec."Currency Code") { ApplicationArea = All; ToolTip = 'Specifies the currency shared by the bank payment and target documents.'; }
                field(Status; Rec.Status) { ApplicationArea = All; ToolTip = 'Specifies whether the allocation is a draft, approved, or posted with the bank payment.'; }
                field(PaymentEntry; Rec."Payment Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the posted customer payment entry funding this allocation.'; }
            }
        }
    }
}
