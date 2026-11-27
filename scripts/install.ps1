try {
    $ErrorActionPreference = 'Stop'
    $here = $PSScriptRoot
    $repo = Split-Path $here -Parent
    $source = Join-Path $repo 'rime'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'keytao.schema.yaml') -PathType Leaf)) {
        throw '缺少方案文件 keytao.schema.yaml。'
    }

    if ((Test-Path -LiteralPath (Join-Path $repo '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
        $env:GIT_TERMINAL_PROMPT = '0'
        git -C $repo pull --ff-only
        if ($LASTEXITCODE -ne 0) { Write-Warning '仓库更新失败，继续安装。' }
    }

    $rime = (Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -Name RimeUserDir -ErrorAction SilentlyContinue).RimeUserDir
    if (-not $rime) { $rime = Join-Path $env:APPDATA 'Rime' }
    if ($rime.Length -gt 3) { $rime = $rime.TrimEnd('\') }
    $weaselRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Rime\Weasel' -Name WeaselRoot -ErrorAction SilentlyContinue).WeaselRoot
    if (-not $weaselRoot) {
        $weaselRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel' -Name WeaselRoot -ErrorAction SilentlyContinue).WeaselRoot
    }
    $backup = Join-Path $here '备份'
    if ($rime -and $backup) {
        $rimePath = [IO.Path]::GetFullPath($rime).TrimEnd('\') + '\'
        $backupPath = [IO.Path]::GetFullPath($backup).TrimEnd('\') + '\'
        $comparison = [StringComparison]::OrdinalIgnoreCase
        if ($rimePath.StartsWith($backupPath, $comparison) -or $backupPath.StartsWith($rimePath, $comparison)) {
            throw 'Rime 目录与备份目录重叠，安装已停止。'
        }
    }

    $stopped = $false
    if ($weaselRoot) {
        Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
        $stopped = $true
    }

    try {
        if ((Test-Path -LiteralPath $rime -PathType Container) -and (Get-ChildItem -LiteralPath $rime -Force | Select-Object -First 1)) {
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
            robocopy $rime $backup /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1
            if ($LASTEXITCODE -ge 8) { throw "Rime 备份失败（退出码 $LASTEXITCODE）。" }
            Write-Host "已备份至：$backup"
        }

        $userFiles = 'default.custom.yaml', 'keytao.user.dict.yaml', 'keytao.extended.dict.yaml', 'keytao-dz.extended.dict.yaml'
        [IO.Directory]::CreateDirectory($rime) | Out-Null
        robocopy $source $rime /E /XF @userFiles /NFL /NDL /NJH /NJS /NP /R:1 /W:1
        if ($LASTEXITCODE -ge 8) { throw "安装失败（退出码 $LASTEXITCODE）。" }
        foreach ($name in $userFiles) {
            $destination = Join-Path $rime $name
            if (-not (Test-Path -LiteralPath $destination)) {
                $original = Join-Path $source $name
                if (Test-Path -LiteralPath $original -PathType Leaf) {
                    Copy-Item -LiteralPath $original -Destination $destination
                }
            }
        }
        Remove-Item -LiteralPath (Join-Path $rime 'keytao.dict.yaml'), (Join-Path $rime 'keytao-dz.dict.yaml') -ErrorAction SilentlyContinue

        $custom = Join-Path $rime 'default.custom.yaml'
        if ((Test-Path -LiteralPath $custom -PathType Leaf) -and
            -not (Select-String -LiteralPath $custom -Pattern '^\s*-\s+schema:\s+keytao(?:\s+#.*)?\s*$' -CaseSensitive -Quiet)) {
            Write-Warning '请在 default.custom.yaml 的 schema_list 下添加 "- schema: keytao"。'
        }
    } catch {
        if ($stopped) {
            $server = Join-Path $weaselRoot 'WeaselServer.exe'
            Start-Process -FilePath $server -WorkingDirectory $weaselRoot -ErrorAction SilentlyContinue
        }
        throw
    }

    try {
        if ($weaselRoot) { $deployer = Join-Path $weaselRoot 'WeaselDeployer.exe' }
        if ($weaselRoot -and (Test-Path -LiteralPath $deployer -PathType Leaf)) {
            $deployment = Start-Process -FilePath $deployer -ArgumentList '/deploy' -Wait -PassThru
            if ($deployment.ExitCode -ne 0) {
                Write-Warning "部署失败（退出码 $($deployment.ExitCode)），请在小狼毫中重新部署。"
            }
        } else {
            Write-Host '请在小狼毫中手动重新部署。'
        }
    } catch {
        Write-Warning '部署失败，请在小狼毫中重新部署。'
    }
    if ($weaselRoot) {
        try {
            $server = Join-Path $weaselRoot 'WeaselServer.exe'
            if (Test-Path -LiteralPath $server -PathType Leaf) {
                Start-Process -FilePath $server -WorkingDirectory $weaselRoot
            }
        } catch {
            Write-Warning '请手动启动小狼毫。'
        }
    }

    Write-Host "已更新 Rime 目录：$rime"
    Read-Host '按回车键退出' | Out-Null
} catch {
    Write-Host "安装失败：$($_.Exception.Message)" -ForegroundColor Red
    Read-Host '按回车键退出' | Out-Null
    exit 1
}
