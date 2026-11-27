param([Parameter(Mandatory=$true)][string]$Path, [switch]$Install)
$ErrorActionPreference = 'Stop'
$acl = Get-Acl -LiteralPath $Path -Audit
if ($Install) {
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [System.Security.AccessControl.FileSystemAuditRule]::new($sid, 'WriteData', 'Success')
    $acl.AddAuditRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
    $acl = Get-Acl -LiteralPath $Path -Audit
    if (-not ($acl.GetAuditRules($true, $false, $sid.GetType()) | Where-Object IdentityReference -eq $sid)) {
        throw 'Explicit audit rule missing from the disposable fixture'
    }
}
$acl.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Audit)
