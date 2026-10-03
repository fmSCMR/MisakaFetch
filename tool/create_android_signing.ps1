# Generates signing credentials outside the source tree; never prints passwords.
param([string]$Keytool)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$privateRoot = Join-Path $env:USERPROFILE '.misakafetch\signing'
$properties = Join-Path $privateRoot 'key.properties'
$keystore = Join-Path $privateRoot 'misakafetch-release.jks'
$localProperties = Join-Path $projectRoot 'android\key.properties'
if (-not $Keytool) {
    if ($env:JAVA_HOME) { $Keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe' }
    else {
        $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
        if ($command) { $Keytool = $command.Source }
    }
}
if (-not $Keytool) { throw 'Set JAVA_HOME or pass -Keytool with its full path.' }
if (-not (Test-Path -LiteralPath $Keytool)) { throw 'JDK keytool is missing; pass -Keytool with its full path.' }
if (Test-Path -LiteralPath $localProperties) { Write-Output 'Existing Android signing configuration retained.'; exit 0 }
if ((Test-Path -LiteralPath $keystore) -and -not (Test-Path -LiteralPath $properties)) { throw 'Existing keystore retained. Restore its credentials before continuing.' }
New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $privateRoot /inheritance:r /grant:r "${identity}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' *> $null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict signing directory permissions.' }
if (-not (Test-Path -LiteralPath $keystore)) {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $env:MISAKAFETCH_KEY_PASSWORD = [Convert]::ToBase64String($bytes)
    try {
        $content = 'storeFile=' + $keystore.Replace('\','/') + "`nkeyAlias=misakafetch`nstorePassword=" + $env:MISAKAFETCH_KEY_PASSWORD + "`nkeyPassword=" + $env:MISAKAFETCH_KEY_PASSWORD + "`n"
        [IO.File]::WriteAllText($properties, $content, [Text.UTF8Encoding]::new($false))
        $log = Join-Path $privateRoot 'keytool.log'
        $errorLog = Join-Path $privateRoot 'keytool-error.log'
        $process = Start-Process -FilePath $Keytool -ArgumentList @('-genkeypair','-keystore',('"'+$keystore+'"'),'-storetype','JKS','-alias','misakafetch','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','"CN=MisakaFetch, OU=Open Source, O=MisakaFetch, C=CN"','-storepass:env','MISAKAFETCH_KEY_PASSWORD','-keypass:env','MISAKAFETCH_KEY_PASSWORD') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $errorLog
        if ($process.ExitCode -ne 0) { throw 'Key generation failed. See private keytool logs; credentials were retained for recovery.' }
    } finally { Remove-Item Env:MISAKAFETCH_KEY_PASSWORD -ErrorAction SilentlyContinue }
}
Copy-Item -LiteralPath $properties -Destination $localProperties
& icacls.exe $localProperties /inheritance:r /grant:r "${identity}:F" 'SYSTEM:F' *> $null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict local signing configuration permissions.' }
$backup = Join-Path $privateRoot 'recovery-copy'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $keystore,$properties -Destination $backup -Force
Write-Output "Signing configured. Private credentials: $privateRoot. Copy these to your own offline backup; a same-disk recovery copy is not a disaster-recovery backup."
