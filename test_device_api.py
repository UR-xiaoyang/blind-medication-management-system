#!/usr/bin/env python3
"""
test_device_api.py — 模拟 ESP32 设备上报，测试设备管理 + 事件日志模块

使用 /api/simulator/publish 端点（无需认证），模拟真实设备上报流程：
1. 设备上线
2. 心跳（电量、温度、药道状态、信号）
3. 出药结果（成功/失败）
4. 传感器数据（温度异常）
5. SOS 紧急求助
6. 设备离线

每个步骤后检查后端数据库是否正确记录。

用法: MEDBOX_ADMIN_PASSWORD=<管理员密码> python test_device_api.py [--base-url http://localhost:8080]
可选：MEDBOX_ADMIN_USERNAME=<管理员用户名>（默认 admin）。
"""

import argparse
import json
import os
import time
import sys
import requests

DEFAULT_BASE = "http://localhost:8080"
DEVICE_ID = "test-esp32-sim-001"


def get_admin_credentials():
    password = os.environ.get("MEDBOX_ADMIN_PASSWORD")
    if not password:
        raise RuntimeError("请设置 MEDBOX_ADMIN_PASSWORD 后再运行测试")
    return {
        "username": os.environ.get("MEDBOX_ADMIN_USERNAME", "admin"),
        "password": password,
    }


class Colors:
    OK = "\033[92m"
    FAIL = "\033[91m"
    INFO = "\033[94m"
    WARN = "\033[93m"
    END = "\033[0m"


def log_ok(msg):
    print(f"{Colors.OK}  [PASS]{Colors.END} {msg}")


def log_fail(msg):
    print(f"{Colors.FAIL}  [FAIL]{Colors.END} {msg}")


def log_info(msg):
    print(f"{Colors.INFO}  [INFO]{Colors.END} {msg}")


def log_step(msg):
    print(f"\n{Colors.WARN}{'=' * 60}{Colors.END}")
    print(f"{Colors.WARN}  {msg}{Colors.END}")
    print(f"{Colors.WARN}{'=' * 60}{Colors.END}")


def publish(base_url, topic_suffix, payload, forward_mqtt=False):
    """调用 /api/simulator/publish 发送模拟消息"""
    url = f"{base_url}/api/simulator/publish"
    body = {
        "device_id": DEVICE_ID,
        "topic_suffix": topic_suffix,
        "payload": payload,
        "forward_mqtt": forward_mqtt,
    }
    resp = requests.post(url, json=body, timeout=10)
    resp.raise_for_status()
    return resp.json()


