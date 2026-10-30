namespace Esvika.PrepaymentSolution;

enum 60100 "ESV PP Document Type"
{
    Extensible = false;
    value(0; Order) { CaptionML = ENU = 'Sales Order', ETI = 'Müügitellimus'; }
    value(1; Invoice) { CaptionML = ENU = 'Sales Invoice', ETI = 'Müügiarve'; }
    value(2; "Credit Memo") { CaptionML = ENU = 'Sales Credit Memo', ETI = 'Müügi kreeditarve'; }
}
