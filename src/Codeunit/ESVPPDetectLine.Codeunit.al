namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.Reconciliation;

codeunit 60107 "ESV PP Detect Line"
{
    TableNo = "Bank Acc. Reconciliation Line";
    trigger OnRun()
    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        Mgt.Detect(Rec);
    end;
}
