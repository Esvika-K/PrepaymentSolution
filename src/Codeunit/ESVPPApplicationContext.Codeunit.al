namespace Esvika.PrepaymentSolution;

using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Sales.Receivables;

codeunit 60106 "ESV PP Application Context"
{
    EventSubscriberInstance = Manual;

    procedure SetAllocation(Allocation: Record "ESV PP Allocation")
    begin
        CurrentAllocation := Allocation;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeInsertDtldCustLedgEntry', '', false, false)]
    local procedure SetApplicationReference(var DtldCustLedgEntry: Record "Detailed Cust. Ledg. Entry")
    begin
        if IsNullGuid(CurrentAllocation."Plan ID") or
           (DtldCustLedgEntry."Entry Type" <> DtldCustLedgEntry."Entry Type"::Application) then
            exit;
        DtldCustLedgEntry."ESV PP Plan ID" := CurrentAllocation."Plan ID";
        DtldCustLedgEntry."ESV PP Document References" := CurrentAllocation."Document No.";
        if CurrentAllocation."Document Type" = CurrentAllocation."Document Type"::Order then
            DtldCustLedgEntry."Sales Order No." := CurrentAllocation."Document No.";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnBeforeCustPostApplyCustLedgEntry', '', false, false)]
    local procedure HideProgress(var HideProgressWindow: Boolean)
    begin
        HideProgressWindow := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnCustPostApplyCustLedgEntryOnBeforeCommit', '', false, false)]
    local procedure SuppressApplicationCommit(var SuppressCommit: Boolean)
    begin
        SuppressCommit := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnApplyOnBeforePmtTolCust', '', false, false)]
    local procedure ExactAmountsOnly(var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnBeforeRunUpdateAnalysisView', '', false, false)]
    local procedure DeferAnalysisViewUpdate(var IsHandled: Boolean)
    begin
        // The outer bank/sales posting updates analysis views after its own commit.
        IsHandled := true;
    end;

    var
        CurrentAllocation: Record "ESV PP Allocation";
}
