namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;

pageextension 60100 "ESV PP Payment Journal" extends "Payment Reconciliation Journal"
{
    layout
    {
        addafter("Transaction Text")
        {
            field(ESVPPDocuments; DocumentReferences)
            {
                CaptionML = ENU = 'Allocation Documents', ETI = 'Jaotuse dokumendid';
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies all MT, MA, KR and KK references in this payment allocation. Open the plan to inspect each document.';
                trigger OnDrillDown()
                begin
                    OpenAllocation();
                end;
            }
            field(ESVPPStatus; PlanStatusText)
            {
                CaptionML = ENU = 'Allocation Status', ETI = 'Jaotuse staatus';
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the current plan status. A blank value means that there is no allocation plan.';
            }
            field(ESVPPAllocated; AllocatedAmount)
            {
                CaptionML = ENU = 'Allocated Cash', ETI = 'Jaotatud summa';
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the cash proposed or approved for the displayed documents.';
            }
        }
    }
    actions
    {
        modify(Reject)
        {
            trigger OnAfterAction()
            var
                SelectedLine: Record "Bank Acc. Reconciliation Line";
                AppliedEntry: Record "Applied Payment Entry";
                Mgt: Codeunit "ESV PP Allocation Mgt.";
            begin
                CurrPage.SetSelectionFilter(SelectedLine);
                if SelectedLine.FindSet() then
                    repeat
                        AppliedEntry.FilterAppliedPmtEntry(SelectedLine);
                        if AppliedEntry.IsEmpty() then
                            Mgt.ClearUnpostedPlan(SelectedLine.SystemId);
                    until SelectedLine.Next() = 0;
                CurrPage.Update(false);
            end;
        }
        addlast(Processing)
        {
            action(ESVPPDetectUnmatched)
            {
                CaptionML = ENU = 'Detect All Unmatched Payments', ETI = 'Tuvasta kõik MT/MA/KK sidumata maksed';
                ApplicationArea = All;
                Image = Find;
                ToolTip = 'Find the customer from exact document references and create draft plans for all unmatched incoming lines in this statement. Review failures in the results.';
                trigger OnAction()
                var
                    BatchMgt: Codeunit "ESV PP Batch Mgt.";
                begin
                    BatchMgt.DetectUnmatched(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ESVPPRemoveAllocation)
            {
                CaptionML = ENU = 'Remove Selected Allocations', ETI = 'Eemalda valitud jaotused';
                ApplicationArea = All;
                Image = Reject;
                ToolTip = 'Remove unposted plans and standard applications for the selected payments. Posted applications retain their history.';
                trigger OnAction()
                var
                    SelectedLine: Record "Bank Acc. Reconciliation Line";
                    Mgt: Codeunit "ESV PP Allocation Mgt.";
                begin
                    CurrPage.SetSelectionFilter(SelectedLine);
                    if SelectedLine.FindSet() then
                        repeat
                            Mgt.RemoveAllocation(SelectedLine);
                        until SelectedLine.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(ESVPPApproveAllDrafts)
            {
                CaptionML = ENU = 'Approve All Draft Allocations', ETI = 'Kinnita kõik mustandid';
                ApplicationArea = All;
                Image = Approve;
                ToolTip = 'Validate and approve all draft plans in this statement. Failed plans remain drafts and are listed for review. Payments are not posted.';
                trigger OnAction()
                var
                    BatchMgt: Codeunit "ESV PP Batch Mgt.";
                begin
                    BatchMgt.ApproveDrafts(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ESVPPDetectSelected)
            {
                CaptionML = ENU = 'Detect MT/MA/KR/KK References', ETI = 'Tuvasta valitud MT/MA/KK sidumata maksed';
                ApplicationArea = All;
                Image = Find;
                ToolTip = 'Create draft allocation plans for selected incoming payments. Identify the customer from exact order, invoice and credit memo references.';
                trigger OnAction()
                var
                    SelectedLine: Record "Bank Acc. Reconciliation Line";
                    Mgt: Codeunit "ESV PP Allocation Mgt.";
                begin
                    CurrPage.SetSelectionFilter(SelectedLine);
                    if SelectedLine.FindSet() then
                        repeat
                            Mgt.Detect(SelectedLine);
                        until SelectedLine.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(ESVPPOpenPlan)
            {
                CaptionML = ENU = 'Payment Allocation', ETI = 'Makse jaotamine';
                ApplicationArea = All;
                Image = Allocations;
                ToolTip = 'Review references, adjust partial amounts, select credit targets and approve the payment allocation.';
                trigger OnAction()
                var
                    Plan: Record "ESV PP Payment Plan";
                begin
                    Plan.Get(Rec.SystemId);
                    Page.RunModal(Page::"ESV PP Payment Plan", Plan);
                    CurrPage.Update(false);
                end;
            }
            action(ESVPPApproveSelected)
            {
                CaptionML = ENU = 'Approve Selected Allocations', ETI = 'Kinnita valitud jaotused';
                ApplicationArea = All;
                Image = Approve;
                ToolTip = 'Validate and approve all selected allocation plans. Any ambiguous or excessive allocation stops the transaction.';
                trigger OnAction()
                var
                    SelectedLine: Record "Bank Acc. Reconciliation Line";
                    Mgt: Codeunit "ESV PP Allocation Mgt.";
                begin
                    CurrPage.SetSelectionFilter(SelectedLine);
                    if SelectedLine.FindSet() then
                        repeat
                            Mgt.Approve(SelectedLine.SystemId);
                        until SelectedLine.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
        }
    }
    trigger OnAfterGetRecord()
    var
        Plan: Record "ESV PP Payment Plan";
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        Clear(DocumentReferences);
        Clear(PlanStatusText);
        Clear(AllocatedAmount);
        if Plan.Get(Rec.SystemId) then begin
            DocumentReferences := Mgt.GetDocumentReferences(Plan.ID);
            PlanStatusText := Format(Plan.Status);
            Plan.CalcFields("Cash Allocated");
            AllocatedAmount := Plan."Cash Allocated";
        end;
    end;

    local procedure OpenAllocation()
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        if Plan.Get(Rec.SystemId) then
            Page.RunModal(Page::"ESV PP Payment Plan", Plan);
        CurrPage.Update(false);
    end;

    var
        DocumentReferences: Text;
        PlanStatusText: Text;
        AllocatedAmount: Decimal;
}
