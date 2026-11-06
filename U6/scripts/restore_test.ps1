[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [string]$DatabaseHost = 'localhost',
    [int]$DatabasePort = 5432,
    [string]$DatabaseUser = 'postgres',
    [switch]$RecreateTestDatabase
)

$ErrorActionPreference = 'Stop'
$sourceName = 'foodstorecopia'
$targetName = 'foodstore_restore_test'
$resolvedBackup = (Resolve-Path -LiteralPath $BackupFile).ProviderPath
$backupItem = Get-Item -LiteralPath $resolvedBackup
if ($backupItem.PSIsContainer) { throw 'Debe indicarse un archivo .dump.' }
if ($backupItem.BaseName -notmatch '^foodstorecopia_(\d{8}_\d{6}_\d{3})$') {
    throw 'El nombre del respaldo no coincide con el generado por backup_foodstore.ps1.'
}
$backupStamp = $Matches[1]
$baseDirectory = Split-Path -Parent (Split-Path -Parent $resolvedBackup)
$logDirectory = Join-Path $baseDirectory 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$metadataFile = Join-Path $logDirectory "respaldo_${backupStamp}.json"
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$logFile = Join-Path $logDirectory "restore_${runStamp}.log"
$validationFile = Join-Path $logDirectory "validaciones_${runStamp}.json"
$comparisonFile = Join-Path $logDirectory "comparacion_${runStamp}.csv"
$resultFile = Join-Path $logDirectory "resultado_restore_${runStamp}.json"
$sqlFile = Join-Path $logDirectory "validaciones_${runStamp}.sql"
$previousPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')
$timer = $null
$exitStatus = 1

function Write-RestoreLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f [DateTimeOffset]::Now.ToString('o'), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Invoke-PgProgram {
    param([string]$Program, [string[]]$Arguments, [switch]$ReturnOutput)
    $previousAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $programOutput = @(& $Program @Arguments 2>&1)
        $programStatus = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousAction }

    foreach ($entry in $programOutput) {
        $line = $entry.ToString()
        Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
        if (-not $ReturnOutput) { Write-Host $line }
    }
    if ($programStatus -ne 0) {
        throw "$(Split-Path -Leaf $Program) termino con codigo $programStatus. Ver el log: $logFile"
    }
    if ($ReturnOutput) { $programOutput | ForEach-Object { $_.ToString() } }
}

try {
    if ($targetName -ne 'foodstore_restore_test' -or $targetName -eq $sourceName) {
        throw 'Destino de restauracion no permitido.'
    }
    foreach ($name in @('psql', 'pg_restore', 'createdb', 'dropdb')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PgBin "$name.exe") -PathType Leaf)) {
            throw "No se encontro $name.exe en $PgBin"
        }
    }
    $psql = Join-Path $PgBin 'psql.exe'
    $pgRestore = Join-Path $PgBin 'pg_restore.exe'
    $createDb = Join-Path $PgBin 'createdb.exe'
    $dropDb = Join-Path $PgBin 'dropdb.exe'
    $metadata = Get-Content -LiteralPath $metadataFile -Raw | ConvertFrom-Json
    if ($metadata.database -ne $sourceName -or [long]$metadata.bytes -ne $backupItem.Length) {
        throw 'La base o el tamano del archivo no coincide con los metadatos del respaldo.'
    }
    if ($metadata.host -ne $DatabaseHost -or [int]$metadata.port -ne $DatabasePort) {
        throw 'El host o puerto difieren de los registrados en el respaldo.'
    }
    $backupStartedAt = [DateTimeOffset]::Parse($metadata.backup_started_at)
    $commonArguments = @('--host', $DatabaseHost, '--port', "$DatabasePort", '--username', $DatabaseUser, '--no-password')
    $psqlArguments = $commonArguments + @('-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1')
    Write-RestoreLog "PREPARACION origen_del_respaldo=$sourceName destino=$targetName archivo=$resolvedBackup"
    Write-Host 'La opcion RecreateTestDatabase permite eliminar y recrear solo foodstore_restore_test.'
    Write-Host 'Ingrese la contrasena de PostgreSQL. Se usa solo durante este proceso y no se guarda en archivos.'
    $securePassword = Read-Host -Prompt 'Contrasena' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
        [Environment]::SetEnvironmentVariable('PGPASSWORD', [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer), 'Process')
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
        $securePassword.Dispose()
    }

    $serverVersion = (Invoke-PgProgram -Program $psql -Arguments ($psqlArguments + @('--dbname', 'postgres', '--command', 'SHOW server_version_num;')) -ReturnOutput | Out-String).Trim()
    if ([int]$serverVersion -lt 160000) { throw 'El servidor debe ser PostgreSQL 16 o superior.' }
    $dumpListing = Invoke-PgProgram -Program $pgRestore -Arguments @('--list', $resolvedBackup) -ReturnOutput
    $dumpListing | Set-Content -LiteralPath (Join-Path $logDirectory "contenido_restore_${runStamp}.txt") -Encoding UTF8
    $existsSql = "SELECT count(*) FROM pg_database WHERE datname = 'foodstore_restore_test';"
    $targetExists = (Invoke-PgProgram -Program $psql -Arguments ($psqlArguments + @('--dbname', 'postgres', '--command', $existsSql)) -ReturnOutput | Out-String).Trim()
    if ($targetExists -eq '1') {
        if (-not $RecreateTestDatabase) {
            throw 'La base de prueba ya existe. La recreacion requiere -RecreateTestDatabase.'
        }
        Write-RestoreLog "PREPARACION eliminando exclusivamente $targetName"
        Invoke-PgProgram -Program $dropDb -Arguments ($commonArguments + @('--maintenance-db', 'postgres', '--force', $targetName))
    }

    # Conteos comprobados por el equipo en foodstorecopia antes del respaldo.
    $expectedCounts = [ordered]@{
        categoria = 2006
        cliente = 20004
        producto = 50010
        pedido = 200004
        detalle_pedido = 200014
    }
    $validationSql = @'
