namespace Esvika.PrepaymentSolution;

using System.Threading;

codeunit 60104 "ESV PP Background"
{
    TableNo = "Job Queue Entry";
    trigger OnRun()
    var
        Plan: Record "ESV PP Payment Plan";
        Allocation: Record "ESV PP Allocation";
        PostingMgt: Codeunit "ESV PP Posting Mgt.";
        PlanIDs: List of [Guid];
        PlanID: Guid;
    begin
        Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
        Allocation.SetFilter("Payment Entry No.", '<>0');
        if Allocation.FindSet() then
            repeat
                if Allocation.Amount > Allocation."Applied Amount" then
                    if Plan.Get(Allocation."Plan ID") then
                        if (Plan.Status = Plan.Status::Posted) and not PlanIDs.Contains(Plan.ID) then
                            PlanIDs.Add(Plan.ID);
            until Allocation.Next() = 0;
        foreach PlanID in PlanIDs do
            PostingMgt.ProcessPlan(PlanID);
    end;
}
