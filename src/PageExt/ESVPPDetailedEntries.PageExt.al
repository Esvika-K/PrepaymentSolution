namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Receivables;

pageextension 60102 "ESV PP Detailed Entries" extends "Detailed Cust. Ledg. Entries"
{
    layout
    {
        addafter("Document No.")
        {
            field(ESVPPOrderNo; Rec."Sales Order No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the sales order funded by this application. Initial payments covering multiple orders show all references in Allocation Documents.';
            }
            field(ESVPPReferences; Rec."ESV PP Document References")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the documents funded by this payment or application. Open the plan to inspect each allocation.';
                trigger OnDrillDown()
                var
                    Plan: Record "ESV PP Payment Plan";
                begin
                    if Plan.Get(Rec."ESV PP Plan ID") then
                        Page.RunModal(Page::"ESV PP Payment Plan", Plan);
                end;
            }
            field(ESVPPPlanID; Rec."ESV PP Plan ID")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the allocation plan that created this entry.';
            }
        }
    }
}
