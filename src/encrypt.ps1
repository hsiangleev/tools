# 文件不要超过20MB，最好加密文本文件
# 使用powershell运行程序，并隐藏窗口
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 新建证书后缀
$certNameExtension = "_custom"

# 生成证书
function createCert ($opts) {
    $cName = $opts[0]
    $certName = $cName + $certNameExtension
    $password = $opts[1]
    
    New-Item -ItemType File -Name "$certName.inf" -Value "
    [Version]
    Signature = `"`$Windows NT`$`"
    
    [Strings]
    szOID_ENHANCED_KEY_USAGE = `"2.5.29.37`"
    szOID_DOCUMENT_ENCRYPTION = `"1.3.6.1.4.1.311.80.1`"
    
    [NewRequest]
    Subject = `"cn=$certName`"
    MachineKeySet = false
    KeyLength = 2048
    KeySpec = AT_KEYEXCHANGE
    HashAlgorithm = Sha1
    Exportable = true
    RequestType = Cert
    EncryptionAlgorithm = 3des
    EncryptionLength = 512
    KeyUsage = `"CERT_KEY_ENCIPHERMENT_KEY_USAGE | CERT_DATA_ENCIPHERMENT_KEY_USAGE`"
    ValidityPeriod = `"Years`"
    ValidityPeriodUnits = `"1000`"
    
    [Extensions]
    %szOID_ENHANCED_KEY_USAGE% = `"{text}%szOID_DOCUMENT_ENCRYPTION%`"
    "
    
    certreq.exe -new "$certName.inf" "$certName.cer"

    $Thumbprint = Get-ChildItem -Path "Cert:\CurrentUser\My" -DocumentEncryptionCert | Where-Object {$_.Subject -eq "cn=$certName"} | ForEach-Object{$_.Thumbprint}
    Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$Thumbprint" -FilePath "~\Desktop\$cName.pfx" -Password (ConvertTo-SecureString -AsPlainText $password -Force)
    Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -eq "cn=$certName"} | Remove-Item
    Remove-Item -Path "$certName.inf"
    Remove-Item -Path "$certName.cer"
}

$form = New-Object Windows.Forms.Form -Property @{
    StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    Size          = '500, 600'
    Text          = '加密'
    # Topmost       = $true
}

$req = New-Object Windows.Forms.GroupBox -Property @{
    Location      = '40, 25'
    Size          = '400, 500'
    Text          = '加密'
}

# 生成证书
$selName1 = New-Object Windows.Forms.Label -Property @{
    Location      = '10, 20'
    Size          = '80, 30'
    Text          = '生成证书'
}
# 如果只有一个证书，则默认获取该证书
$cert = Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -match $certNameExtension}
$certDefaultValue = ""
if($cert.length -eq 1){
    $matchStr = "CN=([\w|\W]+)$certNameExtension"
    $certDefaultValue = ([regex]$matchStr).Match($cert[0].Subject).Groups[1].Value
}
$selValue11 = New-Object Windows.Forms.TextBox -Property @{
    Location      = '100, 15'
    Size          = '100, 50'
    PlaceholderText = "请输入证书名称"
    Text            = $certDefaultValue
}
$selValue12 = New-Object Windows.Forms.TextBox -Property @{
    Location      = '205, 15'
    Size          = '100, 50'
    PasswordChar  = '*'
    PlaceholderText = "请输入证书密码"
}
$selValue13 = New-Object Windows.Forms.Button -Property @{
    Location      = '310, 15'
    Size          = '80, 20'
    Text          = '生成证书'
}
$selValue13.Add_Click({
    try {
        if([String]::IsNullOrEmpty($selValue11.Text)){throw "证书名称不能为空"}
        if([String]::IsNullOrEmpty($selValue12.Text)){throw "证书密码不能为空"}
        $certName = $selValue11.Text + $certNameExtension
        $cert = Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -eq "cn=$certName"}
        if($cert.length -gt 0){throw "该证书已存在，请修改证书名称"}
        createCert($selValue11.Text, $selValue12.Text)
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})


