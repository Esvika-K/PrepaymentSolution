namespace Esvika.PrepaymentSolution;

using Microsoft.Sales.Receivables;

tableextension 60101 "ESV PP Customer Entry" extends "Cust. Ledger Entry"
{
    fields
    {
        field(60100; "ESV PP Plan ID"; Guid)
        {
            Caption = 'Payment Allocation Plan ID';
            DataClassification = CustomerContent;
        }
        field(60101; "ESV PP Reserved"; Boolean)
        {
            Caption = 'Reserved for Payment Allocation';
            DataClassification = CustomerContent;
        }
    }
}
