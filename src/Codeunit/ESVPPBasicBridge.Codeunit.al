namespace Esvika.PrepaymentSolution;

using Esvika.Esvika;
using Microsoft.Sales.Document;
using Microsoft.Sales.Receivables;

codeunit 60105 "ESV PP Basic Bridge"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Events", 'OnAfterCalcReceivedAmount', '', false, false)]
    local procedure IncludeBankAllocations(var SalesHeader: Record "Sales Header")
    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then
            SalesHeader."Recived Amount" += Mgt.GetOrderReceived(SalesHeader."No.", SalesHeader."Bill-to Customer No.", SalesHeader."Currency Code");
    end;

    [EventSubscriber(ObjectType::Page, Page::"Cust. Ledger Entry Payment", 'OnAfterSetOrderPaymentFilters', '', false, false)]
    local procedure IncludeAllocatedPayments(var CustomerEntry: Record "Cust. Ledger Entry"; OrderNo: Code[20])
    var
        Order: Record "Sales Header";
        Allocation: Record "ESV PP Allocation";
        Plan: Record "ESV PP Payment Plan";
        PlanFilter: Text;
    begin
        if not Order.Get(Order."Document Type"::Order, OrderNo) then
            exit;
        CustomerEntry.SetRange("Customer No.", Order."Bill-to Customer No.");
        CustomerEntry.SetRange("Currency Code", Order."Currency Code");
        Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
        Allocation.SetRange("Document No.", OrderNo);
        Allocation.SetRange("Customer No.", Order."Bill-to Customer No.");
        Allocation.SetRange("Currency Code", Order."Currency Code");
        if Allocation.FindSet() then
            repeat
                if Plan.Get(Allocation."Plan ID") then
                    if Plan.Status = Plan.Status::Posted then begin
                        if PlanFilter <> '' then
                            PlanFilter += '|';
                        PlanFilter += Format(Plan.ID);
                    end;
            until Allocation.Next() = 0;
        if PlanFilter = '' then
            exit;
        CustomerEntry.SetRange("Sales Order No.");
        CustomerEntry.FilterGroup(-1);
        CustomerEntry.SetRange("Sales Order No.", OrderNo);
        CustomerEntry.SetFilter("ESV PP Plan ID", PlanFilter);
        CustomerEntry.FilterGroup(0);
    end;
}
