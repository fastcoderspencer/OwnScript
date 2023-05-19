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
Write-Host "��ǰ����Ŀ¼�Ѹ���Ϊ��$targetPath"



# ��ȡ GitHub �����°汾����Ϣ
$latestRelease = Invoke-RestMethod -Uri $releasesUrl

$latestVersion = $latestRelease.tag_name.Replace('v', '').Replace('V', '')
$latestVersionUrl = $latestRelease.assets[0].browser_download_url

# ��ȡ���� AList �İ汾��Ϣ
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
    $logStr = "github�汾Ϊ: $latestVersion��С�ڻ���ڱ��ذ汾�� $localVersion���ű��˳��������¡�"
    Write-Host $logStr
    Add-Content -Path $updateLogPath -Value ("�ű�ִ��ʱ�䣺{0}��{1}" -f (Get-Date -Format g), $logStr)
    exit 0
}



# ��ȡ���°汾��alist��Ϣ
$response = Invoke-WebRequest -Uri $releasesUrl | ConvertFrom-Json
$latestAlistUrl = $response.assets | Where-Object{$_.name -eq "alist-windows-386.zip"} | Select-Object -ExpandProperty browser_download_url


# �����ȡ����alist���������ӣ���ô�����ز��滻
if ($latestAlistUrl) {

    
    try {
        # ɾ��ԭ��������ļ�
        if (Test-Path -Path $alistTempAlistZip) {
            Remove-Item -Path $alistTempAlistZip
            Write-Host 'alistTempAlistZip �ļ�ɾ���ɹ�'
        }
        if (Test-Path -Path $alistTempAlistExe) {
            Remove-Item -Path $alistTempAlistExe
            Write-Host 'alistTempAlistExe �ļ�ɾ���ɹ�'
        }
        if (-not (Test-Path -Path $alistTempPath -PathType Container)) {
            New-Item -Path $alistTempPath -ItemType Directory | Out-Null
            Write-Host "��ʱ�ļ����Ѵ�����$alistTempPath"
        }



        # �������°汾��alist
        # ����ִ��һЩ���ܳ��ִ���Ĳ���
        Invoke-WebRequest -Uri $latestAlistUrl -OutFile $alistTempAlistZip -ErrorAction Stop

        # ��ѹ
        Expand-Archive $alistTempAlistZip -DestinationPath $alistTempPath

        # �ж��ļ��Ƿ����
        if (Test-Path -Path $alistTempAlistExe) {
            Write-Host "�ļ����ؽ�ѹ�ɹ�"

            # ֹͣAList����
            cscript //nologo $stopScriptPath

            # ��ͣ3��������ִ�У���ֹ����û��ȫֹͣ�޷�ɾ��ԭ���ļ�
            Write-Host "alist����ֹͣ��..."
            Start-Sleep -Seconds 3

            # ɾ���ϵ�alist
            if (Test-Path -Path $alistPath) {
                #Remove-Item -Path $alistPath -Verbose
                Remove-Item -Path $alistPath
                
                # copy �����ص�alist��ԭAlist��ַ
                Copy-Item $alistTempAlistExe $alistPath -Force

                # �������÷���
                cscript //nologo $startScriptPath
                Write-Host "�ű�ִ����ϣ�������alist����"
                
                # д�������־
                Add-Content -Path $updateLogPath -Value ("Alist was updated to version {0} at {1}" -f $response.tag_name, (Get-Date -Format g))

                # ɾ����ʱ�ļ�
                if (Test-Path -Path $alistTempPath -PathType Container) {
                    Remove-Item -Path $alistTempPath -Recurse -Force
                    Write-Host "��ʱ�ļ���ȫ��ɾ����$alistTempPath"
                }

                Write-Host "����alist��ϣ��ű��ɹ�ִ����ϣ�10����Զ��رմ˴���..."
                Start-Sleep -Seconds 10
            }

        } else {
            Write-Host "�����ļ��ļ���ѹʧ��"
        }


    }
    catch {
        # ������ִ��󣬲����������д���
        Write-Host "Caught an exception:"
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
    finally {
        # �����Ƿ���ִ��󣬶���ִ�д˿��еĴ���
        Write-Host "Finished."
    }

} else {
    Add-Content -Path $updateLogPath -Value ("Failed to update Alist at {0}, no downloadable asset found." -f (Get-Date -Format g))
}