def get_event_logs(base_url, **params):
    """查询事件日志（需要先登录获取 token）"""
    # 模拟器端点无需认证，但 event-logs 需要
    # 先登录
    login_resp = requests.post(f"{base_url}/api/login", json=get_admin_credentials(), timeout=10)
    if login_resp.status_code != 200:
        log_fail(f"登录失败: {login_resp.text}")
        return []
    token = login_resp.json().get("token", "")

    resp = requests.get(
        f"{base_url}/api/event-logs",
        params=params,
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def get_device_status(base_url, device_id):
    """查询设备实时状态（需要登录）"""
    login_resp = requests.post(f"{base_url}/api/login", json=get_admin_credentials(), timeout=10)
    if login_resp.status_code != 200:
        return None
    token = login_resp.json().get("token", "")

    resp = requests.get(
        f"{base_url}/api/devices/{device_id}/status",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def get_devices(base_url):
    """查询设备列表"""
    login_resp = requests.post(f"{base_url}/api/login", json=get_admin_credentials(), timeout=10)
    if login_resp.status_code != 200:
        return []
    token = login_resp.json().get("token", "")

    resp = requests.get(
        f"{base_url}/api/devices",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def test_connection(base_url):
    """测试后端是否可达"""
    log_step("测试后端连接")
    try:
        resp = requests.get(f"{base_url}/api/simulator/devices", timeout=5)
        if resp.status_code == 200:
            log_ok(f"后端可达: {base_url}")
            return True
        else:
            log_fail(f"后端返回 {resp.status_code}")
            return False
    except requests.ConnectionError:
        log_fail(f"无法连接后端: {base_url}")
        return False


def test_status_online(base_url):
    """测试设备上线"""
    log_step("步骤 1: 设备上线")
    result = publish(base_url, "status", {
        "type": "online",
        "status": "online",
    })
    log_ok(f"status 上报成功: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    status = get_device_status(base_url, DEVICE_ID)
    if status and status.get("status") == "online":
        log_ok(f"设备状态: online")
    else:
        log_fail(f"设备状态异常: {status}")


def test_heartbeat(base_url):
    """测试心跳上报"""
    log_step("步骤 2: 心跳上报")
    hb_payload = {
        "type": "heartbeat",
        "battery": 85,
        "temperature": 28.5,
        "slot_states": "mode=gravity_chute;count=8;capacity=12;state=ready",
        "wifi_rssi": -62,
        "ip_address": "192.168.1.100",
        "firmware": "wroom32-test-v1.0",
    }
    result = publish(base_url, "heartbeat", hb_payload)
    log_ok(f"心跳上报成功: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    status = get_device_status(base_url, DEVICE_ID)
    if status:
        log_ok(f"电量: {status.get('battery', '-')}, 温度: {status.get('temperature', '-')}, 信号: {status.get('signal', status.get('wifi_rssi', '-'))} dBm")
        if status.get("slot_states"):
            log_ok(f"药道状态: {status['slot_states']}")
    else:
        log_fail("无法获取设备状态")


def test_dispense_success(base_url):
    """测试出药成功"""
    log_step("步骤 3: 出药结果（成功）")
    result = publish(base_url, "dispense_result", {
        "type": "dispense_result",
        "success": True,
        "error": "",
        "package_index": 1,
        "slot_index": 1,
        "dose_package_id": 0,
        "slot_states": "mode=gravity_chute;count=7;capacity=12;state=ready",
    })
    log_ok(f"出药成功上报: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    logs = get_event_logs(base_url, page_size=5)
    success_events = [e for e in (logs.get("data") or []) if e.get("event_type") == "dispense_success"]
    if success_events:
        log_ok(f"事件日志已创建: {success_events[0].get('title', '')} (severity={success_events[0].get('severity', '')})")
    else:
        log_info("未找到 dispense_success 事件（可能设备未绑定患者，事件仅在有 patient_id 时创建）")


def test_dispense_fail(base_url):
    """测试出药失败"""
    log_step("步骤 4: 出药结果（失败）")
    result = publish(base_url, "dispense_result", {
        "type": "dispense_result",
        "success": False,
        "error": "药片卡在竖直药道中",
        "package_index": 2,
        "slot_index": 2,
        "dose_package_id": 0,
        "slot_states": "mode=gravity_chute;count=7;capacity=12;state=jammed",
    })
    log_ok(f"出药失败上报: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    logs = get_event_logs(base_url, page_size=5)
    fail_events = [e for e in (logs.get("data") or []) if e.get("event_type") == "dispense_fail"]
    if fail_events:
        log_ok(f"事件日志已创建: {fail_events[0].get('title', '')} (severity={fail_events[0].get('severity', '')})")
    else:
        log_info("未找到 dispense_fail 事件（可能设备未绑定患者）")


def test_sensor_normal(base_url):
    """测试传感器数据（正常温度）"""
    log_step("步骤 5a: 传感器数据（正常温度 25°C）")
    result = publish(base_url, "sensor", {
        "type": "sensor",
        "temperature": 25.0,
    })
    log_ok(f"传感器上报成功: {json.dumps(result, ensure_ascii=False)}")


def test_sensor_anomaly(base_url):
    """测试传感器数据（异常温度）"""
    log_step("步骤 5b: 传感器数据（异常温度 55°C）")
    result = publish(base_url, "sensor", {
        "type": "sensor",
        "temperature": 55.0,
    })
    log_ok(f"传感器异常上报成功: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    logs = get_event_logs(base_url, page_size=10)
    sensor_events = [e for e in (logs.get("data") or []) if e.get("event_type") == "sensor_alert"]
    if sensor_events:
        log_ok(f"温度异常事件已创建: {sensor_events[0].get('title', '')} (severity={sensor_events[0].get('severity', '')})")
    else:
        log_info("未找到 sensor_alert 事件（可能设备未绑定患者）")


def test_sos(base_url):
    """测试 SOS 紧急求助"""
    log_step("步骤 6: SOS 紧急求助")
    result = publish(base_url, "sos", {
        "type": "sos",
        "reason": "用户按下求助按钮，药道可能堵塞",
    })
    log_ok(f"SOS 上报成功: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    logs = get_event_logs(base_url, page_size=10)
    sos_events = [e for e in (logs.get("data") or []) if e.get("event_type") == "sos"]
    if sos_events:
        log_ok(f"SOS 事件已创建: {sos_events[0].get('title', '')} (severity={sos_events[0].get('severity', '')})")
    else:
        log_info("未找到 sos 事件（可能设备未绑定患者）")


def test_status_offline(base_url):
    """测试设备离线"""
    log_step("步骤 7: 设备离线")
    result = publish(base_url, "status", {
        "type": "offline",
        "status": "offline",
    })
    log_ok(f"离线上报成功: {json.dumps(result, ensure_ascii=False)}")

    time.sleep(1)
    status = get_device_status(base_url, DEVICE_ID)
    if status and status.get("status") == "offline":
        log_ok(f"设备状态: offline")
    else:
        log_info(f"设备状态: {status.get('status', 'unknown')}（可能仍在在线缓存中，等 120 秒超时）")


def test_device_exists(base_url):
    """确认设备已在数据库中创建"""
    log_step("确认设备已创建")
    devices = get_devices(base_url)
    device_list = devices.get("data", []) if isinstance(devices, dict) else devices
    found = [d for d in device_list if d.get("device_id") == DEVICE_ID]
    if found:
        log_ok(f"设备已存在于数据库: {DEVICE_ID} (status={found[0].get('status', '?')})")
    else:
        log_fail(f"设备未在数据库中找到: {DEVICE_ID}")


def main():
    parser = argparse.ArgumentParser(description="模拟 ESP32 设备上报测试")
    parser.add_argument("--base-url", default=DEFAULT_BASE, help="后端地址")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    try:
        get_admin_credentials()
    except RuntimeError as exc:
        parser.error(str(exc))
    passed = 0
    failed = 0

    print(f"\n{'#' * 60}")
    print(f"# ESP32 设备上报模拟测试")
    print(f"# 设备ID: {DEVICE_ID}")
    print(f"# 后端: {base_url}")
    print(f"{'#' * 60}")

    # 连接测试
    if not test_connection(base_url):
        print(f"\n{Colors.FAIL}后端不可用，请先启动后端服务{Colors.END}")
        sys.exit(1)

    # 模拟完整设备生命周期
    tests = [
        ("设备上线", test_status_online),
        ("心跳上报", test_heartbeat),
        ("出药成功", test_dispense_success),
        ("出药失败", test_dispense_fail),
        ("传感器正常", test_sensor_normal),
        ("传感器异常", test_sensor_anomaly),
        ("SOS求助", test_sos),
        ("设备离线", test_status_offline),
        ("确认设备存在", test_device_exists),
    ]

    for name, test_fn in tests:
        try:
            test_fn(base_url)
            passed += 1
        except Exception as e:
            log_fail(f"{name} 异常: {e}")
            failed += 1

    # 总结
    print(f"\n{'#' * 60}")
    print(f"# 测试完成")
    print(f"# {Colors.OK}通过: {passed}{Colors.END}")
    if failed > 0:
        print(f"# {Colors.FAIL}失败: {failed}{Colors.END}")
    print(f"{'#' * 60}\n")

    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
