# 配置方法

## 龙芯实验环境

将实验环境的 `myCPU` 设置为本仓库的 `myCPU` 的符号链接，并用本仓库中 `soc_axi` 的内容覆盖实验环境中的 `mycpu_env/soc_axi`。在 Vivado 项目中添加 `myCPU` 中的源文件和 IP 核。

## chiplab

参考 [Chiplab用户手册](https://chiplab.readthedocs.io/zh/latest/Quick-Start.html) 完成配置，将 `IP/myCPU` 设置为本仓库的 `myCPU` 的符号链接。注意设置 `chip/config-generator.mak` 中的 `CPU_2CMT` 为 `y`。