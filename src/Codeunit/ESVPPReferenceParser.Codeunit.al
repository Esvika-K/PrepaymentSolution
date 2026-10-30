namespace Esvika.PrepaymentSolution;

codeunit 60100 "ESV PP Reference Parser"
{
    procedure Parse(PaymentText: Text; var References: List of [Text])
    var
        Token: Text;
        Position: Integer;
        Character: Text[1];
    begin
        Clear(References);
        PaymentText := UpperCase(PaymentText);
        for Position := 1 to StrLen(PaymentText) do begin
            Character := CopyStr(PaymentText, Position, 1);
            if (Character = '/') and
               (CopyStr(PaymentText, Position + 1, 2) in ['MT', 'MA', 'KR', 'KK']) then begin
                AddToken(Token, References);
                Clear(Token);
            end else
            if StrPos('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-/_', Character) > 0 then
                Token += Character
            else begin
                AddToken(Token, References);
                Clear(Token);
            end;
        end;
        AddToken(Token, References);
    end;

    local procedure AddToken(Token: Text; var References: List of [Text])
    var
        Position: Integer;
        HasDigit: Boolean;
    begin
        if StrLen(Token) < 3 then
            exit;
        if not (CopyStr(Token, 1, 2) in ['MT', 'MA', 'KR', 'KK']) then
            exit;
        if StrPos('0123456789-/_', CopyStr(Token, 3, 1)) = 0 then
            exit;
        for Position := 3 to StrLen(Token) do
            HasDigit := HasDigit or (StrPos('0123456789', CopyStr(Token, Position, 1)) > 0);
        if not HasDigit then
            exit;
        if StrLen(Token) > 20 then
            Error(LongReferenceErr, Token);
        if not References.Contains(Token) then
            References.Add(Token);
    end;

    var
        LongReferenceErr: Label 'Document reference %1 exceeds 20 characters.', Comment = '%1 - document reference';
}