SELECT json_build_object(
  'base', current_database(),
  'conteos', json_build_object(
    'categoria', (SELECT count(*) FROM public.categoria),
    'cliente', (SELECT count(*) FROM public.cliente),
    'producto', (SELECT count(*) FROM public.producto),
    'pedido', (SELECT count(*) FROM public.pedido),
    'detalle_pedido', (SELECT count(*) FROM public.detalle_pedido)
  ),
  'productos_invalidos', (SELECT count(*) FROM public.producto WHERE precio < 0 OR stock < 0),
  'detalles_invalidos', (SELECT count(*) FROM public.detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0)
)::text;
'@
    $validationSql | Set-Content -LiteralPath $sqlFile -Encoding UTF8
    Write-RestoreLog 'RTO previsto: 300 segundos. RPO previsto: 24 horas.'
    Write-RestoreLog 'El cronometro incluye crear la base, restaurar, consultar y comparar las validaciones.'

    $restoreStartedAt = [DateTimeOffset]::Now
    if ($restoreStartedAt -lt $backupStartedAt) { throw 'El reloj es anterior al inicio del respaldo.' }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-PgProgram -Program $createDb -Arguments ($commonArguments + @('--template', 'template0', $targetName))
    Invoke-PgProgram -Program $pgRestore -Arguments ($commonArguments + @('--dbname', $targetName, '--exit-on-error', '--no-owner', '--no-privileges', $resolvedBackup))
    $validationText = (Invoke-PgProgram -Program $psql -Arguments ($psqlArguments + @('--dbname', $targetName, '--command', $validationSql)) -ReturnOutput | Out-String).Trim()
    $validation = $validationText | ConvertFrom-Json
    $validation | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $validationFile -Encoding UTF8
    $comparison = foreach ($table in $expectedCounts.Keys) {
        [pscustomobject]@{
            tabla = $table
            antes_del_respaldo = [long]$expectedCounts[$table]
            despues_de_restaurar = [long]$validation.conteos.$table
            coincide = ([long]$expectedCounts[$table] -eq [long]$validation.conteos.$table)
        }
    }
    $comparison | Export-Csv -LiteralPath $comparisonFile -NoTypeInformation -Encoding UTF8
    if ($validation.base -ne $targetName) { throw 'Las validaciones se ejecutaron en una base inesperada.' }
    if (@($comparison | Where-Object { -not $_.coincide }).Count -ne 0) { throw 'Los conteos no coinciden. Ver comparacion CSV.' }
    if ([long]$validation.productos_invalidos -ne 0 -or [long]$validation.detalles_invalidos -ne 0) {
        throw 'Los controles de integridad no devolvieron cero.'
    }
    $timer.Stop()
    $validationFinishedAt = [DateTimeOffset]::Now
    $rtoSeconds = $timer.Elapsed.TotalSeconds
    $rpoMinutes = ($restoreStartedAt - $backupStartedAt).TotalMinutes
    [ordered]@{
        resultado = 'EXITO'
        origen_del_respaldo = $sourceName
        destino = $targetName
        archivo_respaldo = $resolvedBackup
        inicio_respaldo = $backupStartedAt.ToString('o')
        fin_respaldo = $metadata.backup_finished_at
        inicio_restauracion = $restoreStartedAt.ToString('o')
        fin_validaciones = $validationFinishedAt.ToString('o')
        rto_previsto_segundos = 300
        rto_observado_segundos = [Math]::Round($rtoSeconds, 3)
        rto_cumple_objetivo = ($rtoSeconds -le 300)
        rpo_previsto_horas = 24
        rpo_observado_minutos = [Math]::Round($rpoMinutes, 3)
        rpo_cumple_objetivo = ($rpoMinutes -le 1440)
        criterio_rpo = 'Antiguedad del respaldo al iniciar el ensayo, usando su hora de inicio. No mide perdida real de datos.'
        comparacion = @($comparison)
        productos_invalidos = [long]$validation.productos_invalidos
        detalles_invalidos = [long]$validation.detalles_invalidos
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultFile -Encoding UTF8
    $comparison | Format-Table -AutoSize | Out-Host
    Write-RestoreLog "EXITO restauracion y validaciones completas en $targetName"
    Write-RestoreLog ('RTO observado: {0:N3} segundos; objetivo: 300 segundos' -f $rtoSeconds)
    Write-RestoreLog ('RPO observado: {0:N3} minutos de antiguedad; objetivo: 1440 minutos' -f $rpoMinutes)
    Write-RestoreLog "Productos invalidos=$($validation.productos_invalidos); detalles invalidos=$($validation.detalles_invalidos)"
    Write-RestoreLog "RESULTADO $resultFile"
    Write-RestoreLog "COMPARACION $comparisonFile"
    $exitStatus = 0
}
catch {
    if ($null -ne $timer) { $timer.Stop() }
    Write-RestoreLog "FALLA $($_.Exception.Message)"
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPassword, 'Process')
}
exit $exitStatus
