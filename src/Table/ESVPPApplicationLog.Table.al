namespace Esvika.PrepaymentSolution;

table 60102 "ESV PP Application Log"
{
    Caption = 'Payment Application Log';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Entry No."; Integer) { CaptionML = ENU = 'Entry No.', ETI = 'Kande nr'; AutoIncrement = true; }
        field(2; "Plan ID"; Guid) { CaptionML = ENU = 'Plan ID', ETI = 'Plaani ID'; }
        field(3; "Allocation Line No."; Integer) { CaptionML = ENU = 'Allocation Line No.', ETI = 'Määramise rea nr'; }
        field(4; "Credit Entry No."; Integer) { CaptionML = ENU = 'Credit Entry No.', ETI = 'Kreedit kande nr'; }
        field(5; "Invoice Entry No."; Integer) { CaptionML = ENU = 'Invoice Entry No.', ETI = 'Arve kande nr'; }
        field(6; Amount; Decimal) { CaptionML = ENU = 'Amount', ETI = 'Summa'; }
        field(7; "Detailed Entry No."; Integer) { CaptionML = ENU = 'Detailed Entry No.', ETI = 'Üksikasjaliku kande nr'; }
        field(8; "Applied At"; DateTime) { CaptionML = ENU = 'Applied At', ETI = 'Seotud'; }
    }
    keys { key(PK; "Entry No.") { Clustered = true; } key(Plan; "Plan ID", "Allocation Line No.") { } }
}
