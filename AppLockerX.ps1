#Requires -RunAsAdministrator

<#
.SYNOPSIS
    AppLockerのプロパティを設定するスクリプト（XML版）
.DESCRIPTION
    実行可能ファイルとパッケージアプリの規則を有効化します。
    既定の許可規則も含まれます。
.NOTES
    管理者権限が必要です。
    SKYSEA Client Viewからの配布を想定しています。
    戻り値: 0=成功、1=失敗
    【推奨版】確実に動作します

    <!-- 実行可能ファイルの規則 = Exe -->
<RuleCollection Type="Exe" EnforcementMode="Enabled">
  ↑ 画像の「実行可能ファイルの規則(E)」に対応
  ↑ 構成済み + 規則の実施 = Enabled

<!-- Windowsインストーラーの規則 = Msi -->
<RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  ↑ 画像の「Windowsインストーラーの規則(W)」に対応
  ↑ 構成なし = NotConfigured

<!-- スクリプトの規則 = Script -->
<RuleCollection Type="Script" EnforcementMode="NotConfigured" />
  ↑ 画像の「スクリプトの規則(S)」に対応
  ↑ 構成なし = NotConfigured

<!-- パッケージアプリの規則 = Appx -->
<RuleCollection Type="Appx" EnforcementMode="Enabled">
  ↑ 画像の「パッケージアプリの規則(P)」に対応
  ↑ 構成済み + 規則の実施 = Enabled
#>

try {
    # AppLockerサービスの状態確認と起動
    $appIdService = Get-Service -Name AppIDSvc -ErrorAction Stop
    
    if ($appIdService.Status -ne 'Running') {
        Set-Service -Name AppIDSvc -StartupType Automatic
        Start-Service -Name AppIDSvc
    }
    
    # AppLockerポリシーのXML定義
    $policyXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePublisherRule Id="a9e18c21-ff8f-43cf-b9fc-db40eed693ba" Name="すべての署名済みファイル" Description="すべてのユーザーに対してすべての署名済みファイルを許可する" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="*" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
    <FilePathRule Id="921cc481-6e17-4653-8f75-050b80acca20" Name="Program Files内のすべてのファイル" Description="すべてのユーザーが Program Files内のすべてのファイルを実行できる" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="a61c8b2c-a319-4cd0-9690-d2177cad7b51" Name="Windows フォルダー内のすべてのファイル" Description="すべてのユーザーが Windows フォルダー内のすべてのファイルを実行できる" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Script" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
    <FilePublisherRule Id="b7af7102-efde-4369-8a89-7a6a392d1473" Name="すべての署名済みパッケージ アプリ" Description="すべてのユーザーに対してすべての署名済みパッケージ アプリを許可する" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="*" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
</AppLockerPolicy>
"@
    
    # 一時ファイルに保存
    $tempFile = [System.IO.Path]::GetTempFileName()
    $policyXml | Out-File -FilePath $tempFile -Encoding UTF8
    
    # ポリシーを適用
    Set-AppLockerPolicy -XmlPolicy $tempFile -ErrorAction Stop
    
    # 一時ファイルを削除
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    
    # 成功
    exit 0
    
} catch {
    # 失敗
    exit 1
}