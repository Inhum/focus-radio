# Порог свободного места в процентах
$threshold = 20

# Получаем диски: тип 3 = локальный, тип 4 = сетевой
$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3 OR DriveType = 4"

foreach ($drive in $drives) {
    # Вычисляем процент свободного места
    $freePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100)

    # Переводим байты в гигабайты для удобочитаемого вывода
    $freeGB  = [math]::Round($drive.FreeSpace / 1GB, 1)
    $totalGB = [math]::Round($drive.Size       / 1GB, 1)

    if ($freePercent -lt $threshold) {
        Write-Host "WARN: $($drive.DeviceID) — свободно ${freePercent}% (${freeGB} ГБ из ${totalGB} ГБ)"
    } else {
        Write-Host "OK:   $($drive.DeviceID) — свободно ${freePercent}% (${freeGB} ГБ из ${totalGB} ГБ)"
    }
}