# 文件加密
$selName2 = New-Object Windows.Forms.Label -Property @{
    Location      = '10, 50'
    Size          = '80, 30'
    Text          = '文件加密'
}
$selValue21 = New-Object Windows.Forms.TextBox -Property @{
    Location      = '100, 45'
    Size          = '160, 50'
    PlaceholderText = "请输入文件路径"
}
$selValue22 = New-Object Windows.Forms.Button -Property @{
    Location      = '265, 45'
    Size          = '40, 20'
    Text          = '文件'
}
$selValue22.Add_Click({
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.ShowDialog()
    $selValue21.Text = $FileBrowser.FileName
})
$selValue23 = New-Object Windows.Forms.Button -Property @{
    Location      = '310, 45'
    Size          = '80, 20'
    Text          = '加密'
}
function ConvertTo-Base64 {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline, Position=0)]
        [string] $String
    )

    [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($String), 'InsertLineBreaks')
}
function ConvertFrom-Base64 {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline, Position=0)]
        [string] $String
    )

    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($String))
}
$selValue23.Add_Click({
    try {
        $path = $selValue21.Text
        if([String]::IsNullOrEmpty($selValue11.Text)){throw "证书名称不能为空"}
        elseif([String]::IsNullOrEmpty($path)){throw "文件路径不能为空"}
        elseif([System.IO.File]::Exists($path) -eq $false){throw "文件不存在"}
        $certName = $selValue11.Text + $certNameExtension
        $fileAttr = Get-Item -Path $path
        $encryptFilePath = $fileAttr.DirectoryName + "\Encrypt_" + $fileAttr.Name
        # 先base64加密
        $File = [System.IO.File]::ReadAllBytes($path)
        $Base64 = [System.Convert]::ToBase64String($File)
        $Base64 | Protect-CmsMessage -To $certName | Out-File -FilePath $encryptFilePath
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})

# 文件解密
$selName3 = New-Object Windows.Forms.Label -Property @{
    Location      = '10, 80'
    Size          = '80, 30'
    Text          = '文件解密'
}
$selValue31 = New-Object Windows.Forms.TextBox -Property @{
    Location      = '100, 75'
    Size          = '160, 50'
    PlaceholderText = "请输入文件路径"
}
$selValue32 = New-Object Windows.Forms.Button -Property @{
    Location      = '265, 75'
    Size          = '40, 20'
    Text          = '文件'
}
$selValue32.Add_Click({
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.ShowDialog()
    $selValue31.Text = $FileBrowser.FileName
})
$selValue33 = New-Object Windows.Forms.Button -Property @{
    Location      = '310, 75'
    Size          = '80, 20'
    Text          = '解密'
}
$selValue33.Add_Click({
    try {
        $path = $selValue31.Text
        if([String]::IsNullOrEmpty($selValue11.Text)){throw "证书名称不能为空"}
        elseif([String]::IsNullOrEmpty($path)){throw "文件路径不能为空"}
        elseif([System.IO.File]::Exists($path) -eq $false){throw "文件不存在"}

        $certName = $selValue11.Text + $certNameExtension

        $fileAttr = Get-Item -Path $path
        $dateTime = Get-Date -Format 'yyyyMMddHHmmss'
        $fileName = $dateTime + $fileAttr.Extension

        function create_file([string]$encryptFilePath) {
            $Base64 = Get-Content -Path $path | Unprotect-CmsMessage -To $certName
            $ByteStream = [System.Convert]::FromBase64String($Base64)
            [System.IO.File]::WriteAllBytes($encryptFilePath, $ByteStream)
        }

        # 不能预览，直接导出的文件
        if($fileAttr.Extension -in @('.exe','.zip','.rar')) {
            $encryptFilePath = $fileAttr.DirectoryName + "\" + ($fileAttr.Name -replace "^Encrypt_","Decode_")
            create_file($encryptFilePath)
            return
        }

        # 直接预览，并修改的文件
        $encryptFilePath = "C:\Users\$env:UserName\AppData\Local\Temp\$fileName"        # 临时文件存放位置
        create_file($encryptFilePath)
        if($fileAttr.Extension -in @('.docx','.xlsx','.pptx','.csv','.gif')){
            Invoke-Item -Path $encryptFilePath        # 默认方式打开
        }elseif($fileAttr.Extension -in @('.jpg','.png')){
            mspaint.exe $encryptFilePath      # 画图工具打开
        }else{
            notepad $encryptFilePath          # 记事本打开
        }
        # 判断文件是否已经打开
        $isOpen = $false
        while ($isOpen -eq $false) {
            Start-Sleep -Milliseconds 200
            try {
                if ((get-Process | where-Object {$_.mainWindowTitle -match ".*$dateTime.*"}).length -gt 0){
                    $isOpen = $true
                    # 判断文件是否关闭，关闭之后重新保存
                    $isStart = $true
                    while ($isStart) {
                        Start-Sleep -Milliseconds 200
                        try {
                            if ((get-Process | where-Object {$_.mainWindowTitle -match ".*$dateTime.*"}).length -eq 0){
                                $isStart = $false
                                $File = [System.IO.File]::ReadAllBytes($encryptFilePath)
                                $Base64 = [System.Convert]::ToBase64String($File)
                                $Base64 | Protect-CmsMessage -To $certName | Out-File -FilePath $path
                                Remove-Item -Path $encryptFilePath
                            }
                        }
                        catch {}
                    }
                }
            }
            catch {}
        }
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})

$okButton = New-Object Windows.Forms.Button -Property @{
    Location      = "100,470"
    Size          = '75, 23'
    Text          = '查看证书'
}
$delButton = New-Object Windows.Forms.Button -Property @{
    Location      = "180,470"
    Size          = '75, 23'
    Text          = '删除证书'
}
$allButton = New-Object Windows.Forms.Button -Property @{
    Location      = "260,470"
    Size          = '75, 23'
    Text          = '所有证书'
}

$okButton.Add_Click({
    try {
        if([String]::IsNullOrEmpty($selValue11.Text)){throw "证书名称不能为空"}
        $certName = $selValue11.Text + $certNameExtension
        $cert = Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -eq "cn=$certName"}
        if($cert.length -eq 0){throw "没有该证书"}
        $matchStr = "CN=([\w|\W]+)$certNameExtension"
        $arr=@()
        $cert | ForEach-Object {
            $arr += @(
                [PSCustomObject]@{
                    Name = ([regex]$matchStr).Match($_.Subject).Groups[1].Value
                    Thumbprint = $_.Thumbprint
                    NotAfter = $_.NotAfter
                    PSPath = $_.PSPath
                }
            )
        }
        $arr | Out-GridView
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})
$delButton.Add_Click({
    try {
        $text = $selValue11.Text
        if([String]::IsNullOrEmpty($text)){throw "证书名称不能为空"}
        $certName = $text + $certNameExtension
        $result = (New-Object -ComObject WScript.Shell).popup("确定删除证书`"$text`"？",0,"msg",1 + 32)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK)
        {
            Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -eq "cn=$certName"} | Remove-Item
            throw "删除成功"
        }
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})
$allButton.Add_Click({
    try {
        $cert = Get-ChildItem "Cert:\CurrentUser\" -DocumentEncryptionCert -Recurse | Where-Object {$_.Subject -match $certNameExtension}
        if($cert.length -eq 0){throw "当前没有创建证书"}

        $matchStr = "CN=([\w|\W]+)$certNameExtension"
        $arr=@()
        $cert | ForEach-Object {
            $arr += @(
                [PSCustomObject]@{
                    Name = ([regex]$matchStr).Match($_.Subject).Groups[1].Value
                    Thumbprint = $_.Thumbprint
                    NotAfter = $_.NotAfter
                    PSPath = $_.PSPath
                }
            )
        }
        $arr | Out-GridView
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
})

$req.Controls.AddRange(@(
    $selName1, $selValue11, $selValue12, $selValue13,
    $selName2, $selValue21, $selValue21, $selValue22, $selValue23,
    $selName3, $selValue31, $selValue31, $selValue32, $selValue33,
    $okButton, $delButton, $allButton
))

$form.Controls.Add($req)
$form.ShowDialog()
