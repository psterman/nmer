param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'status.json'),
    [int]$IntervalMs = 1000,
    [int]$HistoryLimit = 180
)

$ErrorActionPreference = 'SilentlyContinue'

$logicalCpu = [Environment]::ProcessorCount
if ($logicalCpu -le 0) { $logicalCpu = 1 }

$cpuSnapshot = @{}
$ioSnapshot = @{}
$history = New-Object System.Collections.ArrayList
$startedAt = Get-Date

function To-MB([double]$bytes) {
    return [Math]::Round($bytes / 1MB, 2)
}

function Get-StatusLevel([double]$value, [double]$warnAt, [double]$criticalAt) {
    if ($value -ge $criticalAt) { return 'critical' }
    if ($value -ge $warnAt) { return 'warn' }
    return 'ok'
}

function Build-Checklist($agg, $cmdStats) {
    $items = @()

    $items += [ordered]@{
        id = 'concurrency'
        title = '并发搜索任务'
        value = "rg 进程数: $($agg.rgCount)"
        status = if ($agg.rgCount -ge 5) { 'critical' } elseif ($agg.rgCount -ge 3) { 'warn' } else { 'ok' }
        reason = if ($agg.rgCount -ge 5) { '输入触发过快或旧任务未取消，出现明显并发堆叠。' } elseif ($agg.rgCount -ge 3) { '存在并发叠加，建议验证防抖和 cancel。' } else { '并发水平正常。' }
        suggestion = '键入触发增加 150-250ms debounce，并在新查询启动前 cancel 旧任务。'
    }

    $items += [ordered]@{
        id = 'rg_memory'
        title = 'rg 内存占用'
        value = "总工作集: $([string]$agg.rgMemMB) MB"
        status = Get-StatusLevel $agg.rgMemMB 400 900
        reason = if ($agg.rgMemMB -ge 900) { 'rg 占用过高，可能扫描范围过大或命中过多。' } elseif ($agg.rgMemMB -ge 400) { 'rg 内存偏高，建议检查排除规则。' } else { 'rg 内存可接受。' }
        suggestion = '补充 -g/--glob 排除 node_modules、dist、*.log、*.min.*、大文件目录。'
    }

    $items += [ordered]@{
        id = 'searchcenter_memory'
        title = 'SearchCenter 内存占用'
        value = "总工作集: $([string]$agg.scMemMB) MB"
        status = Get-StatusLevel $agg.scMemMB 500 1200
        reason = if ($agg.scMemMB -ge 1200) { '结果聚合/预览缓存疑似堆积。' } elseif ($agg.scMemMB -ge 500) { '内存偏高，建议检查是否全量缓存结果。' } else { 'SearchCenter 内存正常。' }
        suggestion = '结果改为分页与流式处理，限制预览缓存数量。'
    }

    $items += [ordered]@{
        id = 'scope_filter'
        title = '扫描范围治理'
        value = "带排除参数的 rg 占比: $($cmdStats.excludeRatio)%"
        status = if ($cmdStats.excludeRatio -lt 30 -and $agg.rgCount -gt 0) { 'critical' } elseif ($cmdStats.excludeRatio -lt 65 -and $agg.rgCount -gt 0) { 'warn' } else { 'ok' }
        reason = if ($agg.rgCount -eq 0) { '暂无活跃 rg 任务。' } elseif ($cmdStats.excludeRatio -lt 30) { '多数 rg 命令缺少排除参数，扫描范围可能失控。' } elseif ($cmdStats.excludeRatio -lt 65) { '部分 rg 已做排除，但仍不充分。' } else { '排除参数覆盖较好。' }
        suggestion = '统一命令模板：默认附加 --max-filesize 与关键目录排除。'
    }

    $items += [ordered]@{
        id = 'backpressure'
        title = '结果回压风险'
        value = "rg 写出速率: $([string]$agg.rgIoWriteMBs) MB/s"
        status = if ($agg.rgIoWriteMBs -ge 18) { 'critical' } elseif ($agg.rgIoWriteMBs -ge 8) { 'warn' } else { 'ok' }
        reason = if ($agg.rgIoWriteMBs -ge 18) { '输出数据流过大，主进程解析/渲染可能跟不上。' } elseif ($agg.rgIoWriteMBs -ge 8) { '输出速率偏高，存在缓冲积压风险。' } else { '输出速率平稳。' }
        suggestion = '减少上下文行和冗余字段，限制单次返回条数并启用分页。'
    }

    return $items
}

