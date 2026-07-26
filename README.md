# 🤖 Unitree Go2 SDK & ROS2 Setup on Jetson Orin Nano

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Jetson_Orin_Nano-green?style=for-the-badge&logo=nvidia" alt="Platform">
  <img src="https://img.shields.io/badge/Robot-Unitree_Go2-blue?style=for-the-badge" alt="Robot">
  <img src="https://img.shields.io/badge/ROS2-Foxy-orange?style=for-the-badge&logo=ros" alt="ROS2">
  <img src="https://img.shields.io/badge/OS-Ubuntu_20.04-purple?style=for-the-badge&logo=ubuntu" alt="OS">
</p>

본 저장소는 **NVIDIA Jetson Orin Nano (D115 캐리어 보드, Ubuntu 20.04)** 환경에서 Unitree Go2 로봇의 제어 및 센서 데이터 수신을 위한 `unitree_sdk2` 및 `unitree_ros2` 설정 절차를 기록한 문서입니다.

> [!NOTE]
> 이 가이드는 실제 Jetson Orin Nano + Go2 환경에서 **검증된 절차**를 기반으로 작성되었습니다.

 ## ⚠️ 필수 주의 사항: D115 캐리어 보드 및 L4T 커널 보호

본 환경은 NVIDIA Jetson Orin Nano 모듈에 커스텀 보드인 **D115 캐리어 보드**가 결합된 시스템입니다. 하드웨어의 정상적인 작동을 위해 제조사의 맞춤형 BSP(Board Support Package) 및 NVIDIA L4T(Linux for Tegra) 커널이 적용되어 있습니다. 따라서 다음 사항을 엄격히 준수해야 합니다.

* **`sudo apt upgrade` 실행 엄금**
  전체 패키지 업그레이드를 수행하면 D115 보드 구동에 필수적인 커스텀 L4T 커널 패키지(예: `nvidia-l4t-kernel`, `nvidia-l4t-display-kernel` 등)가 표준 패키지로 덮어씌워집니다. 이로 인해 랜 포트 인식 불가, 디스플레이 출력 실패 또는 부팅 불가 등의 치명적인 하드웨어 제어 오류가 발생합니다.
* **필수 패키지 단독 설치**
  개발에 필요한 라이브러리나 툴이 있을 경우, 전체 업데이트를 피하고 반드시 `sudo apt install [패키지명]` 명령어를 사용하여 필요한 패키지만 개별적으로 설치해야 합니다.

---

## 📋 목차

