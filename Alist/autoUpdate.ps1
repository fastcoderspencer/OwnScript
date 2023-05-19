$startScriptPath = "D:\AList\shell\startAList.vbs"
$stopScriptPath = "D:\AList\shell\stopAList.vbs"
$targetPath = "D:\AList"

$alistPath = "D:\AList\alist.exe"
$updateLogPath = "D:\AList\update.log"

$alistTempPath = "D:\AList\temp\"
$alistTempAlistZip = "D:\AList\temp\alist-windows-386.zip"
$alistTempAlistExe = "D:\AList\temp\alist.exe"

$releasesUrl = "https://api.github.com/repos/alist-org/alist/releases/latest"


Set-Location -Path $targetPath
Write-Host "当前工作目录已更改为：$targetPath"



# 获取 GitHub 上最新版本的信息
$latestRelease = Invoke-RestMethod -Uri $releasesUrl

$latestVersion = $latestRelease.tag_name.Replace('v', '').Replace('V', '')
$latestVersionUrl = $latestRelease.assets[0].browser_download_url

# 获取本地 AList 的版本信息
$commandOutput = Invoke-Expression ".\alist.exe version"
if ($null -eq $commandOutput) {
    Write-Host "Failed to get version information from alist.exe"
    exit 1
}

$versionOutput = $commandOutput | Out-String
if ($null -eq $versionOutput) {
    Write-Host "Failed to convert command output to string"
    exit 1
}


$localVersionLine = ($versionOutput -split "`n" | Select-String "Version:" -SimpleMatch)[-1].Line

if ($null -eq $localVersionLine) {
    Write-Host "Failed to find version line in command output"
    exit 1
}

$localVersion = $localVersionLine.Split(":")[1].Trim()


if ($latestVersion -le $localVersion) {
    $logStr = "github版本为: $latestVersion，小于或等于本地版本： $localVersion，脚本退出，不更新。"
    Write-Host $logStr
    Add-Content -Path $updateLogPath -Value ("脚本执行时间：{0}，{1}" -f (Get-Date -Format g), $logStr)
    exit 0
}



# 获取最新版本的alist信息
$response = Invoke-WebRequest -Uri $releasesUrl | ConvertFrom-Json
$latestAlistUrl = $response.assets | Where-Object{$_.name -eq "alist-windows-386.zip"} | Select-Object -ExpandProperty browser_download_url


# 如果获取到了alist的下载链接，那么就下载并替换
if ($latestAlistUrl) {

    
    try {
        # 删除原来缓存的文件
        if (Test-Path -Path $alistTempAlistZip) {
            Remove-Item -Path $alistTempAlistZip
            Write-Host 'alistTempAlistZip 文件删除成功'
        }
        if (Test-Path -Path $alistTempAlistExe) {
            Remove-Item -Path $alistTempAlistExe
            Write-Host 'alistTempAlistExe 文件删除成功'
        }
        if (-not (Test-Path -Path $alistTempPath -PathType Container)) {
            New-Item -Path $alistTempPath -ItemType Directory | Out-Null
            Write-Host "临时文件夹已创建：$alistTempPath"
        }



        # 下载最新版本的alist
        # 尝试执行一些可能出现错误的操作
        Invoke-WebRequest -Uri $latestAlistUrl -OutFile $alistTempAlistZip -ErrorAction Stop

        # 解压
        Expand-Archive $alistTempAlistZip -DestinationPath $alistTempPath

        # 判断文件是否存在
        if (Test-Path -Path $alistTempAlistExe) {
            Write-Host "文件下载解压成功"

            # 停止AList服务
            cscript //nologo $stopScriptPath

            # 暂停3秒再往下执行，防止服务没完全停止无法删除原有文件
            Write-Host "alist服务停止中..."
            Start-Sleep -Seconds 3

            # 删除老的alist
            if (Test-Path -Path $alistPath) {
                #Remove-Item -Path $alistPath -Verbose
                Remove-Item -Path $alistPath
                
                # copy 新下载的alist到原Alist地址
                Copy-Item $alistTempAlistExe $alistPath -Force

                # 重新启用服务
                cscript //nologo $startScriptPath
                Write-Host "脚本执行完毕，已重启alist服务"
                
                # 写入更新日志
                Add-Content -Path $updateLogPath -Value ("Alist was updated to version {0} at {1}" -f $response.tag_name, (Get-Date -Format g))

                # 删除临时文件
                if (Test-Path -Path $alistTempPath -PathType Container) {
                    Remove-Item -Path $alistTempPath -Recurse -Force
                    Write-Host "临时文件已全部删除：$alistTempPath"
                }

                Write-Host "重启alist完毕，脚本成功执行完毕，10秒后自动关闭此窗口..."
                Start-Sleep -Seconds 10
            }

        } else {
            Write-Host "下载文件文件解压失败"
        }


    }
    catch {
        # 如果出现错误，捕获它并进行处理
        Write-Host "Caught an exception:"
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
    finally {
        # 无论是否出现错误，都将执行此块中的代码
        Write-Host "Finished."
    }

} else {
    Add-Content -Path $updateLogPath -Value ("Failed to update Alist at {0}, no downloadable asset found." -f (Get-Date -Format g))
}
