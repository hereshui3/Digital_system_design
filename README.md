<div align="center">

# Digital System Design / 数字系统设计

**XJTU 数字系统设计课程实验合集**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Language: Verilog](https://img.shields.io/badge/Language-Verilog-blue)](https://en.wikipedia.org/wiki/Verilog)
[![Platform: EGO1 FPGA](https://img.shields.io/badge/Platform-EGO1%20FPGA-green)](https://www.xilinx.com)

基于 Verilog 的数字逻辑设计实验，运行于 Xilinx EGO1 FPGA 开发板。

</div>

---

## 目录 / Table of Contents

- [中文说明](#中文说明)
  - [简介](#简介)
  - [项目列表](#项目列表)
  - [开发环境](#开发环境)
  - [许可证](#许可证)
- [English](#english)
  - [Introduction](#introduction)
  - [Projects](#projects)
  - [Development Environment](#development-environment)
  - [License](#license)

---

# 中文说明

## 简介

本项目是西安交通大学（XJTU）数字系统设计课程的实验项目合集。所有设计均使用 **Verilog HDL** 编写，在 **Xilinx EGO1 FPGA 开发板**上验证通过。

实验从基础的数字逻辑单元开始（比较器、加法器、编码器），逐步深入到时序逻辑（呼吸灯、秒表、抢答器、交通灯），最终完成了一个完整的 **VGA 跑酷游戏**，综合运用了 FPGA 设计的多种核心技术。

## 项目列表

| # | 项目 | 类别 | 说明 | 难度 |
|---|------|------|------|------|
| 1 | **Comparator** (比较器) | 运算电路 | 2-bit 比较器，比较两个 2-bit 输入，输出大于/小于/等于标志 | ⭐ |
| 2 | **Full Adder** (全加器) | 运算电路 | 1-bit 全加器，支持进位输入/输出 | ⭐ |
| 3 | **expe2** (编码器) | 编码电路 | 4-to-2 编码器，将 4-bit 输入编码为 2-bit 输出 | ⭐ |
| 4 | **LED** (LED控制) | 时序逻辑 | 1秒交替闪烁 LED 控制（模块名 display_7seg，实际驱动 2 个 LED） | ⭐ |
| 5 | **Breath LED** (呼吸灯) | PWM 控制 | 基于 PWM 的呼吸灯，LED 亮度平滑呼吸变化 | ⭐⭐ |
| 6 | **Stopwatch** (秒表) | 计时器 | 4 位 7 段数码管显示，精度 0.1 秒，带启动/暂停控制 | ⭐⭐ |
| 7 | **Smart Responder** (抢答器) | 状态机 | 4 人抢答器，首位按键锁存 + 9 秒倒计时后自动复位 | ⭐⭐ |
| 8 | **Traffic Light** (交通灯) | 状态机 | 4 路十字路口交通灯控制，红/黄/绿自动切换 + 数码管倒计时 | ⭐⭐ |
| 9 | **VGA** (VGA显示) | 图像显示 | VGA 彩条发生器，4 种模式：水平彩条 / 垂直彩条 / XOR / XNOR | ⭐⭐⭐ |
| 10 | **Runner Game** (跑酷游戏) | 综合项目 | **完整 VGA 跑酷游戏** — 跳跃/下蹲、8 种障碍物、4 种地形、计分、开始/结束界面 | ⭐⭐⭐⭐⭐ |

### 亮点项目：Runner Game 🏃

一个完整的无尽跑酷游戏，在 FPGA 上实现：

- **双跳 & 下蹲** 角色控制
- **8 种障碍物**（仙人掌、柱子、门架、矮墙等）+ **4 种地形**（平台、峡谷）
- **动态难度** — 速度随时间递增
- **VGA 640×480 @ 60Hz** 输出，含渐变天空、滚动云朵、HUD 文字
- **分数系统** — 4 位 BCD 分数，同时在 7 段数码管和 VGA 界面显示
- **开始画面**（Logo + 提示文字）& **结束画面**（显示分数 + 重试提示）

## 开发环境

| 工具 | 版本 |
|------|------|
| 开发软件 | Xilinx Vivado |
| 开发板 | EGO1 (Xilinx Artix-7) |
| 编程语言 | Verilog HDL |
| 仿真 | Vivado Simulator / ModelSim |

## 许可证

[MIT](LICENSE)

---

# English

## Introduction

This repository collects digital system design lab projects from Xi'an Jiaotong University (XJTU). All designs are written in **Verilog HDL** and verified on the **Xilinx EGO1 FPGA development board**.

The labs progress from fundamental digital logic units (comparator, adder, encoder) to sequential logic (breathing LED, stopwatch, quiz buzzer, traffic light controller), culminating in a fully-featured **VGA runner game** that integrates multiple core FPGA design techniques.

## Projects

| # | Project | Category | Description | Difficulty |
|---|---------|----------|-------------|------------|
| 1 | **Comparator** | Arithmetic | 2-bit comparator with greater-than / less-than / equal outputs | ⭐ |
| 2 | **Full Adder** | Arithmetic | 1-bit full adder with carry-in and carry-out | ⭐ |
| 3 | **expe2** | Encoder | 4-to-2 priority encoder | ⭐ |
| 4 | **LED** | Sequential | 1-second alternating LED blink (module named `display_7seg`, drives 2 LEDs) | ⭐ |
| 5 | **Breath LED** | PWM | PWM-based breathing LED with smooth fade-in/out | ⭐⭐ |
| 6 | **Stopwatch** | Timer | 4-digit 7-segment stopwatch, 0.1s precision, start/pause control | ⭐⭐ |
| 7 | **Smart Responder** | State Machine | 4-player quiz buzzer — first-press latch + 9-second countdown | ⭐⭐ |
| 8 | **Traffic Light** | State Machine | 4-way intersection controller with countdown display | ⭐⭐ |
| 9 | **VGA** | Display | VGA color bar generator — 4 modes: horizontal / vertical / XOR / XNOR | ⭐⭐⭐ |
| 10 | **Runner Game** | Comprehensive | **Full VGA endless runner** — jump/crouch, 8 obstacle types, 4 terrain types, scoring, start/end screens | ⭐⭐⭐⭐⭐ |

### Highlight: Runner Game 🏃

A complete endless-runner video game synthesized on FPGA:

- **Double-jump & crouch** player mechanics
- **8 obstacle types** (cactus, columns, gates, walls, etc.) + **4 terrain types** (platforms, canyons)
- **Dynamic difficulty** — speed increases over time
- **VGA 640×480 @ 60Hz** output with gradient sky, parallax clouds, and HUD text
- **Score system** — 4-digit BCD score displayed on both 7-segment LEDs and VGA
- **Start screen** (logo + instructions) & **game-over screen** (score display + retry prompt)

## Development Environment

| Tool | Version |
|------|---------|
| IDE | Xilinx Vivado |
| Board | EGO1 (Xilinx Artix-7) |
| Language | Verilog HDL |
| Simulation | Vivado Simulator / ModelSim |

## License

[MIT](LICENSE)

---

<div align="center">
<sub>Built with ❤️ at Xi'an Jiaotong University</sub>
</div>