while ($true) {
    $now = Get-Date
    $uptimeSec = [Math]::Round((New-TimeSpan -Start $startedAt -End $now).TotalSeconds, 1)

    $cim = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('rg.exe', 'searchcenter.exe', 'SearchCenterCore.exe') })
    $processRows = @()

    foreach ($p in $cim) {
        $pid = [int]$p.ProcessId
        $gp = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if (-not $gp) { continue }

        $cpuSeconds = [double]($gp | Select-Object -ExpandProperty CPU)
        if ($null -eq $cpuSeconds) { $cpuSeconds = 0.0 }

        $cpuPct = 0.0
        if ($cpuSnapshot.ContainsKey($pid)) {
            $prev = $cpuSnapshot[$pid]
            $deltaSec = ($now - $prev.time).TotalSeconds
            if ($deltaSec -gt 0) {
                $cpuPct = (($cpuSeconds - $prev.cpu) / $deltaSec) * 100.0 / $logicalCpu
            }
            if ($cpuPct -lt 0) { $cpuPct = 0 }
        }

        $cpuSnapshot[$pid] = [ordered]@{ cpu = $cpuSeconds; time = $now }

        $ioReadBytes = [double]$gp.IOReadBytes
        $ioWriteBytes = [double]$gp.IOWriteBytes
        $ioReadMBs = 0.0
        $ioWriteMBs = 0.0
        if ($ioSnapshot.ContainsKey($pid)) {
            $prevIo = $ioSnapshot[$pid]
            $deltaSecIo = ($now - $prevIo.time).TotalSeconds
            if ($deltaSecIo -gt 0) {
                $ioReadMBs = [Math]::Max(0, (($ioReadBytes - $prevIo.read) / 1MB) / $deltaSecIo)
                $ioWriteMBs = [Math]::Max(0, (($ioWriteBytes - $prevIo.write) / 1MB) / $deltaSecIo)
            }
        }
        $ioSnapshot[$pid] = [ordered]@{ read = $ioReadBytes; write = $ioWriteBytes; time = $now }

        $ageSec = 0
        if ($gp.StartTime) {
            $ageSec = [Math]::Round((New-TimeSpan -Start $gp.StartTime -End $now).TotalSeconds, 1)
        }

        $processRows += [ordered]@{
            pid = $pid
            name = $p.Name
            cpuPct = [Math]::Round($cpuPct, 2)
            workingSetMB = To-MB $gp.WorkingSet64
            privateMB = To-MB $p.PrivatePageCount
            ioReadMB = To-MB $gp.IOReadBytes
            ioWriteMB = To-MB $gp.IOWriteBytes
            ioReadMBs = [Math]::Round($ioReadMBs, 2)
            ioWriteMBs = [Math]::Round($ioWriteMBs, 2)
            ageSec = $ageSec
            commandLine = [string]$p.CommandLine
        }
    }

    $activePids = @($processRows | ForEach-Object { $_.pid })
    foreach ($k in @($cpuSnapshot.Keys)) {
        if ($activePids -notcontains $k) {
            $cpuSnapshot.Remove($k) | Out-Null
        }
    }
    foreach ($k in @($ioSnapshot.Keys)) {
        if ($activePids -notcontains $k) {
            $ioSnapshot.Remove($k) | Out-Null
        }
    }

    foreach ($row in $processRows) {
        if (-not $row.commandLine) { $row.commandLine = '' }
    }

    $rgRows = @($processRows | Where-Object { $_.name -eq 'rg.exe' })
    $scRows = @($processRows | Where-Object { $_.name -in @('searchcenter.exe', 'SearchCenterCore.exe') })

    $rgWithExclude = @($rgRows | Where-Object {
        $_.commandLine -match '(--glob|-g\s+|--ignore-file|--max-filesize|--max-columns)'
    }).Count
    $excludeRatio = if ($rgRows.Count -gt 0) { [Math]::Round(($rgWithExclude * 100.0) / $rgRows.Count, 0) } else { 100 }

    $current = [ordered]@{
        ts = $now.ToString('yyyy-MM-dd HH:mm:ss')
        uptimeSec = $uptimeSec
        rgCount = $rgRows.Count
        scCount = $scRows.Count
        rgMemMB = [Math]::Round((($rgRows | Measure-Object -Property workingSetMB -Sum).Sum), 2)
        scMemMB = [Math]::Round((($scRows | Measure-Object -Property workingSetMB -Sum).Sum), 2)
        rgCpuPct = [Math]::Round((($rgRows | Measure-Object -Property cpuPct -Sum).Sum), 2)
        scCpuPct = [Math]::Round((($scRows | Measure-Object -Property cpuPct -Sum).Sum), 2)
        rgIoWriteMBs = [Math]::Round((($rgRows | Measure-Object -Property ioWriteMBs -Sum).Sum), 2)
        rgIoReadMBs = [Math]::Round((($rgRows | Measure-Object -Property ioReadMBs -Sum).Sum), 2)
    }

    [void]$history.Add($current)
    while ($history.Count -gt $HistoryLimit) {
        $history.RemoveAt(0)
    }

    $checklist = Build-Checklist $current ([ordered]@{ excludeRatio = $excludeRatio })

    $payload = [ordered]@{
        generatedAt = $now.ToString('yyyy-MM-dd HH:mm:ss')
        intervalMs = $IntervalMs
        processSummary = $current
        checklist = $checklist
        processes = @($processRows | Sort-Object -Property @{Expression='cpuPct';Descending=$true}, @{Expression='workingSetMB';Descending=$true})
        history = @($history)
    }

    $json = $payload | ConvertTo-Json -Depth 8 -Compress
    $tmp = "$OutputPath.tmp"
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $OutputPath -Force

    Start-Sleep -Milliseconds $IntervalMs
}
