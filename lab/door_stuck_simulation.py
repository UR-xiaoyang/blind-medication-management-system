"""
圆形药盒 + 活版门设计 卡门概率模拟实验

设计参数:
- 圆形药盒: 100mm 直径
- 活版门: 依靠重量自然打开，与侧壁存在间隙

模拟目标:
- 通过蒙特卡洛方法计算门卡住的概率
- 分析不同间隙对卡门概率的影响
"""

import random
import math
from typing import Tuple

# 设计参数
PILL_BOX_DIAMETER = 100  # mm
HOLE_DIAMETER = 102      # mm (漏孔直径，比药盒大2mm)
DOOR_THICKNESS = 3       # mm (活版门厚度)
DOOR_WEIGHT = 50         # gram (活版门重量)
GAP_TO_SIDE = 2          # mm (门与侧壁的初始间隙)
WALL_FRICTION = 0.3      # 摩擦系数 (侧壁与门之间)

# 模拟参数
NUM_SIMULATIONS = 10000  # 模拟次数

random.seed(42)

def check_door_stuck(
    pill_offset_x: float,
    pill_offset_y: float,
    door_angle: float,
    gap: float
) -> bool:
    """
    检查门是否卡住

    参数:
    - pill_offset_x, pill_offset_y: 药盒中心相对漏孔中心的偏移
    - door_angle: 门打开的角度 (弧度)
    - gap: 门与侧壁的间隙

    返回:
    - True 表示卡住, False 表示正常
    """
    max_offset = (HOLE_DIAMETER - PILL_BOX_DIAMETER) / 2

    if pill_offset_x < -max_offset or pill_offset_x > max_offset:
        return True
    if pill_offset_y < -max_offset or pill_offset_y > max_offset:
        return True

    pill_edge_x = pill_offset_x + PILL_BOX_DIAMETER / 2 * math.cos(door_angle)
    pill_edge_y = pill_offset_y + PILL_BOX_DIAMETER / 2 * math.sin(door_angle)

    distance_to_wall = abs(pill_edge_x) - gap
    if distance_to_wall > 0 and distance_to_wall > DOOR_THICKNESS * WALL_FRICTION:
        return True

    if abs(pill_offset_x) > max_offset - DOOR_THICKNESS:
        return True

    return False

def run_simulation(
    num_simulations: int,
    gap: float,
    angle_variation: float = 0.3
) -> float:
    """
    运行蒙特卡洛模拟

    参数:
    - num_simulations: 模拟次数
    - gap: 门与侧壁的间隙
    - angle_variation: 门打开角度的变化范围 (弧度)

    返回:
    - 卡门概率
    """
    stuck_count = 0

    for _ in range(num_simulations):
        pill_offset_x = random.uniform(-3, 3)
        pill_offset_y = random.uniform(-3, 3)
        door_angle = random.uniform(-angle_variation, angle_variation)

        if check_door_stuck(pill_offset_x, pill_offset_y, door_angle, gap):
            stuck_count += 1

    return stuck_count / num_simulations

def analyze_gap_effect() -> None:
    """分析不同间隙对卡门概率的影响"""
    print("=" * 60)
    print("间隙大小对卡门概率的影响分析")
    print("=" * 60)
    print(f"{'间隙(mm)':<12} {'卡门概率':<15} {'评价'}")
    print("-" * 60)

    gaps = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0]
    results = []

    for gap in gaps:
        prob = run_simulation(NUM_SIMULATIONS, gap)
        results.append((gap, prob))

        if prob < 0.01:
            rating = "优秀"
        elif prob < 0.05:
            rating = "良好"
        elif prob < 0.1:
            rating = "可接受"
        else:
            rating = "需改进"

        print(f"{gap:<12.1f} {prob:<15.4f} {rating}")

    print("-" * 60)
    return results

def main():
    print("=" * 60)
    print("圆形药盒 + 活版门设计 卡门概率模拟实验")
    print("=" * 60)
    print(f"药盒直径: {PILL_BOX_DIAMETER} mm")
    print(f"漏孔直径: {HOLE_DIAMETER} mm")
    print(f"门厚度: {DOOR_THICKNESS} mm")
    print(f"模拟次数: {NUM_SIMULATIONS}")
    print()

    print("【当前设计参数下的卡门概率】")
    current_prob = run_simulation(NUM_SIMULATIONS, GAP_TO_SIDE)
    print(f"间隙 = {GAP_TO_SIDE}mm 时, 卡门概率 = {current_prob:.4f} ({current_prob*100:.2f}%)")
    print()

    print("【参数敏感性分析】")
    analyze_gap_effect()

    print()
    print("【建议】")
    if current_prob < 0.01:
        print(f"当前设计 ({GAP_TO_SIDE}mm间隙) 卡门概率很低, 设计可靠")
    elif current_prob < 0.05:
        print(f"当前设计 ({GAP_TO_SIDE}mm间隙) 卡门概率可接受")
    else:
        print(f"建议增加间隙以降低卡门概率")

if __name__ == "__main__":
    main()