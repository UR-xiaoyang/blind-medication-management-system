"""
在 SQLite 数据库中插入演示数据。
运行方式: python insert_demo_data.py
"""
import sqlite3
from datetime import datetime, timedelta

DB_PATH = "blind-medication-backend/data/blind_medication.db"

db = sqlite3.connect(DB_PATH)
cur = db.cursor()
now = datetime.now()
ts = now.strftime("%Y-%m-%d %H:%M:%S")

# ====== 清空旧测试数据，保留 admin(id=1) ======
for t in ["medication_logs","dose_package_items","dose_packages",
          "event_logs","nursing_records","medications","patients",
          "devices","device_heartbeats"]:
    cur.execute(f"DELETE FROM {t}")
    cur.execute(f"DELETE FROM sqlite_sequence WHERE name='{t}'")
db.commit()
print("Old data cleared.")

# ====== 设备 ======
devs = [
    ("ESP32-BOX-001","张秀兰的药盒","v2.1.0","offline",
     (now-timedelta(minutes=30)).strftime("%Y-%m-%d %H:%M:%S"),"192.168.1.101",-58),
    ("ESP32-BOX-002","李建国的药盒","v2.1.0","offline",
     (now-timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S"),"192.168.1.102",-65),
    ("ESP32-BOX-003","王淑芬的药盒","v2.0.5","offline",None,"",0),
]
for d in devs:
    cur.execute(
        "INSERT INTO devices(device_id,device_name,firmware,status,last_online,ip_address,signal,created_at,updated_at) "
        "VALUES(?,?,?,?,?,?,?,?,?)", (*d, ts, ts))

# ====== 患者 ======
pts = [
    ("张秀兰","女",72,"13912345678","北京市朝阳区幸福里小区3栋502",
     "张伟","13811112222",
     "高血压病史15年，2型糖尿病8年，左眼白内障术后。性格内向，独居。",
     "ESP32-BOX-001"),
    ("李建国","男",68,"13698765432","北京市海淀区花园路12号院2栋101",
     "李华","13722223333",
     "双目失明，冠心病支架术后，服用抗凝药。有轻度肾功能不全。",
     "ESP32-BOX-002"),
    ("王淑芬","女",81,"13566667777","北京市西城区德胜门外大街5号院1栋303",
     "王明","13888889999",
     "青光眼致全盲，骨质疏松，长期服用钙片和维生素D。记忆力下降需提醒用药。",
     "ESP32-BOX-003"),
]
for p in pts:
    cur.execute(
        "INSERT INTO patients(name,gender,age,phone,address,emergency_name,emergency_phone,"
        "medical_notes,device_id,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
        (*p, ts, ts))

# 绑定设备
cur.execute("UPDATE devices SET patient_id=1 WHERE device_id='ESP32-BOX-001'")
cur.execute("UPDATE devices SET patient_id=2 WHERE device_id='ESP32-BOX-002'")
cur.execute("UPDATE devices SET patient_id=3 WHERE device_id='ESP32-BOX-003'")
print("Devices & patients done.")

# ====== 药品 ======
meds = [
    # 张秀兰(pid=1)  med_id 1-3
    (1,"苯磺酸氨氯地平","5mg/片","1片","每日1次",60,15,"偶见头晕、面部潮红、踝部水肿"),
    (1,"二甲双胍缓释片","500mg/片","1片","每日2次",120,42,"胃肠道反应、维生素B12缺乏"),
    (1,"阿托伐他汀钙片","20mg/片","1片","每晚1次",30,8,"肝酶升高、肌肉疼痛"),
    # 李建国(pid=2)  med_id 4-6
    (2,"华法林钠片","2.5mg/片","1片","每日1次",90,30,"出血风险增加，需定期监测INR"),
    (2,"阿司匹林肠溶片","100mg/片","1片","每日1次",60,20,"胃肠道出血、过敏反应"),
    (2,"美托洛尔缓释片","47.5mg/片","1片","每日1次",30,10,"心动过缓、乏力、头晕"),
    # 王淑芬(pid=3)  med_id 7-9
    (3,"碳酸钙D3片","600mg+D3 125IU","1片","每日1次",60,18,"便秘、嗳气"),
    (3,"阿仑膦酸钠片","70mg/片","1片","每周1次",12,4,"食管溃疡、骨痛、腹胀"),
    (3,"维生素D滴剂","400IU/粒","1粒","每日1次",90,25,"过量可致高钙血症"),
]
for m in meds:
    cur.execute(
        "INSERT INTO medications(patient_id,name,specification,dosage,frequency,"
        "stock_total,stock_used,side_effects,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
        (*m, ts, ts))
print("Medications done.")

# med_id 映射（插入顺序 1~9）
M = list(range(1, 10))

# ====== 按次服药包 ======
dpk = [
    # (patient_id, name, trigger_time, package_index, enabled, status, notes)
    (1,"早餐后","08:00",1,1,"pending",""),
    (1,"午餐后","12:30",2,1,"pending",""),
    (1,"睡前","21:00",3,1,"pending",""),
    (2,"早餐后","08:30",1,1,"pending",""),
    (2,"晚餐后","18:30",2,1,"pending",""),
    (3,"早餐后","07:30",1,1,"pending",""),
    (3,"周一早餐前","07:00",2,1,"pending","每周一空腹服用阿仑膦酸钠，服药后30分钟内不要躺下"),
]
pkg_ids = []
for d in dpk:
    cur.execute(
        "INSERT INTO dose_packages(patient_id,name,trigger_time,package_index,enabled,status,notes,created_at,updated_at) "
        "VALUES(?,?,?,?,?,?,?,?,?)", (*d, ts, ts))
    pkg_ids.append(cur.lastrowid)

# 药包子项
items = [
    (pkg_ids[0], M[0], 1, "片"), (pkg_ids[0], M[1], 1, "片"),   # 张-早餐后
    (pkg_ids[1], M[1], 1, "片"),                                 # 张-午餐后
    (pkg_ids[2], M[2], 1, "片"),                                 # 张-睡前
    (pkg_ids[3], M[3], 1, "片"), (pkg_ids[3], M[4], 1, "片"),   # 李-早餐后
    (pkg_ids[4], M[5], 1, "片"),                                 # 李-晚餐后
    (pkg_ids[5], M[6], 1, "片"), (pkg_ids[5], M[8], 1, "粒"),   # 王-早餐后
    (pkg_ids[6], M[7], 1, "片"),                                 # 王-周一早餐前
]
for it in items:
    cur.execute(
        "INSERT INTO dose_package_items(dose_package_id,medication_id,quantity,unit,created_at,updated_at) "
        "VALUES(?,?,?,?,?,?)", (*it, ts, ts))
print("Dose packages done.")

# ====== 事件日志 ======
def t(delta_days=0, delta_hours=0, delta_mins=0):
    return (now - timedelta(days=delta_days, hours=delta_hours, minutes=delta_mins)).strftime("%Y-%m-%d %H:%M:%S")

evts = [
    (1,"ESP32-BOX-001","dispense_success","出药成功",
     "药包编号: 1，早餐后，氨氯地平+二甲双胍",
     "info","device","resolved",1,"confirmed_normal","设备自动出药，患者已取药", t(3), t(3)),
    (1,"ESP32-BOX-001","dispense_fail","出药失败 - 药片卡住",
     "药包编号: 2，午餐后，错误: 药片卡在竖直药道中",
     "error","device","resolved",1,"visit_dispatched","已通知护理员上门检查并手动补药", t(3,-2), t(3,-1)),
    (2,"ESP32-BOX-002","medication_missed","未服药警告",
     "李建国早餐后药包未按时服用，已超过2小时",
     "warning","device","resolved",1,"family_notified",
     "已电话联系患者家属，确认患者外出就医，稍后补服", t(2,10), t(2,8)),
    (2,"ESP32-BOX-002","sos","SOS紧急求助",
     "用户按下SOS按钮，需要人工协助检查竖直药道",
     "critical","device","resolved",1,"visit_dispatched",
     "已派遣护理员上门，药道已清理", t(2), t(2,-1)),
    (3,"ESP32-BOX-003","device_offline","设备离线",
     "王淑芬的药盒已离线超过4小时",
     "warning","device","processing",None,"","", t(0,6), ts),
    (1,"ESP32-BOX-001","dispense_success","出药成功",
     "药包编号: 1，早餐后",
     "info","device","pending",None,"","", t(0,2), ts),
    (2,"ESP32-BOX-002","dispense_success","出药成功",
     "药包编号: 1，早餐后，华法林+阿司匹林",
     "info","device","pending",None,"","", t(0,1,30), ts),
    (1,"ESP32-BOX-001","sensor_alert","设备温度偏高",
     "设备温度: 52.3°C，已超过50°C阈值",
     "warning","device","pending",None,"","", t(0,0,45), ts),
]
for e in evts:
    cur.execute(
        "INSERT INTO event_logs(patient_id,device_id,event_type,title,content,severity,source,status,"
        "handler_id,handle_result,handle_note,occurred_at,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)", e)
print("Event logs done.")

# ====== 护理记录 ======
nursing = [
    (1,1,"medication_check",
     "上门检查张秀兰的用药情况，苯磺酸氨氯地平存量充足，二甲双胍缓释片剩余约两周用量，建议下周补充。患者反映偶尔头晕，已记录并提醒注意血压监测。"),
    (2,1,"phone_followup",
     "电话随访李建国，确认华法林INR指标已送检，结果待回。患者表示药道卡药问题已解决，新药盒运行正常。"),
    (3,1,"health_visit",
     "上门走访王淑芬，发现药盒离线，排查后确认是家中WiFi路由器断电所致，已协助重新连接。老人精神状态良好，但行动较迟缓，建议增加钙片剂量。"),
    (2,1,"emergency",
     "收到SOS求助信号后紧急上门，发现药道竖直槽卡药，已手动清除堵塞并补充备用药品至药道。检查药道机械结构正常，已清理残留药粉。"),
]
for n in nursing:
    cur.execute(
        "INSERT INTO nursing_records(patient_id,admin_id,type,content,created_at) VALUES(?,?,?,?,?)",
        (*n, ts))
print("Nursing records done.")

# ====== 服药记录（今天 + 昨天） ======
today_s = now.strftime("%Y-%m-%d")
yest_s  = (now - timedelta(days=1)).strftime("%Y-%m-%d")
ml = [
    (1, M[0], pkg_ids[0], "taken",  f"{today_s} 08:05:00"),
    (1, M[1], pkg_ids[0], "taken",  f"{today_s} 08:05:00"),
    (2, M[3], pkg_ids[3], "taken",  f"{today_s} 08:35:00"),
    (2, M[4], pkg_ids[3], "taken",  f"{today_s} 08:35:00"),
    (1, M[0], pkg_ids[0], "taken",  f"{yest_s} 08:10:00"),
    (1, M[1], pkg_ids[0], "taken",  f"{yest_s} 08:10:00"),
    (1, M[1], pkg_ids[1], "missed", f"{yest_s} 14:00:00"),
    (2, M[3], pkg_ids[3], "taken",  f"{yest_s} 09:00:00"),
    (3, M[6], pkg_ids[5], "taken",  f"{yest_s} 07:35:00"),
]
for m in ml:
    cur.execute(
        "INSERT INTO medication_logs(patient_id,medication_id,dose_package_id,action,taken_at,created_at) "
        "VALUES(?,?,?,?,?,?)", (*m, m[4]))
print("Medication logs done.")

db.commit()
db.close()
print("✅ All demo data inserted!")
