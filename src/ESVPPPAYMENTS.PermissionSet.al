namespace Esvika.PrepaymentSolution;

using System.IO;

permissionset 60100 "ESV PP PAYMENTS"
{
    Assignable = true;
    Caption = 'Payment Allocations';
    Permissions =
        page "ESV PP Add Document" = X,
        tabledata "Data Exch." = R,
        tabledata "ESV PP Payment Plan" = RIMD,
        tabledata "ESV PP Allocation" = RIMD,
        tabledata "ESV PP Application Log" = RI,
        table "ESV PP Detection Result" = X,
        table "ESV PP Payment Plan" = X,
        table "ESV PP Allocation" = X,
        table "ESV PP Application Log" = X,
        codeunit "ESV PP Detect Line" = X,
        codeunit "ESV PP Approve Line" = X,
        codeunit "ESV PP Batch Mgt." = X,
        codeunit "ESV PP Reference Parser" = X,
        codeunit "ESV PP Allocation Mgt." = X,
        codeunit "ESV PP Apply Entries" = X,
        codeunit "ESV PP Posting Mgt." = X,
        codeunit "ESV PP Background" = X,
        codeunit "ESV PP Basic Bridge" = X,
        codeunit "ESV PP Application Context" = X,
        page "ESV PP Detection Results" = X,
        page "ESV PP Payment Plans" = X,
        page "ESV PP Payment Plan" = X,
        page "ESV PP Allocations" = X,
        page "ESV PP Application Log" = X,
        page "ESV PP Order Allocations" = X;
}
