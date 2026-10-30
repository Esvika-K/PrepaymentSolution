namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Document;

pageextension 60101 "ESV PP Sales Order" extends "Sales Order"
{
    layout
    {
        addlast(General)
        {
            field(ESVPPReceived; ReceivedAmount)
            {
                Caption = 'Allocated Bank Receipts';
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Bank receipts allocated to this exact order and billing customer through payment allocation plans. This excludes legacy cash and card receipts.';
                trigger OnDrillDown()
                var
                    Allocation: Record "ESV PP Allocation";
                begin
                    Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
                    Allocation.SetRange("Document No.", Rec."No.");
                    Allocation.SetRange("Customer No.", Rec."Bill-to Customer No.");
                    Allocation.SetRange("Currency Code", Rec."Currency Code");
                    Page.RunModal(Page::"ESV PP Order Allocations", Allocation);
                end;
            }
        }
    }
    trigger OnAfterGetCurrRecord()
    var
        Mgt: Codeunit "ESV PP Allocation Mgt.";
    begin
        ReceivedAmount := Mgt.GetOrderReceived(Rec."No.", Rec."Bill-to Customer No.", Rec."Currency Code");
    end;
    var
        ReceivedAmount: Decimal;
}
