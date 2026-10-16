// pusher_block_U.scad
// U 形推动块 / 滑块（重构版：与 sliding_track_base 互配，凹槽居中）
// 尺寸：47mm(X, 宽) × 140mm(Y, 长) × 13mm(Z, 高)
// 形状：U 形滑槽 = 底板 + 左立板 + 右立板
// 坐标系：左下后角 (X=0, Y=0, Z=0) 为原点
//   X  →  右（宽 47）
//   Y  →  长 140
//   Z  →  上（高 13）
//
// 使用方式：U 件倒扣（开口朝下），让两条立板的底缘嵌进 sliding_track_base
//           顶面两条矩形导轨凹槽中，沿 Y 方向滑行。
//
// 互配关系（必须与 sliding_track_base.scad 同步修改）：
//   底板导轨凹槽（关于 X 中心 X=37.5 对称居中）：
//     左侧 X∈[14, 16]（中心 15）  右侧 X∈[59, 61]（中心 60）
//   U 件立板 X∈[14, 16] 和 X∈[59, 61]，宽 2mm，高 11mm
//   立板中心 X=15 和 X=60，正好落在底板两凹槽正中央
//
// 局部坐标系（U 件）下，U 件底板 X∈[14, 61]（外宽 47），立板紧贴底板两端。
// 实际使用时通过 translate 把 U 件放置到全局坐标系下，让立板对齐底板凹槽。
// 本文件不嵌入任何 translate——全局坐标 = 局部坐标。
//
// 结构拆分（3 块板 union）：
//   底板：   X∈[14,61],   Y∈[0,140],   Z∈[0, 2]      （厚 2）
//   左立板： X∈[14,16],   Y∈[0,140],   Z∈[2,13]      （厚 2，高 11）
//   右立板： X∈[59,61],   Y∈[0,140],   Z∈[2,13]      （厚 2，高 11）
//   内部滑槽空间：X∈[16,59]（净宽 43）, Z∈[2,13]（净高 11）, Y∈[0,140]（全贯通）

pusher_w = 47;   // 外宽 X
pusher_l = 86.4; // 外长 Y
pusher_h = 13;   // 外高 Z
wall_t   = 2;    // 壁厚（立板）
floor_t  = 2;    // 底板厚

// 底板 X 起点（局部坐标）= 14（让底板 X∈[14, 61]）
floor_x  = 14;

// 立板 X 起点
left_wall_x  = 14;  // 左立板 X 起点
right_wall_x = 59;  // 右立板 X 起点

module pusher_block_U() {
    color("OrangeRed")
    union() {
        // 底板（X∈[14, 61]）
        translate([floor_x, 0, 0])
            cube([pusher_w, pusher_l, floor_t]);

        // 左立板
        translate([left_wall_x, 0, floor_t])
            cube([wall_t, pusher_l, pusher_h - floor_t]);

        // 右立板
        translate([right_wall_x, 0, floor_t])
            cube([wall_t, pusher_l, pusher_h - floor_t]);
    }
}

// 独立预览/渲染
pusher_block_U();
