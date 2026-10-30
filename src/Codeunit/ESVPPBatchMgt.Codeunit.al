namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;

codeunit 60108 "ESV PP Batch Mgt."
{
    procedure DetectUnmatched(CurrentLine: Record "Bank Acc. Reconciliation Line")
    begin
        ProcessLines(CurrentLine, false);
    end;

    procedure ApproveDrafts(CurrentLine: Record "Bank Acc. Reconciliation Line")
    begin
        ProcessLines(CurrentLine, true);
    end;

    local procedure ProcessLines(CurrentLine: Record "Bank Acc. Reconciliation Line"; ApproveExistingDrafts: Boolean)
    var
        BankLine: Record "Bank Acc. Reconciliation Line";
        AppliedEntry: Record "Applied Payment Entry";
        Plan: Record "ESV PP Payment Plan";
        TempResult: Record "ESV PP Detection Result" temporary;
        DetectLine: Codeunit "ESV PP Detect Line";
        ApproveLine: Codeunit "ESV PP Approve Line";
        Results: Page "ESV PP Detection Results";
        ResultNo: Integer;
        SuccessCount: Integer;
        Eligible: Boolean;
        Success: Boolean;
    begin
        CurrentLine.TestField("Statement Type", CurrentLine."Statement Type"::"Payment Application");
        BankLine.SetRange("Statement Type", CurrentLine."Statement Type");
        BankLine.SetRange("Bank Account No.", CurrentLine."Bank Account No.");
        BankLine.SetRange("Statement No.", CurrentLine."Statement No.");
        BankLine.SetFilter("Statement Amount", '>0');
        if BankLine.FindSet() then
            repeat
                AppliedEntry.FilterAppliedPmtEntry(BankLine);
                Eligible := false;
                if ApproveExistingDrafts then begin
                    if Plan.Get(BankLine.SystemId) then
                        Eligible := (Plan.Status = Plan.Status::Draft) and (Plan."Payment Entry No." = 0);
                end else
                    Eligible := AppliedEntry.IsEmpty() and not Plan.Get(BankLine.SystemId);
                if Eligible and not BankLine.IsTransactionPostedAndReconciled() then begin
                    ResultNo += 1;
                    TempResult.Init();
                    TempResult."Entry No." := ResultNo;
                    TempResult."Statement Line No." := BankLine."Statement Line No.";
                    TempResult."Payment Text" := BankLine."Transaction Text";
                    TempResult."Plan ID" := BankLine.SystemId;
                    ClearLastError();
                    // Boolean Run isolates each line: one bad reference must not undo successful lines.
                    // A successful Run commits one detection/approval only; it never posts a payment.
                    if ApproveExistingDrafts then
                        Success := ApproveLine.Run(BankLine)
                    else
                        Success := DetectLine.Run(BankLine);
                    if Success then begin
                        SuccessCount += 1;
                        TempResult.Success := true;
                        if ApproveExistingDrafts then
                            TempResult.Message := ApprovedTxt
                        else
                            TempResult.Message := DetectedTxt;
                    end else
                        TempResult.Message := CopyStr(GetLastErrorText(), 1, MaxStrLen(TempResult.Message));
                    Clear(DetectLine);
                    Clear(ApproveLine);
                    TempResult.Insert();
                end;
            until BankLine.Next() = 0;
        if ResultNo = 0 then begin
            if ApproveExistingDrafts then
                Message(NoDraftsTxt)
            else
                Message(NoLinesTxt);
            exit;
        end;
        Results.SetResults(TempResult);
        Results.RunModal();
        Message(SummaryTxt, SuccessCount, ResultNo - SuccessCount);
    end;

    var
        DetectedTxt: Label 'Draft created. Review the customer, documents and amounts before approval.';
        ApprovedTxt: Label 'Allocation approved. The payment has not been posted.';
        NoLinesTxt: Label 'There are no incoming unmatched lines without an allocation plan in this statement.';
        NoDraftsTxt: Label 'There are no unposted draft allocation plans in this statement.';
        SummaryTxt: Label 'Lines processed: %1. Lines requiring review: %2.', Comment = '%1 - successfully processed lines, %2 - failed lines';
}
