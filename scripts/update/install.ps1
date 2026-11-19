param([Parameter(Mandatory)][string]$GameExe, [Parameter(Mandatory)][int]$GamePid)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$gameDir = Split-Path -LiteralPath $GameExe
$changed = @()
$finished = $false
try {
    $owner = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
    if ($owner -and !$owner.WaitForExit(30000)) { throw 'Game is still running.' }
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $PSScriptRoot 'update.zip'))
    $stage = Join-Path $gameDir ('.update-' + [guid]::NewGuid())
    [void][IO.Directory]::CreateDirectory($stage)
    try {
        foreach ($name in 'Cascadia.exe','Cascadia.pck') {
            $entry = $archive.GetEntry($name)
            if (!$entry -or !$entry.Length) { throw "Missing $name" }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $stage $name))
        }
    } finally { $archive.Dispose() }
    foreach ($name in 'Cascadia.exe','Cascadia.pck') {
        $target = [IO.Path]::ChangeExtension($GameExe,[IO.Path]::GetExtension($name))
        $backup = Join-Path $stage ($name + '.bak')
        [IO.File]::Replace((Join-Path $stage $name),$target,$backup)
        $changed += @{Target=$target; Backup=$backup}
    }
    Start-Process -FilePath $GameExe -WorkingDirectory $gameDir
    $finished = $true
} catch {
    $reason = $_.Exception.Message
    try {
        foreach ($file in $changed) { [IO.File]::Copy($file.Backup,$file.Target,$true) }
        $finished = $true
    } catch { $reason += " Backup: $stage" }
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($reason,'Cascadia update failed')
} finally {
    if ($finished -and $stage -and (Test-Path -LiteralPath $stage)) {
        foreach ($name in 'Cascadia.exe','Cascadia.pck','Cascadia.exe.bak','Cascadia.pck.bak') {
            [IO.File]::Delete((Join-Path $stage $name))
        }
        [IO.Directory]::Delete($stage)
    }
    [IO.File]::Delete((Join-Path $PSScriptRoot 'update.zip'))
    [IO.File]::Delete($PSCommandPath)
    [IO.Directory]::Delete($PSScriptRoot)
}
