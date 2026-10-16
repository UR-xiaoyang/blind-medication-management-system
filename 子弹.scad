// 盲人取药机 - 单次药量小抽屉 (Pill Drawer)
// 实际测量尺寸：65.5 × 13.5 × 13.5 mm
// 滑动方向：沿 13.5mm 短边（Y 方向）从底板推出
// X 方向 65.5mm 落在底板凹槽中，Z 方向 13.5mm 为盒子高度

drawer_w = 65.5;        // 抽屉外宽 (X方向，落入底板凹槽的宽度)
drawer_l = 13.5;        // 抽屉外长 (Y方向，滑动推出方向)
drawer_h = 13.5;        // 抽屉高度 (Z方向)
wall_thickness = 1.5;   // 壁厚与底板厚度

// --- 抽屉生成模块 ---
module pill_drawer() {
    difference() {
        // 1. 生成外部基础方块
        cube([drawer_w, drawer_l, drawer_h], center=false);

        // 2. 内部挖空，形成无盖盒子的形状
        translate([wall_thickness, wall_thickness, wall_thickness])
            cube([
                drawer_w - (2 * wall_thickness),
                drawer_l - (2 * wall_thickness),
                drawer_h // 顶部直接贯穿，形成开口
            ], center=false);
    }
}

// 渲染抽屉
pill_drawer();
