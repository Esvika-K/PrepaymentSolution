namespace Esvika.PrepaymentSolution;

using Microsoft.Bank.BankAccount;
using Microsoft.Sales.Customer;

table 60100 "ESV PP Payment Plan"
{
    Caption = 'Payment Allocation Plan';
    DataClassification = CustomerContent;
    LookupPageId = "ESV PP Payment Plans";
    DrillDownPageId = "ESV PP Payment Plans";
    fields
    {
        field(1; ID; Guid) { Caption = 'ID'; }
        field(2; "Bank Account No."; Code[20]) { CaptionML = ENU = 'Bank Account No.', ETI = 'Panga konto nr'; TableRelation = "Bank Account"; }
        field(3; "Statement No."; Code[20]) { CaptionML = ENU = 'Statement No.', ETI = 'Väljavõtte nr'; }
        field(4; "Statement Line No."; Integer) { CaptionML = ENU = 'Statement Line No.', ETI = 'Väljavõtte rea nr'; }
        field(5; "Customer No."; Code[20]) { CaptionML = ENU = 'Customer No.', ETI = 'Kliendi nr'; TableRelation = Customer; }
        field(6; "Currency Code"; Code[10]) { CaptionML = ENU = 'Currency Code', ETI = 'Valuuta kood'; }
        field(7; "Payment Date"; Date) { CaptionML = ENU = 'Payment Date', ETI = 'Makse kuupäev'; }
        field(8; "Payment Amount"; Decimal) { CaptionML = ENU = 'Payment Amount', ETI = 'Makse summa'; }
        field(9; "Payment Text"; Text[2048]) { CaptionML = ENU = 'Payment Text', ETI = 'Makse tekst'; }
        field(10; Status; Enum "ESV PP Status") { CaptionML = ENU = 'Status', ETI = 'Staatus'; }
        field(11; "Payment Entry No."; Integer) { CaptionML = ENU = 'Payment Entry No.', ETI = 'Makse kande nr'; }
        field(12; "Approved By"; Code[50]) { CaptionML = ENU = 'Approved By', ETI = 'Kinnitas'; }
        field(13; "Approved At"; DateTime) { CaptionML = ENU = 'Approved At', ETI = 'Kinnitatud'; }
        field(14; "Cash Allocated"; Decimal)
        {
            CaptionML = ENU = 'Cash Allocated', ETI = 'Määratud sularaha';
            FieldClass = FlowField;
            CalcFormula = sum("ESV PP Allocation".Amount where("Plan ID" = field(ID), "Document Type" = filter(<> "Credit Memo")));
            Editable = false;
        }
        field(15; "Transaction ID"; Text[50]) { CaptionML = ENU = 'Bank Transaction ID', ETI = 'Panga tehingu ID'; }
    }
    keys { key(PK; ID) { Clustered = true; } key(Payment; "Payment Entry No.") { } }
    trigger OnDelete()
    var
        Allocation: Record "ESV PP Allocation";
    begin
        TestField(Status, Status::Draft);
        TestField("Payment Entry No.", 0);
        Allocation.SetRange("Plan ID", ID);
        Allocation.DeleteAll(true);
    end;
}
