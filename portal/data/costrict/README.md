# 签名工具使用说明

## 用途

签名工具用于对costrict相关的包文件进行数字签名，确保文件的完整性和安全性。签名后的文件可以被验证为未被篡改，保证系统运行时使用的是可信的文件。

## 功能特点

- 自动识别符合`package/os/arch/ver`结构的包目录
- 支持多种操作系统（Windows、Linux、Darwin）和架构（amd64、arm64）
- 提供命令行参数定制签名过程
- 完整的帮助文档和示例

## 目录结构

```
costrict/
├── build-packages.sh         # 原始bash构建脚本
├── costrict-private.pem      # 签名私钥文件
├── package-defs.json         # 包定义文件
├── packages.json             # 包列表文件
├── resign-packages.ps1       # PowerShell签名脚本（推荐使用）
├── smc.exe                   # 签名工具主程序
└── README.md                 # 本文档
```

## 签名工具依赖

- `smc.exe`：签名工具主程序，负责实际的签名操作
- `costrict-private.pem`：签名私钥，用于生成数字签名
- `package-defs.json`：包定义文件，包含包的基本信息

## PowerShell签名脚本使用方法

### 基本用法

```powershell
# 使用默认配置签名所有包
powershell.exe -ExecutionPolicy Bypass -File .\resign-packages.ps1
```

### 命令行参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `-Help` | 显示帮助信息 | 无 |
| `-Key` | 指定私钥文件路径 | `costrict-private.pem` |
| `-Defs` | 指定包定义文件路径 | `package-defs.json` |
| `-Smc` | 指定smc.exe文件路径 | `smc.exe` |

### 示例

```powershell
# 显示帮助信息
powershell.exe -ExecutionPolicy Bypass -File .\resign-packages.ps1 -Help

# 使用自定义私钥和定义文件
powershell.exe -ExecutionPolicy Bypass -File .\resign-packages.ps1 -Key "custom-key.pem" -Defs "custom-defs.json"

# 使用自定义smc路径
powershell.exe -ExecutionPolicy Bypass -File .\resign-packages.ps1 -Smc "D:\path\to\smc.exe"
```

## package-defs.json格式

包定义文件包含所有需要签名的包的基本信息，格式如下：

```json
{
  "packages": [
    {
      "name": "package-name",
      "version": "1.0.0",
      "type": "exec",
      "description": "包描述信息"
    }
  ]
}
```

### 字段说明

- `name`：包名称
- `version`：包版本号
- `type`：包类型（如`exec`、`config`等）
- `description`：包描述信息

## 签名过程

1. 脚本扫描当前目录下所有符合`package/os/arch/ver`结构的目录
2. 对每个目录下除`package.json`外的所有文件进行签名
3. 使用指定的私钥生成数字签名
4. 生成包含签名信息的`package.json`文件

## 签名验证

签名后的文件会生成对应的`package.json`文件，包含签名信息。系统可以通过验证签名确保文件的完整性。

## 注意事项

1. 私钥文件（costrict-private.pem）必须妥善保管，避免泄露
2. 签名操作需要在具有足够权限的环境中执行
3. 确保所有要签名的包都已正确配置在package-defs.json中
4. 签名后的文件不应再被修改，否则签名验证会失败

## 故障排除

### 脚本无法执行
- 确保PowerShell执行策略已正确设置：`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- 检查脚本路径是否正确

### 签名失败
- 检查私钥文件是否存在且有效
- 确保smc.exe文件路径正确
- 检查包定义文件格式是否正确
- 确保要签名的文件存在且可访问

## 最佳实践

1. 在修改任何包文件后重新签名
2. 定期备份私钥文件
3. 使用版本控制管理包定义文件
4. 在部署前验证签名的有效性

## 联系信息

如有任何问题或建议，请联系系统管理员。