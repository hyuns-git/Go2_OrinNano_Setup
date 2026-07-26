#!/bin/bash
# ============================================================
# Unitree Go2 ROS2 환경 변수 설정 스크립트
# 
# 사용법:
#   source scripts/setup_env.sh
#   또는 ~/.bashrc 에 아래 줄을 추가:
#   source ~/Go2_OrinNano_Setup/scripts/setup_env.sh
# ============================================================

# 네트워크 인터페이스 설정 (환경에 맞게 수정)
NETWORK_INTERFACE="eth1"

# ROS2 Foxy 기본 환경
source /opt/ros/foxy/setup.bash

# Unitree ROS2 워크스페이스
if [ -f ~/unitree_ros2/cyclonedds_ws/install/setup.bash ]; then
    source ~/unitree_ros2/cyclonedds_ws/install/setup.bash
    echo "[✓] unitree_ros2 워크스페이스 로드 완료"
else
    echo "[✗] unitree_ros2 워크스페이스를 찾을 수 없습니다."
    echo "    경로를 확인하세요: ~/unitree_ros2/cyclonedds_ws/install/setup.bash"
fi

# DDS 미들웨어 설정
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# CycloneDDS 네트워크 인터페이스 지정
export CYCLONEDDS_URI="<CycloneDDS><Domain><General><Interfaces><NetworkInterface name=\"${NETWORK_INTERFACE}\"/></Interfaces></General></Domain></CycloneDDS>"

echo "[✓] RMW_IMPLEMENTATION = ${RMW_IMPLEMENTATION}"
echo "[✓] 네트워크 인터페이스 = ${NETWORK_INTERFACE}"
echo ""
echo "=== Unitree Go2 ROS2 환경 설정 완료 ==="
echo "  - ros2 topic list  로 통신 확인"
echo "  - ros2 topic echo /sportmodestate  로 데이터 수신 확인"
