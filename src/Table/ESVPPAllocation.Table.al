namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.History;

table 60101 "ESV PP Allocation"
{
    CaptionML = ENU = 'Payment Allocation', ETI = 'Makse jaotamine';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Plan ID"; Guid) { Caption = 'Plan ID'; TableRelation = "ESV PP Payment Plan".ID; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; }
        field(3; "Document Type"; Enum "ESV PP Document Type") { Caption = 'Document Type'; }
        field(4; "Document No."; Code[20]) { CaptionML = ENU = 'Document No.', ETI = 'Dokumendi nr'; }
        field(5; "Customer No."; Code[20]) { CaptionML = ENU = 'Customer No.', ETI = 'Kliendi nr'; }
        field(6; "Currency Code"; Code[10]) { CaptionML = ENU = 'Currency Code', ETI = 'Valuuta kood'; }
        field(7; "Target Entry No."; Integer) { CaptionML = ENU = 'Target Entry No.', ETI = 'Sihtkande nr'; }
        field(8; "Order SystemId"; Guid) { CaptionML = ENU = 'Order SystemId', ETI = 'Tellimuse süsteemi ID'; }
        field(9; "Open Amount"; Decimal) { CaptionML = ENU = 'Open Amount at Detection', ETI = 'Avatud summa tuvastamisel'; }
        field(10; Amount; Decimal)
        {
            CaptionML = ENU = 'Allocated Amount', ETI = 'Määratud summa';
            MinValue = 0;
            trigger OnValidate()
            begin
                CheckDraft();
            end;
        }
        field(11; "Applied Amount"; Decimal) { CaptionML = ENU = 'Applied Amount', ETI = 'Seotud summa'; }
        field(12; "Credit Target Invoice No."; Code[20])
        {
            CaptionML = ENU = 'Credit Target Invoice No.', ETI = 'Kreeditarve nr';
            TableRelation = "Sales Invoice Header"."No." where("Bill-to Customer No." = field("Customer No."));
            trigger OnValidate()
            begin
                CheckDraft();
                TestField("Document Type", "Document Type"::"Credit Memo");
            end;
        }
        field(13; "Payment Entry No."; Integer) { CaptionML = ENU = 'Payment Entry No.', ETI = 'Makse kande nr'; }
        field(14; "Order Created At"; DateTime) { CaptionML = ENU = 'Order Created At', ETI = 'Tellimus loodud'; }
        field(15; "Manually Added"; Boolean)
        {
            CaptionML = ENU = 'Manually Added', ETI = 'Käsitsi lisatud';
            Editable = false;
        }
    }
    keys
    {
        key(PK; "Plan ID", "Line No.") { Clustered = true; }
        key(Document; "Document Type", "Document No.", "Customer No.", "Currency Code") { }
        key(Payment; "Payment Entry No.") { }
        key(PlanTotals; "Plan ID", "Document Type") { SumIndexFields = Amount, "Applied Amount"; }
    }
    trigger OnModify()
    begin
        CheckDraft();
    end;

    trigger OnDelete()
    begin
        CheckDraft();
    end;

    local procedure CheckDraft()
    var
        Plan: Record "ESV PP Payment Plan";
    begin
        Plan.Get("Plan ID");
        Plan.TestField(Status, Plan.Status::Draft);
    end;
}
