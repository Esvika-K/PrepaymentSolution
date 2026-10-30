namespace Esvika.PrepaymentSolution;

page 60107 "ESV PP Add Document"
{
    CaptionML = ENU = 'Add Document', ETI = 'Lisa dokument';
    PageType = StandardDialog;
    layout
    {
        area(Content)
        {
            group(Document)
            {
                CaptionML = ENU = 'Document', ETI = 'Dokument';
                field(DocumentNumber; DocumentNo)
                {
                    CaptionML = ENU = 'Document No.', ETI = 'Dokumendi nr';
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Enter the complete document number, for example MT0055018. Only a document for the same billing customer and currency can be added.';
                }
            }
        }
    }
    procedure GetDocumentNo(): Code[20]
    begin
        exit(DocumentNo);
    end;

    var
        DocumentNo: Code[20];
}