- [하드웨어 및 네트워크 환경 설정](#1--하드웨어-및-네트워크-환경-설정)
- [Unitree SDK2 설치](#2--unitree-sdk2-설치)
- [Unitree ROS2 (Foxy) 브릿지 설치](#3--unitree-ros2-foxy-브릿지-설치)
- [실행 및 데이터 수신 확인](#4--실행-및-데이터-수신-확인)
- [트러블슈팅](#5--트러블슈팅)

---

## 1. 🔌 하드웨어 및 네트워크 환경 설정

Go2 로봇과 통신하기 위해 **유선 이더넷(LAN) 연결** 및 **고정 IP 설정**이 필요합니다.

### 네트워크 구성도

```
┌──────────────────┐    Ethernet (LAN)    ┌──────────────────┐
│   Jetson Orin    │◄────────────────────►│   Unitree Go2    │
│   Nano (D115)    │                      │     Robot        │
│                  │                      │                  │
│  192.168.123.222 │                      │  192.168.123.161 │
│     (eth1)       │                      │                  │
└──────────────────┘                      └──────────────────┘
```

| 항목 | 값 |
|:---|:---|
| **Go2 로봇 내부 IP** | `192.168.123.161` |
| **Orin Nano 할당 IP** | `192.168.123.222` |
| **사용 인터페이스** | `eth1` (하드웨어에 따라 `eth0`일 수 있음) |
| **서브넷 마스크** | `255.255.255.0` |

### 임시 IP 할당 및 통신 테스트

```bash
# eth1 인터페이스에 IP 할당 및 활성화
sudo ifconfig eth1 192.168.123.222 netmask 255.255.255.0 up

# 로봇과의 물리적 통신 확인
ping 192.168.123.161
```

> [!IMPORTANT]
> 위 `ifconfig` 명령어는 **재부팅 시 초기화**되므로, 영구 적용을 위해서는 Ubuntu 네트워크 설정(GUI 또는 Netplan)에서 **수동(Manual)**으로 고정 IP를 등록해야 합니다.

---

## 2. 📦 Unitree SDK2 설치

로봇 제어를 위한 **C++ 기반 핵심 라이브러리** 설치 절차입니다.

### 2-1. 의존성 설치

```bash
sudo apt-get update
sudo apt-get install -y \
    cmake \
    g++ \
    build-essential \
    libyaml-cpp-dev \
    libeigen3-dev \
    libboost-all-dev \
    libspdlog-dev \
    libfmt-dev \
    git
```

### 2-2. 빌드 및 설치

시스템 환경에 영향을 주지 않도록 `/opt/unitree_robotics` 경로에 설치합니다.

```bash
git clone https://github.com/unitreerobotics/unitree_sdk2.git
cd unitree_sdk2
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/unitree_robotics
make -j$(nproc)
sudo make install
```

---

## 3. 🌉 Unitree ROS2 (Foxy) 브릿지 설치

ROS2 환경에서 Go2의 센서 데이터(Topic)를 직접 수신하기 위해 **CycloneDDS 버전을 맞추고** 패키지를 빌드합니다.

### 3-1. 의존성 설치

```bash
sudo apt install -y \
    ros-foxy-rmw-cyclonedds-cpp \
    ros-foxy-rosidl-generator-dds-idl \
    libyaml-cpp-dev
```

### 3-2. 워크스페이스 구성 및 소스 다운로드

```bash
cd ~
git clone https://github.com/unitreerobotics/unitree_ros2.git
cd ~/unitree_ros2/cyclonedds_ws/src

git clone https://github.com/ros2/rmw_cyclonedds -b foxy
git clone https://github.com/eclipse-cyclonedds/cyclonedds -b releases/0.10.x
```

### 3-3. CycloneDDS 단독 빌드

> [!CAUTION]
> 시스템 ROS2 환경 변수와의 충돌(`symbol lookup error`)을 방지하기 위해 **환경 변수를 초기화한 상태**에서 단독으로 먼저 빌드합니다.

```bash
cd ~/unitree_ros2/cyclonedds_ws

# 환경 변수 초기화 (충돌 방지)
unset LD_LIBRARY_PATH

colcon build --packages-select cyclonedds
```

### 3-4. 나머지 패키지 빌드

CycloneDDS 빌드 완료 후, ROS2 환경 변수를 불러와 나머지 패키지를 컴파일합니다.

```bash
source /opt/ros/foxy/setup.bash
source install/setup.bash
colcon build --packages-skip cyclonedds
```

---

## 4. 🚀 실행 및 데이터 수신 확인

새로운 터미널을 열 때마다 아래의 환경 변수를 설정해야 로봇의 DDS 통신망과 연결됩니다.

### 4-1. 환경 변수 설정

```bash
# ROS2 및 워크스페이스 소싱
source /opt/ros/foxy/setup.bash
source ~/unitree_ros2/cyclonedds_ws/install/setup.bash

# DDS 미들웨어 및 네트워크 인터페이스 지정
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="eth1"/></Interfaces></General></Domain></CycloneDDS>'
```

> [!TIP]
> 매번 입력이 번거로우시다면, 위 내용을 `~/.bashrc` 파일 하단에 추가하거나 본 저장소의 [`scripts/setup_env.sh`](scripts/setup_env.sh) 스크립트를 활용하세요.

### 4-2. ROS2 토픽 확인

```bash
# 통신 연결 확인 (전체 토픽 목록 출력)
ros2 topic list

# Go2 관절, IMU 등 상태 데이터 실시간 확인
ros2 topic echo /sportmodestate
```

### 주요 토픽 목록

| 토픽 이름 | 설명 |
|:---|:---|
| `/sportmodestate` | 관절 각도, IMU, 속도 등 종합 상태 |
| `/lowstate` | 모터 레벨 저수준 상태 데이터 |
| `/highstate` | 고수준 상태 데이터 |

---

## 5. 🔧 트러블슈팅

### `symbol lookup error` 발생 시

CycloneDDS 라이브러리 버전 충돌이 원인입니다. 아래 순서로 재빌드하세요:

```bash
cd ~/unitree_ros2/cyclonedds_ws
rm -rf build install log
unset LD_LIBRARY_PATH
colcon build --packages-select cyclonedds
source /opt/ros/foxy/setup.bash
source install/setup.bash
colcon build --packages-skip cyclonedds
```

### `ping` 실패 시

1. 이더넷 케이블 연결 상태 확인
2. `ip addr show` 명령어로 인터페이스명 재확인
3. Go2 로봇 전원 상태 확인
4. 방화벽 설정 확인: `sudo ufw status`

### 토픽이 보이지 않을 때

1. `RMW_IMPLEMENTATION` 환경 변수 확인
2. `CYCLONEDDS_URI`의 네트워크 인터페이스명 확인
3. Go2 로봇의 DDS 모드가 활성화되어 있는지 확인

---

## 📁 프로젝트 구조

```
Go2_OrinNano_Setup/
├── README.md                  # 본 문서
├── scripts/
│   └── setup_env.sh           # 환경 변수 자동 설정 스크립트
├── config/
│   └── cyclonedds.xml         # CycloneDDS 설정 파일
└── .gitignore
```

---

## 🔗 참고 자료

- [Unitree SDK2 GitHub](https://github.com/unitreerobotics/unitree_sdk2)
- [Unitree ROS2 GitHub](https://github.com/unitreerobotics/unitree_ros2)
- [ROS2 Foxy 공식 문서](https://docs.ros.org/en/foxy/)
- [CycloneDDS GitHub](https://github.com/eclipse-cyclonedds/cyclonedds)
- [NVIDIA Jetson Orin Nano 개발자 가이드](https://developer.nvidia.com/embedded/jetson-orin-nano)

---

## 📄 라이선스

본 저장소의 문서는 자유롭게 참고 및 수정 가능합니다.  
Unitree SDK 및 ROS2 관련 코드의 라이선스는 각 원본 저장소의 라이선스를 따릅니다.

---

<p align="center">
  <sub>Made with ❤️ by <a href="https://github.com/hyuns-git">hyuns-git</a></sub>
</p>
