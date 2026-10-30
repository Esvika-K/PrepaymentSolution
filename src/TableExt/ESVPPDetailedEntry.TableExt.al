namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Receivables;

tableextension 60102 "ESV PP Detailed Entry" extends "Detailed Cust. Ledg. Entry"
{
    fields
    {
        field(60100; "ESV PP Plan ID"; Guid)
        {
            Caption = 'Payment Allocation Plan ID';
            DataClassification = CustomerContent;
            TableRelation = "ESV PP Payment Plan".ID;
        }

        field(60102; "ESV PP Document References"; Text[2048])
        {
            Caption = 'Allocation Documents';
            DataClassification = CustomerContent;
        }
    }
}
