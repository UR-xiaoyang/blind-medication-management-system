// pusher_face.scad - L 形推头（独立可打印件，无悬垂）
// 坐标系：竖板左下角 (X=0, Y=0, Z=0) 在齿条基体底面
// 竖板 23×1.5×20mm 垂直向上（自支撑）
// 横板 23×15+1.5×1.5mm 水平（自支撑）
// 竖板底部有 1.5mm 凸出量，套在 stick_rack 的 T 型键上

include <rack_params.scad>

module upright_web() {
    // 竖直筋板：宽 X = pusher_w(23), 厚 Y = pusher_tab_t(1.5), 高 Z = blocker_h(20)
    color("OrangeRed")
    cube([pusher_w, pusher_tab_t, blocker_h]);
}

module tray() {
    // 水平托板：宽 X = pusher_w(23), 长 Y = 15 + pusher_tab_t(16.5), 厚 Z = pusher_arm_t(1.5)
    // 顶面 Z = base_t(5)，底面 Z = base_t - pusher_arm_t
    color("OrangeRed")
    translate([0, -pusher_tab_t, base_t])
        cube([pusher_w, pusher_tab_t + 15, pusher_arm_t]);
}

module pusher_face() {
    union() {
        upright_web();
        tray();
    }
}

pusher_face();
