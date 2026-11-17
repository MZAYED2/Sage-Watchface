param(
    [ValidateSet('Initialize', 'Upload', 'Build')]
    [string]$Action = 'Initialize',
    [string]$Repository,
    [int]$VersionCode = 1001,
    [string]$VersionName = '1.0.1'
)
$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$signingDirectory = Join-Path $projectDirectory '.signing'
$keystorePath = Join-Path $signingDirectory 'sage-release.jks'
$backupPath = Join-Path $signingDirectory 'credentials.dpapi'
$jdkDirectory = $env:JAVA_HOME
if (-not $jdkDirectory -or -not (Test-Path (Join-Path $jdkDirectory 'bin/keytool.exe'))) {
    $jdkDirectory = 'C:/Program Files/Android/Android Studio/jbr'
}
$keytool = Join-Path $jdkDirectory 'bin/keytool.exe'
if (-not (Test-Path $keytool)) { throw 'Set JAVA_HOME to a JDK with keytool first.' }
Add-Type -AssemblyName System.Security
if (Test-Path $keystorePath) {
    if (-not (Test-Path $backupPath)) { throw 'Existing key has no local credential backup; refusing to replace it.' }
    $encrypted = [IO.File]::ReadAllBytes($backupPath)
    $clear = [Security.Cryptography.ProtectedData]::Unprotect(
        $encrypted, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $signing = [Text.Encoding]::UTF8.GetString($clear) | ConvertFrom-Json
    [Array]::Clear($clear, 0, $clear.Length)
} else {
    New-Item -ItemType Directory -Force -Path $signingDirectory | Out-Null
    $random = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    $generator.GetBytes($random)
    $generator.Dispose()
    $password = [BitConverter]::ToString($random).Replace('-', '')
    [Array]::Clear($random, 0, $random.Length)
    $signing = [pscustomobject]@{
        StorePassword = $password
        KeyPassword = $password
        Alias = 'sage-nocturne'
    }
    $env:ANDROID_KEYSTORE_PASSWORD = $signing.StorePassword
    $env:ANDROID_KEY_PASSWORD = $signing.KeyPassword
    & $keytool -genkeypair -noprompt -storetype JKS -keystore $keystorePath -alias $signing.Alias `
        -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Sage Nocturne' `
        -storepass:env ANDROID_KEYSTORE_PASSWORD -keypass:env ANDROID_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Release key generation failed.' }
    $clear = [Text.Encoding]::UTF8.GetBytes(($signing | ConvertTo-Json -Compress))
    $encrypted = [Security.Cryptography.ProtectedData]::Protect(
        $clear, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes($backupPath, $encrypted)
    [Array]::Clear($clear, 0, $clear.Length)
}
$env:ANDROID_KEYSTORE_PATH = $keystorePath
$env:ANDROID_KEYSTORE_PASSWORD = $signing.StorePassword
$env:ANDROID_KEY_ALIAS = $signing.Alias
$env:ANDROID_KEY_PASSWORD = $signing.KeyPassword
try {
    if ($Action -eq 'Upload') {
        if (-not $Repository) { throw 'Specify -Repository owner/name.' }
        $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
        $gh = if ($ghCommand) { $ghCommand.Source } else { Join-Path $projectDirectory '.codex-tools/gh/bin/gh.exe' }
        function Set-SigningSecret([string]$Name, [string]$Value) {
            $Value | & $gh secret set $Name --repo $Repository
            if ($LASTEXITCODE -ne 0) { throw ('Secret upload failed: ' + $Name) }
            Write-Host ('Stored repository secret: ' + $Name)
        }
        Set-SigningSecret 'ANDROID_KEYSTORE_BASE64' ([Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath)))
        Set-SigningSecret 'ANDROID_KEYSTORE_PASSWORD' $signing.StorePassword
        Set-SigningSecret 'ANDROID_KEY_ALIAS' $signing.Alias
        Set-SigningSecret 'ANDROID_KEY_PASSWORD' $signing.KeyPassword
    } elseif ($Action -eq 'Build') {
        $env:JAVA_HOME = $jdkDirectory
        & (Join-Path $projectDirectory 'gradlew.bat') --no-daemon --no-configuration-cache :watchface:assembleRelease `
            ('-PreleaseVersionCode=' + $VersionCode) ('-PreleaseVersionName=' + $VersionName)
        if ($LASTEXITCODE -ne 0) { throw 'Signed release build failed.' }
    } else {
        Write-Host ('Release signing key ready: ' + $keystorePath)
        Write-Host 'Credentials backed up with Windows DPAPI for this Windows user; no secrets printed.'
    }
} finally {
    foreach ($name in @('ANDROID_KEYSTORE_PATH', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD')) {
        Remove-Item ('Env:' + $name) -ErrorAction SilentlyContinue
    }
}
