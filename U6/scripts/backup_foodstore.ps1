[CmdletBinding()]
param(
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [string]$DatabaseHost = 'localhost',
    [int]$DatabasePort = 5432,
    [string]$DatabaseUser = 'postgres'
)

$ErrorActionPreference = 'Stop'
$databaseName = 'foodstorecopia'
$baseDirectory = Split-Path -Parent $PSScriptRoot
$backupDirectory = Join-Path $baseDirectory 'backups'
$logDirectory = Join-Path $baseDirectory 'logs'
New-Item -ItemType Directory -Path $backupDirectory, $logDirectory -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$backupFile = Join-Path $backupDirectory "${databaseName}_${stamp}.dump"
$partialFile = "$backupFile.partial"
$logFile = Join-Path $logDirectory "backup_${stamp}.log"
$listingFile = Join-Path $logDirectory "contenido_${stamp}.txt"
$metadataFile = Join-Path $logDirectory "respaldo_${stamp}.json"

function Write-BackupLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f [DateTimeOffset]::Now.ToString('o'), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    $pgDump = Join-Path $PgBin 'pg_dump.exe'
    $pgRestore = Join-Path $PgBin 'pg_restore.exe'
    foreach ($program in @($pgDump, $pgRestore)) {
        if (-not (Test-Path -LiteralPath $program -PathType Leaf)) {
            throw "No se encontro el programa: $program"
        }
    }

    $dumpVersion = (& $pgDump --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo comprobar la version de pg_dump.' }
    $restoreVersion = (& $pgRestore --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo comprobar la version de pg_restore.' }

    $startedAt = [DateTimeOffset]::Now
    Write-BackupLog "INICIO base=$databaseName host=$DatabaseHost puerto=$DatabasePort usuario=$DatabaseUser"
    Write-BackupLog "CLIENTE $dumpVersion"
    Write-BackupLog "ARCHIVO $backupFile"
    Write-Host 'Si PostgreSQL solicita una contrasena, escribila en la consola. No se guarda en este script.'

    & $pgDump --host=$DatabaseHost --port=$DatabasePort --username=$DatabaseUser --dbname=$databaseName --format=custom --file=$partialFile
    $dumpExitCode = $LASTEXITCODE
    if ($dumpExitCode -ne 0) {
        Write-BackupLog "FALLA pg_dump codigo=$dumpExitCode archivo_parcial=$partialFile"
        exit $dumpExitCode
    }

    $finishedAt = [DateTimeOffset]::Now
    $dumpItem = Get-Item -LiteralPath $partialFile
    if ($dumpItem.Length -eq 0) { throw 'El respaldo esta vacio.' }

    $listing = & $pgRestore --list $partialFile
    $listExitCode = $LASTEXITCODE
    if ($listExitCode -ne 0) {
        Write-BackupLog "FALLA pg_restore --list codigo=$listExitCode archivo_parcial=$partialFile"
        exit $listExitCode
    }
    $listing | Set-Content -LiteralPath $listingFile -Encoding UTF8
    Move-Item -LiteralPath $partialFile -Destination $backupFile

    [ordered]@{
        database = $databaseName
        host = $DatabaseHost
        port = $DatabasePort
        user = $DatabaseUser
        backup_started_at = $startedAt.ToString('o')
        backup_finished_at = $finishedAt.ToString('o')
        bytes = $dumpItem.Length
        file = $backupFile
        format = 'custom'
        pg_dump = $dumpVersion
        pg_restore = $restoreVersion
        listing_exit_code = $listExitCode
        full_restore_verified = $false
    } | ConvertTo-Json | Set-Content -LiteralPath $metadataFile -Encoding UTF8

    Write-BackupLog "EXITO base=$databaseName bytes=$($dumpItem.Length) codigo=0"
    Write-BackupLog "LISTADO_LEGIBLE archivo=$listingFile; restauracion completa pendiente"
    Write-BackupLog "METADATOS $metadataFile"
    Write-Host "Respaldo: $backupFile"
    Write-Host "Log: $logFile"
    exit 0
}
catch {
    Write-BackupLog "FALLA $($_.Exception.Message)"
    exit 1
}
