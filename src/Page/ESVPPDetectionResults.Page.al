namespace Esvika.PrepaymentSolution;

page 60105 "ESV PP Detection Results"
{
    CaptionML = ENU = 'Payment Detection Results', ETI = 'Makse tuvastamise tulemused';
    PageType = List;
    SourceTable = "ESV PP Detection Result";
    Editable = false;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field(LineNo; Rec."Statement Line No.") { ApplicationArea = All; ToolTip = 'Specifies the source bank statement line.'; }
                field(PaymentText; Rec."Payment Text") { ApplicationArea = All; ToolTip = 'Specifies the payment text supplied by the bank.'; }
                field(Success; Rec.Success) { ApplicationArea = All; ToolTip = 'Specifies whether detection or approval completed successfully.'; }
                field(Result; Rec.Message) { ApplicationArea = All; ToolTip = 'Specifies the outcome or the error requiring manual review.'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(OpenPlan)
            {
                Caption = 'Payment Allocation';
                ApplicationArea = All;
                Image = Allocations;
                ToolTip = 'Open the allocation plan for this payment.';
                trigger OnAction()
                var
                    Plan: Record "ESV PP Payment Plan";
                begin
                    if Plan.Get(Rec."Plan ID") then
                        Page.RunModal(Page::"ESV PP Payment Plan", Plan);
                end;
            }
        }
    }
    procedure SetResults(var TempResult: Record "ESV PP Detection Result" temporary)
    begin
        Rec.Copy(TempResult, true);
    end;
}
