# ADDomainInventory

ADDomainInventory は、Active Directory 環境における **ドメインコントローラ（DC）** と **メンバPC** のインベントリ情報を収集する PowerShell モジュールです。

## 主な機能

- DC 情報の収集
  - OS/ハードウェア情報
  - FSMO / サイト / 役割
  - レプリケーション状態・失敗情報
  - GPO 一覧
  - SYSVOL サイズ
  - DNS ゾーン
  - AD 関連サービスの稼働状態

- メンバPC 情報の収集
  - OS バージョン
  - インストール済みアプリケーション
  - 適用済み HotFix
  - ローカルユーザ / グループ / 管理者権限状態

## インストール

```powershell
Install-Module -Name ADDomainInventory -Scope CurrentUser
