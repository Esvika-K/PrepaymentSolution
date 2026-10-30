namespace Esvika.PrepaymentSolution;

enum 60101 "ESV PP Status"
{
    Extensible = false;
    value(0; Draft) { CaptionML = ENU = 'Draft', ETI = 'Mustand'; }
    value(1; Approved) { CaptionML = ENU = 'Approved', ETI = 'Kinnitatud'; }
    value(2; Posted) { CaptionML = ENU = 'Posted', ETI = 'Konteeritud'; }
    value(3; Cancelled) { CaptionML = ENU = 'Cancelled', ETI = 'Tühistatud'; }
}
