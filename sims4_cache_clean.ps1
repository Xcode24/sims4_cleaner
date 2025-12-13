# Путь к папке The Sims 4
$SimsPath = "$env:USERPROFILE\Documents\Electronic Arts\The Sims 4"

if (!(Test-Path $SimsPath)) {
    Write-Host "Папка The Sims 4 не найдена!"
    Pause
    exit
}

# Папка для бэкапов
$BackupRoot = "$env:USERPROFILE\Documents\Sims4_Cache_Backups"
if (!(Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot | Out-Null
}

# Имя бэкапа
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupPath = Join-Path $BackupRoot "Backup_$Date"
New-Item -ItemType Directory -Path $BackupPath | Out-Null

# Папки для обработки
$CacheFolders = @(
    "cache",
    "cachestr",
    "cachewebkit",
    "lotcachedata"
)

# Бэкап и удаление папок
foreach ($Folder in $CacheFolders) {
    $Source = Join-Path $SimsPath $Folder
    $Destination = Join-Path $BackupPath $Folder

    if (Test-Path $Source) {
        Copy-Item $Source $Destination -Recurse
        Remove-Item $Source -Recurse -Force
        Write-Host "Бэкап + удаление папки: $Folder"
    }
}

# Файл localthumbcache.package
$ThumbCache = Join-Path $SimsPath "localthumbcache.package"
if (Test-Path $ThumbCache) {
    Copy-Item $ThumbCache $BackupPath
    Remove-Item $ThumbCache -Force
    Write-Host "Бэкап + удаление файла: localthumbcache.package"
}

Write-Host "Готово. Бэкап создан в:"
Write-Host $BackupPath
Pause
