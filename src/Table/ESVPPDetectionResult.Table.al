namespace Esvika.PrepaymentSolution;

table 60103 "ESV PP Detection Result"
{
    Caption = 'Payment Detection Result';
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Entry No."; Integer) { CaptionML = ENU = 'Entry No.', ETI = 'Kande nr'; }
        field(2; "Statement Line No."; Integer) { CaptionML = ENU = 'Statement Line No.', ETI = 'Väljavõtte rea nr'; }
        field(3; "Payment Text"; Text[140]) { CaptionML = ENU = 'Payment Text', ETI = 'Makse tekst'; }
        field(4; Success; Boolean) { CaptionML = ENU = 'Processed', ETI = 'Töödeldud'; }
        field(5; Message; Text[2048]) { CaptionML = ENU = 'Result', ETI = 'Tulemus'; }
        field(6; "Plan ID"; Guid) { CaptionML = ENU = 'Plan ID', ETI = 'Plaani ID'; }
    }
    keys { key(PK; "Entry No.") { Clustered = true; } }
}
