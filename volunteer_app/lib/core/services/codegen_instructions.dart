// 这里维护代码生成指令
// 按照项目结构，以下为运行代码生成的命令行指令

// Riverpod 代码生成 (需要运行的命令):
// dart run build_runner build

// 项目说明：
// 1. API 服务类位于 Features/API 目录
// 2. API 数据模型文件 (*.g.dart) 通过 riverpod_annotation 自动生成
// 3. 需要先安装相关依赖：
//    flutter pub add riverpod_annotation dio flutter_riverpod
//    flutter pub add dev:build_runner dev:riverpod_generator

// 激活 Riverpod 代码生成器 (首次使用):
// flutter pub global activate riverpod_generator

// 实时代码生成模式 (开发中实时监听变化):
// dart run build_runner watch

// 实时代码生成模式还可以指定特定文件监听:
// dart run build_runner watch --delete-conflicting-outputs

// 按需清理和重新生成 (如果文件被修改后生成器无法识别):
// dart run build_runner clean
// dart run build_runner build

// 文件结构说明:
// /lib/features/api/
//   ├── api_service.dart                  - API 服务类
//   ├── patient.g.dart                    - 患者相关生成文件
//   ├── medication.g.dart                 - 药品相关生成文件
//   ├── device.g.dart                    - 设备相关生成文件
//   ├── report.g.dart                    - 报告相关生成文件
//   ├── nursing_record.g.dart            - 护理记录相关生成文件
//   └── dose_package.g.dart             - 剂次包相关生成文件

// 如需添加新的数据模型或服务，请遵循以下步骤:
// 1. 在 api_service.dart 中添加新的服务类
// 2. 创建对应的 *.g.dart 文件 (如果使用了 @riverpod 注解)
// 3. 运行代码生成器
