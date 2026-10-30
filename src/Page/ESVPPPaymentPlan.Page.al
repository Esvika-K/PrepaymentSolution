namespace Esvika.PrepaymentSolution;

page 60101 "ESV PP Payment Plan"
{
    CaptionML = ENU = 'Payment Allocation Plan', ETI = 'Makse jaotamise plaan';
    PageType = Card;
    SourceTable = "ESV PP Payment Plan";
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            group(General)
            {
                Editable = false;
                field(Customer; Rec."Customer No.") { ApplicationArea = All; ToolTip = 'Specifies the billing customer whose documents can receive this payment.'; }
                field(PaymentDate; Rec."Payment Date") { ApplicationArea = All; ToolTip = 'Specifies the transaction date supplied by the bank.'; }
                field(PaymentAmount; Rec."Payment Amount") { ApplicationArea = All; ToolTip = 'Specifies the total incoming bank payment, including any unallocated cash.'; }
                field(Currency; Rec."Currency Code") { ApplicationArea = All; ToolTip = 'Specifies the currency shared by the bank payment and target documents.'; }
                field(Status; Rec.Status) { ApplicationArea = All; ToolTip = 'Specifies whether the allocation is a draft, approved, or posted with the bank payment.'; }
                field(PaymentText; Rec."Payment Text") { ApplicationArea = All; MultiLine = true; ToolTip = 'Specifies the bank text used to identify MT, MA, KR and KK document references.'; }
                field(Allocated; Rec."Cash Allocated") { ApplicationArea = All; ToolTip = 'Specifies the cash allocated to orders and invoices. Credit memo allocations are excluded.'; }
                field(Unallocated; UnallocatedAmount) { CaptionML = ENU = 'Unallocated Cash', ETI = 'Jaotamata summa'; ApplicationArea = All; ToolTip = 'Specifies the amount that remains as an unallocated customer credit after posting.'; }
                field(PaymentEntry; Rec."Payment Entry No.") { ApplicationArea = All; ToolTip = 'Specifies the posted customer payment entry funding this allocation.'; }
            }
            part(Allocations; "ESV PP Allocations")
            {
                ApplicationArea = All;
                SubPageLink = "Plan ID" = field(ID);
                UpdatePropagation = Both;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Recalculate)
            {
                CaptionML = ENU = 'Recalculate Suggested Amounts', ETI = 'Arvuta soovitatud summad';
                ApplicationArea = All;
                Image = Calculate;
                ToolTip = 'Replace draft amounts with current document balances, less referenced credits. Review partial allocations before approval.';
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Mgt.Recalculate(Rec.ID);
                    CurrPage.Update(false);
                end;
            }
            action(Approve)
            {
                CaptionML = ENU = 'Approve Allocation', ETI = 'Kinnita jaotamine';
                ApplicationArea = All;
                Image = Approve;
                ToolTip = 'Confirm this allocation and replace the bank line application with an on-account receipt. Documents are applied when the payment is posted.';
                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Mgt.Approve(Rec.ID);
                    CurrPage.Update(false);
                end;
            }
            action(Reopen)
            {
                CaptionML = ENU = 'Reopen', ETI = 'Ava uuesti';
                ApplicationArea = All;
                Image = ReOpen;
                ToolTip = 'Reopen an approved plan before its payment has been posted.';
                trigger OnAction()
                begin
                    Mgt.Reopen(Rec.ID);
                    CurrPage.Update(false);
                end;
            }
            action(History)
            {
                CaptionML = ENU = 'Application History', ETI = 'Rakenduse ajalugu';
                ApplicationArea = All;
                Image = History;
                ToolTip = 'Review the posted standard applications created by this plan.';
                RunObject = page "ESV PP Application Log";
                RunPageLink = "Plan ID" = field(ID);
            }
            action(CancelPostedAllocation)
            {
                CaptionML = ENU = 'Cancel Posted Allocation', ETI = 'Tühista postitatud jaotamine';
                ApplicationArea = All;
                Image = Cancel;
                ToolTip = 'Release reservations after all applications made by this plan have been unapplied using standard Business Central actions. This does not refund or reverse the payment.';
                trigger OnAction()
                var
                    ApplyEntries: Codeunit "ESV PP Apply Entries";
                begin
                    if not Confirm(CancelPlanQst, false) then
                        exit;
                    ApplyEntries.CancelPlan(Rec.ID);
                    CurrPage.Update(false);
                end;
            }
        }
    }
    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields("Cash Allocated");
        UnallocatedAmount := Rec."Payment Amount" - Rec."Cash Allocated";
    end;

    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
        UnallocatedAmount: Decimal;
        CancelPlanQst: Label 'Cancel this allocation plan and release its remaining payment reservations? This does not refund the payment.';
}
