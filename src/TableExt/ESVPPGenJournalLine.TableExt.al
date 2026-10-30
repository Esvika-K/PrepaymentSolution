namespace Esvika.PrepaymentSolution;

using Microsoft.Finance.GeneralLedger.Journal;

tableextension 60100 "ESV PP Gen. Journal Line" extends "Gen. Journal Line"
{
    fields
    {
        field(60100; "ESV PP Plan ID"; Guid)
        {
            Caption = 'Payment Allocation Plan ID';
            DataClassification = CustomerContent;
        }
    }
}
