# 上传文件需要powershell7，使用form-data类型，content有则格式为json，并且上传文件名不能含中文

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
Add-Type -AssemblyName System.Web

function ajax ($options) {
    $agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.83 Safari/537.36 Edg/85.0.564.44'
    $url = $options[0]
    $type = $options[1]
    $contentType = $options[2]
    $cookie = $options[3]
    $body = $options[4]
    $headers = $options[5]
    $form = $options[6]
    function getCookie ($cookie) {
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        if($cookie -eq ""){
            return $session
        }
        foreach ($a in $cookie.split(";")){
            $cookie = New-Object System.Net.Cookie
            $arr = $a.split("=")
            $cookie.Name = $arr[0].Replace(" ", "")
            $cookie.Value = $arr[1]
            $cookie.Domain = ([uri]$url).Host
            $session.Cookies.Add($cookie)
        }
        return $session
    }
    $session = getCookie($cookie)

    if($form -eq ""){
        if($type -eq 'GET'){
            if([String]::IsNullOrEmpty($body) -eq $false){
                $querystring = ConvertTo-QueryString -data ($body | ConvertFrom-Json)
                if($url -match '\?'){$url = $url + "&"}
                else{$url = $url + "?"}
                $url = $url + $querystring
            }
            $res = Invoke-WebRequest -Uri $url -Method 'GET' -WebSession $session -UserAgent $agent -Headers $headers
        }else{
            $res = Invoke-WebRequest -Uri $url -ContentType $contentType -Method $type -Body $body -WebSession $session -UserAgent $agent -Headers $headers
        }
    }else{
        $res = Invoke-WebRequest -Uri $url -ContentType $contentType -Method $type -WebSession $session -UserAgent $agent -Headers $headers -Form $form
    }

    
    return $res
}
# 换行形式的格式转哈希
function convertHashTable ($json) {
    $k = @{}
    if($json -ne ""){
        $json = $json.split("`n")
        for($i=0;$i -lt $json.count;$i++){
            $arr = $json[$i].split(":")
            $val = $json[$i].ToString().Replace($arr[0]+":", "")
            $k.Add($arr[0], $val)
        }
    }
    return $k   
}
# 换行形式的格式转哈希
function convertFormHashTable ($json) {
    # Write-Error $i;
    $k = @{}
    $filePath = $fileBox.Text
    
    if($filePath -eq ""){
        Write-Error "file path not null"
    }
    $arr = ConvertFrom-Json($json)
    foreach( $property in $arr.psobject.properties.name )
    {
        $k[$property] = $arr.$property
    }
    $k.Add("file", (Get-Item -Path $filePath))
    return $k   
}
# 格式化json缩进
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | ForEach-Object {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            $indent++
        }
        $line
    }) -Join "`n"
}

function ConvertTo-QueryString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $data,
        # URL encode parameter names
        [Parameter(Mandatory = $false)]
        [switch] $EncodeParameterNames
    )

    process {
        foreach ($InputObject in $data) {
            $QueryString = New-Object System.Text.StringBuilder
            if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary] -or $InputObject.GetType().FullName.StartsWith('System.Collections.Generic.Dictionary')) {
                foreach ($Item in $InputObject.GetEnumerator()) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    [string] $ParameterName = $Item.Key
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($Item.Value))
                }
            }
            elseif ($InputObject -is [object] -and $InputObject -isnot [ValueType]) {
                foreach ($Item in ($InputObject | Get-Member -MemberType Property, NoteProperty)) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    [string] $ParameterName = $Item.Name
                    if ($EncodeParameterNames) { $ParameterName = [System.Net.WebUtility]::UrlEncode($ParameterName) }
                    [void]$QueryString.AppendFormat('{0}={1}', $ParameterName, [System.Net.WebUtility]::UrlEncode($InputObject.($Item.Name)))
                }
            }
            else {
                ## Non-Terminating Error
                $Exception = New-Object ArgumentException -ArgumentList ('Cannot convert input of type {0} to query string.' -f $InputObject.GetType())
                Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::ParserError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConvertQueryStringFailureTypeNotSupported' -TargetObject $InputObject
                continue
            }

            Write-Output $QueryString.ToString()
        }
    }
}

