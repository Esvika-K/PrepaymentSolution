namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;

codeunit 60109 "ESV PP Approve Line"
{
    TableNo = "Bank Acc. Reconciliation Line";
    trigger OnRun()
    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        Mgt.Approve(Rec.SystemId);
    end;
}
