# ================== UTF-8 FIX ==================
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[System.Globalization.CultureInfo]::CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo("ru-RU")
[System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo("ru-RU")
# ===============================================

# Загружаем сборки Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Включаем визуальные стили
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# Проверка: запущена ли The Sims 4
$GameProcesses = @("TS4_x64", "TS4")
$RunningGame = Get-Process -Name $GameProcesses -ErrorAction SilentlyContinue

if ($RunningGame) {
    $null = [System.Windows.Forms.MessageBox]::Show(
        "The Sims 4 сейчас запущена!`r`nЗакройте игру и запустите скрипт снова.",
        "Игра запущена",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    exit
}

# Путь к папке The Sims 4
$SimsPath = Join-Path $env:USERPROFILE "Documents\Electronic Arts\The Sims 4"
if (!(Test-Path $SimsPath)) {
    $null = [System.Windows.Forms.MessageBox]::Show(
        "Папка The Sims 4 не найдена!`r`nПуть: $SimsPath",
        "Ошибка",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Функция для получения размера папки
function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            $Size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop | 
                Measure-Object -Property Length -Sum).Sum
            if ($null -eq $Size) { return 0 }
            return $Size
        }
        catch {
            return 0
        }
    }
    return 0
}

# Функция для форматирования размера
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) {
        return "{0:N2} ГБ" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} МБ" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} КБ" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes Б"
    }
}

# Функция для подсчета общего размера
function Get-TotalBackupSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $Size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $Size) { return 0 }
        return $Size
    }
    return 0
}