function drawLabel ($options) {
    $label = New-Object System.Windows.Forms.Label
    $label.Location = $options[0]
    $label.Size = $options[1]
    $label.Text = $options[2]
    return $label
}
function drawRichText ($options) {
    $RichTextBox = New-Object System.Windows.Forms.RichTextBox
    $RichTextBox.Location = $options[0]
    $RichTextBox.Size = $options[1]
    return $RichTextBox
}
function drawRadioButton ($options) {
    $RadioButton = New-Object System.Windows.Forms.RadioButton
    $RadioButton.Location = $options[0]
    $RadioButton.size = $options[1]
    $RadioButton.Text = $options[2]
    $RadioButton.Checked = $options[3] 
    $RadioButton.Name = $options[4] 
    return $RadioButton
}
function drawGroupBox ($options) {
    $GroupBox = New-Object System.Windows.Forms.GroupBox
    $GroupBox.Location = $options[0]
    $GroupBox.size = $options[1]
    $GroupBox.text = $options[2]
    return $GroupBox
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'http request'
$form.Size = '1000,600'
$form.StartPosition = 'CenterScreen'

$req = drawGroupBox('30,15', '450,500', "request")

# url
$urlLabel = drawLabel("15,30", "80,30", 'url')
$urlBox = New-Object System.Windows.Forms.TextBox
$urlBox.Location = "120,30"
$urlBox.Size = "300,30"

# methods
$methodLabel = drawLabel("15,80", "80,30", 'methods')

$groupMethods = drawGroupBox('120,60', '300,40', "")
$methodRadio1 = drawRadioButton('15,10', '50,20', "get", $true, "methods")
$methodRadio2 = drawRadioButton('70,10', '50,20', "post", $false, "methods")
$methodRadio3 = drawRadioButton('135,10', '50,20', "put", $false, "methods")
$methodRadio4 = drawRadioButton('200,10', '70,20', "delete", $false, "methods")
$groupMethods.Controls.AddRange(@($methodRadio1, $methodRadio2, $methodRadio3, $methodRadio4))

# contentType
$contentTypeLabel = drawLabel("15,120", "80,30", 'contentType')

$groupContentType = drawGroupBox('120,110', '300,40', "")
$contentTypeRadio2 = drawRadioButton('15,10', '50,20', "json", $true, "contentType")
$contentTypeRadio1 = drawRadioButton('70,10', '110,20', "form-urlencoded", $false, "contentType")
$contentTypeRadio3 = drawRadioButton('185,10', '100,20', "form-data", $false, "contentType")
$groupContentType.Controls.AddRange(@($contentTypeRadio1, $contentTypeRadio2, $contentTypeRadio3))

# header
$headerLabel = drawLabel("15,160", "80,30", 'header')
$headerBox = drawRichText("120,160", "300,60")

# cookie
$cookieLabel = drawLabel("15,240", "80,30", 'cookie')
$cookieBox = drawRichText("120,240", "300,60")

# content
$contentLabel = drawLabel("15,320", "80,30", 'content')
$contentBox = drawRichText("120,320", "300,100")

# file
$fileLabel = drawLabel("15,440", "80,30", 'file')
$fileBox = New-Object System.Windows.Forms.TextBox
$fileBox.Location = "120,440"
$fileBox.Size = "240,30"
$fileBox.ReadOnly = $true
$fileButton = New-Object System.Windows.Forms.Button
$fileButton.Location = "365,440"
$fileButton.Size = "55,23"
$fileButton.Text = 'upload'

# button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = "120,470"
$okButton.Size = "75,23"
$okButton.Text = 'submit'
$req.Controls.AddRange(@($urlLabel,$urlBox,$methodLabel, $groupMethods, $contentTypeLabel, $groupContentType ,$cookieLabel,$cookieBox,$contentLabel,$contentBox,$okButton, $headerLabel,$headerBox,$fileLabel,$fileBox,$fileButton))
$form.Controls.Add($req)

$fileButton.Add_Click({
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop') 
        #Filter = 'Documents (*.docx)|*.docx|SpreadSheet (*.xlsx)|*.xlsx|*.txt'
    }
    $FileBrowser.ShowDialog()
    $fileBox.Text = $FileBrowser.FileName
})

$okButton.Add_Click({
    try {
        $url = $urlBox.Text
        $headers = $headerBox.Text
        $cookie = $cookieBox.Text
        $body = $contentBox.Text
        $form = ""
        if($methodRadio1.Checked -eq $true){$type = "GET"}
        elseif($methodRadio2.Checked -eq $true){$type = "POST"}
        elseif($methodRadio3.Checked -eq $true){$type = "PUT"}
        elseif($methodRadio4.Checked -eq $true){$type = "DELETE"}
        if($contentTypeRadio2.Checked -eq $true){$contentType = "application/json; charset=UTF-8"}
        elseif($contentTypeRadio1.Checked -eq $true){$contentType = "application/x-www-form-urlencoded; charset=UTF-8"}
        else{$contentType = "multipart/form-data; charset=UTF-8";$form = convertFormHashTable($body);$body=""}
        $headers = convertHashTable($headers)

        $res = ajax($url, $type, $contentType, $cookie, $body, $headers,$form)
        $resHBox.text = ConvertTo-Json($res.Headers)
    }
    catch {
        (New-Object -ComObject WScript.Shell).popup($PSItem.ToString(),0,"msg",0 + 48)
        return
    }
    $resContentBox.text = ""
    start-sleep -Milliseconds 500
    try {
        $resContentBox.text = ConvertFrom-Json($res.Content) | ConvertTo-Json -Depth 10 | Format-Json
    }
    catch {
        $resContentBox.text = $res.Content
    }
})

# response
$res = drawGroupBox('500,15', '450,500', "response")

# header
$resHLabel = drawLabel("15,30", "80,30", 'header')
$resHBox = drawRichText("120,30", "300,120")

# data
$resContentLabel = drawLabel("15,180", "80,30", 'data')
$resContentBox = drawRichText("120,180", "300,300")

$res.Controls.AddRange(@($resHLabel,$resHBox,$resContentLabel,$resContentBox))
$form.Controls.Add($res)

# $form.Topmost = $true
# $form.Add_Shown({$textBox.Select()})
$form.ShowDialog()