# Функция для восстановления из бэкапа
function Restore-Backup {
    param([string]$BackupPath)
    
    $Confirm = [System.Windows.Forms.MessageBox]::Show(
        "Вы уверены, что хотите восстановить файлы из бэкапа?`r`n`r`nПуть к бэкапу:`r`n$BackupPath`r`n`r`nЭто заменит текущие файлы в папке игры.",
        "Подтверждение восстановления",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($Confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            # Восстанавливаем папки из бэкапа
            Get-ChildItem -Path $BackupPath -Directory | ForEach-Object {
                $SourceDir = $_.FullName
                $DestDir = Join-Path $SimsPath $_.Name
                
                if (Test-Path $DestDir) {
                    Remove-Item $DestDir -Recurse -Force -ErrorAction Stop
                }
                Copy-Item $SourceDir $DestDir -Recurse -ErrorAction Stop
            }
            
            # Восстанавливаем файлы из бэкапа
            Get-ChildItem -Path $BackupPath -File | ForEach-Object {
                $SourceFile = $_.FullName
                $DestFile = Join-Path $SimsPath $_.Name
                
                if (Test-Path $DestFile) {
                    Remove-Item $DestFile -Force -ErrorAction Stop
                }
                Copy-Item $SourceFile $DestFile -ErrorAction Stop
            }
            
            $null = [System.Windows.Forms.MessageBox]::Show(
                "Восстановление выполнено успешно!`r`nФайлы восстановлены из:`r`n$BackupPath",
                "Восстановление завершено",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return $true
        }
        catch {
            $null = [System.Windows.Forms.MessageBox]::Show(
                "Ошибка при восстановлении: $($_.Exception.Message)",
                "Ошибка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }
    return $false
}

# Функция для очистки бэкапов
function Clear-Backups {
    $BackupRoot = Join-Path $env:USERPROFILE "Documents\Electronic Arts\Sims4_Cache_Backups"
    
    if (!(Test-Path $BackupRoot)) {
        $null = [System.Windows.Forms.MessageBox]::Show(
            "Папка бэкапов не найдена.",
            "Информация",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    $backupCount = (Get-ChildItem -Path $BackupRoot -Directory).Count
    $totalSize = Get-TotalBackupSize -Path $BackupRoot
    
    $Confirm = [System.Windows.Forms.MessageBox]::Show(
        "Вы уверены, что хотите удалить все бэкапы?`r`n`r`nКоличество бэкапов: $backupCount`r`nОбщий размер: $(Format-Size -Bytes $totalSize)`r`n`r`nЭто действие нельзя отменить!",
        "Подтверждение удаления бэкапов",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($Confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            Remove-Item $BackupRoot -Recurse -Force -ErrorAction Stop
            $null = [System.Windows.Forms.MessageBox]::Show(
                "Все бэкапы успешно удалены!",
                "Бэкапы очищены",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            $null = [System.Windows.Forms.MessageBox]::Show(
                "Ошибка при удалении бэкапов: $($_.Exception.Message)",
                "Ошибка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
}

# Цвета для темной темы
$darkBgColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$darkFgColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$darkControlBg = [System.Drawing.Color]::FromArgb(45, 45, 45)
$darkBorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
$darkButtonBg = [System.Drawing.Color]::FromArgb(60, 60, 60)
$darkButtonHover = [System.Drawing.Color]::FromArgb(80, 80, 80)

# Создаем шрифт для интерфейса
$interfaceFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$buttonFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Функция для создания темной кнопки
function New-DarkButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [scriptblock]$OnClick
    )
    
    $Button = New-Object System.Windows.Forms.Button
    $Button.Location = New-Object System.Drawing.Point($X, $Y)
    $Button.Size = New-Object System.Drawing.Size($Width, $Height)
    $Button.Text = $Text
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.BackColor = $darkButtonBg
    $Button.ForeColor = $darkFgColor
    $Button.FlatAppearance.BorderColor = $darkBorderColor
    $Button.FlatAppearance.MouseOverBackColor = $darkButtonHover
    $Button.Font = $buttonFont
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    if ($OnClick) {
        $Button.Add_Click($OnClick)
    }
    
    return $Button
}

# Функция для создания темной формы
function New-DarkForm {
    param(
        [string]$Title,
        [int]$Width,
        [int]$Height
    )
    
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = $Title
    $Form.Size = New-Object System.Drawing.Size($Width, $Height)
    $Form.StartPosition = "CenterScreen"
    $Form.BackColor = $darkBgColor
    $Form.ForeColor = $darkFgColor
    $Form.Font = $interfaceFont
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $Form.MaximizeBox = $false
    
    return $Form
}

# Функция для создания темной метки
function New-DarkLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    
    $Label = New-Object System.Windows.Forms.Label
    $Label.Location = New-Object System.Drawing.Point($X, $Y)
    $Label.Size = New-Object System.Drawing.Size($Width, $Height)
    $Label.Text = $Text
    $Label.BackColor = $darkBgColor
    $Label.ForeColor = $darkFgColor
    $Label.Font = $interfaceFont
    
    return $Label
}

# Функция для создания темного ListView
function New-DarkListView {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    
    $ListView = New-Object System.Windows.Forms.ListView
    $ListView.Location = New-Object System.Drawing.Point($X, $Y)
    $ListView.Size = New-Object System.Drawing.Size($Width, $Height)
    $ListView.View = [System.Windows.Forms.View]::Details
    $ListView.FullRowSelect = $true
    $ListView.CheckBoxes = $true
    $ListView.BackColor = $darkControlBg
    $ListView.ForeColor = $darkFgColor
    $ListView.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $ListView.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Regular)
    
    return $ListView
}

# Собираем информацию о файлах и папках для очистки
$ItemsToProcess = @()
$CacheFolders = @("cache", "cachestr", "cachewebkit", "lotcachedata")

foreach ($Folder in $CacheFolders) {
    $Source = Join-Path $SimsPath $Folder
    if (Test-Path $Source) {
        $Size = Get-FolderSize -Path $Source
        $ItemsToProcess += [PSCustomObject]@{
            Name          = $Folder
            Path          = $Source
            Type          = "Папка"
            Size          = $Size
            FormattedSize = Format-Size -Bytes $Size
        }
    }
}

$ThumbCache = Join-Path $SimsPath "localthumbcache.package"
if (Test-Path $ThumbCache) {
    $Size = (Get-Item $ThumbCache).Length
    $ItemsToProcess += [PSCustomObject]@{
        Name          = "localthumbcache.package"
        Path          = $ThumbCache
        Type          = "Файл"
        Size          = $Size
        FormattedSize = Format-Size -Bytes $Size
    }
}

# Проверяем, есть ли что удалять
if ($ItemsToProcess.Count -eq 0) {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Нет файлов или папок для очистки.`r`nЖелаете перейти к управлению бэкапами?",
        "Нечего очищать",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        # Создаем форму управления бэкапами
        $BackupForm = New-DarkForm "Управление бэкапами Sims 4" 620 400
        
        # Информация о бэкапах
        $BackupRoot = Join-Path $env:USERPROFILE "Documents\Electronic Arts\Sims4_Cache_Backups"
        $backupExists = Test-Path $BackupRoot
        
        if ($backupExists) {
            $backups = Get-ChildItem -Path $BackupRoot -Directory | Sort-Object CreationTime -Descending
            $totalSize = Get-TotalBackupSize -Path $BackupRoot
            
            $backupInfo = "Доступные бэкапы:`r`n"
            $backupInfo += "Количество: $($backups.Count)`r`n"
            $backupInfo += "Общий размер: $(Format-Size -Bytes $totalSize)`r`n`r`n"
            $backupInfo += "Последний бэкап:`r`n"
            
            if ($backups.Count -gt 0) {
                $latestBackup = $backups[0]
                $backupInfo += "$($latestBackup.Name)`r`n"
                $backupInfo += "Создан: $($latestBackup.CreationTime)`r`n"
                $backupInfo += "Путь: $($latestBackup.FullName)"
            }
        }
        else {
            $backupInfo = "Бэкапы не найдены."
        }
        
        $Label = New-DarkLabel $backupInfo 20 20 580 150
        $BackupForm.Controls.Add($Label)
        
        # Панель для кнопок
        $buttonY = 190
        $buttonSpacing = 20
        $buttonWidth = 170
        $buttonHeight = 45
        
        # Центрируем кнопки
        $totalButtonWidth = (3 * $buttonWidth) + (2 * $buttonSpacing)
        $startX = ($BackupForm.ClientSize.Width - $totalButtonWidth) / 2
        
        # Кнопка восстановления
        $RestoreButton = New-DarkButton "🔧Восстановить из бекапа" $startX $buttonY $buttonWidth $buttonHeight -OnClick {
            if ($backups.Count -gt 0) {
                $latestBackup = $backups[0]
                if (Restore-Backup -BackupPath $latestBackup.FullName) {
                    $BackupForm.Close()
                }
            }
        }
        $RestoreButton.Enabled = $backupExists -and ($backups.Count -gt 0)
        $BackupForm.Controls.Add($RestoreButton)
        
        # Кнопка очистки бэкапов
        $ClearBackupButton = New-DarkButton "🗑️Очистить бэкапы" ($startX + $buttonWidth + $buttonSpacing) $buttonY $buttonWidth $buttonHeight -OnClick {
            Clear-Backups
            $BackupForm.Close()
        }
        $ClearBackupButton.Enabled = $backupExists
        $BackupForm.Controls.Add($ClearBackupButton)
        
        # Кнопка закрытия
        $CloseButton = New-DarkButton "❌Закрыть" ($startX + 2 * ($buttonWidth + $buttonSpacing)) $buttonY $buttonWidth $buttonHeight -OnClick { 
            $BackupForm.Close() 
        }
        $BackupForm.Controls.Add($CloseButton)
        
        # Разделитель
        $separator = New-Object System.Windows.Forms.Label
        $separator.Location = New-Object System.Drawing.Point(20, ($buttonY - 15))
        $separator.Size = New-Object System.Drawing.Size(580, 2)
        $separator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $BackupForm.Controls.Add($separator)
        
        $null = $BackupForm.ShowDialog()
    }
    exit
}

# Создаем основную форму
$Form = New-DarkForm "Очистка кэша The Sims 4" 740 600

# Текстовая информация


# Список файлов/папок
$ListView = New-DarkListView 20 90 700 230

$null = $ListView.Columns.Add("Название", 180)
$null = $ListView.Columns.Add("Тип", 90)
$null = $ListView.Columns.Add("Размер", 110)
$null = $ListView.Columns.Add("Путь", 310)

$TotalSize = 0
foreach ($Item in $ItemsToProcess) {
    $ListViewItem = New-Object System.Windows.Forms.ListViewItem($Item.Name)
    $null = $ListViewItem.SubItems.Add($Item.Type)
    $null = $ListViewItem.SubItems.Add($Item.FormattedSize)
    $null = $ListViewItem.SubItems.Add($Item.Path)
    $ListViewItem.Checked = $true
    $ListViewItem.Tag = $Item
    $null = $ListView.Items.Add($ListViewItem)
    $TotalSize += $Item.Size
}

$Form.Controls.Add($ListView)

# Информация об общем размере и пути бэкапа
$BackupRoot = Join-Path $env:USERPROFILE "Documents\Electronic Arts\Sims4_Cache_Backups"
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupPath = Join-Path $BackupRoot "Backup_$Date"

$SizeLabel = New-DarkLabel ("Общий размер для бэкапа: " + (Format-Size -Bytes $TotalSize)) 20 335 700 25
$Form.Controls.Add($SizeLabel)

$PathLabel = New-DarkLabel ("Путь бэкапа: $BackupPath") 20 365 700 45
$Form.Controls.Add($PathLabel)

# Разделитель
$separator = New-Object System.Windows.Forms.Label
$separator.Location = New-Object System.Drawing.Point(20, 420)
$separator.Size = New-Object System.Drawing.Size(700, 2)
$separator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$Form.Controls.Add($separator)

# Кнопки
$buttonY = 440
$buttonSpacing = 20
$buttonWidth = 165
$buttonHeight = 50

# Центрируем кнопки
$totalButtonWidth = (4 * $buttonWidth) + (3 * $buttonSpacing)
$startX = ($Form.ClientSize.Width - $totalButtonWidth) / 2

# Кнопка очистки
$CleanButton = New-DarkButton "🧹Очистить cash игры" $startX $buttonY $buttonWidth $buttonHeight -OnClick {
    # Получаем выбранные элементы
    $SelectedItems = @()
    foreach ($Item in $ListView.Items) {
        if ($Item.Checked) {
            $SelectedItems += $Item.Tag
        }
    }
    
    if ($SelectedItems.Count -eq 0) {
        $null = [System.Windows.Forms.MessageBox]::Show(
            "Не выбрано ни одного элемента для обработки.",
            "Предупреждение",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Создаем папку для бэкапов
    if (!(Test-Path $BackupRoot)) {
        $null = New-Item -ItemType Directory -Path $BackupRoot
    }
    
    # Создаем папку для текущего бэкапа
    $null = New-Item -ItemType Directory -Path $BackupPath
    
    # Выполняем бэкап и удаление выбранных элементов
    $BackupSize = 0
    foreach ($Item in $SelectedItems) {
        $Destination = Join-Path $BackupPath (Split-Path $Item.Path -Leaf)
        
        try {
            if ($Item.Type -eq "Папка") {
                Copy-Item $Item.Path $Destination -Recurse -ErrorAction Stop
                Remove-Item $Item.Path -Recurse -Force -ErrorAction Stop
            }
            else {
                Copy-Item $Item.Path $Destination -ErrorAction Stop
                Remove-Item $Item.Path -Force -ErrorAction Stop
            }
            $BackupSize += $Item.Size
        }
        catch {
            $null = [System.Windows.Forms.MessageBox]::Show(
                "Ошибка при обработке $($Item.Name): $($_.Exception.Message)",
                "Ошибка",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    
    # Показываем результат
    $resultText = "Операция завершена успешно!`r`n`r`n"
    $resultText += "Обработано элементов: $($SelectedItems.Count)`r`n"
    $resultText += "Общий размер бэкапа: $(Format-Size -Bytes $BackupSize)`r`n"
    $resultText += "Бэкап создан в:`r`n$BackupPath`r`n`r`n"
    $resultText += "Путь к бэкапам: $BackupRoot"
    
    $null = [System.Windows.Forms.MessageBox]::Show(
        $resultText,
        "Очистка завершена",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    $Form.Close()
}
$Form.Controls.Add($CleanButton)

# Кнопка восстановления
$RestoreButton = New-DarkButton "🔧Восстановить из бекапа" ($startX + $buttonWidth + $buttonSpacing) $buttonY $buttonWidth $buttonHeight -OnClick {
    if (!(Test-Path $BackupRoot)) {
        $null = [System.Windows.Forms.MessageBox]::Show(
            "Папка бэкапов не найдена.",
            "Информация",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    $backups = Get-ChildItem -Path $BackupRoot -Directory | Sort-Object CreationTime -Descending
    if ($backups.Count -eq 0) {
        $null = [System.Windows.Forms.MessageBox]::Show(
            "Бэкапы не найдены.",
            "Информация",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    $latestBackup = $backups[0]
    $Form.Close()
    Restore-Backup -BackupPath $latestBackup.FullName
}
$Form.Controls.Add($RestoreButton)

# Кнопка очистки бэкапов
$ClearBackupButton = New-DarkButton "🗑️Очистить бэкапы" ($startX + 2 * ($buttonWidth + $buttonSpacing)) $buttonY $buttonWidth $buttonHeight -OnClick {
    $Form.Close()
    Clear-Backups
}
$Form.Controls.Add($ClearBackupButton)

# Кнопка отмены
$CancelButton = New-DarkButton "❌Отмена" ($startX + 3 * ($buttonWidth + $buttonSpacing)) $buttonY $buttonWidth $buttonHeight -OnClick { 
    $Form.Close() 
}
$Form.Controls.Add($CancelButton)

# Показываем форму
$null = $Form.ShowDialog()
