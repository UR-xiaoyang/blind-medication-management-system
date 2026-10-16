// bearing_block.scad - 6.5mm 电机轴的轴座
// 局部坐标系：左下前角为 (0,0,0)
// 包含：12×10×8 主块 + L 形加强脚 + Φ6.7 轴孔（沿 X 方向水平穿过）+ M3 沉头安装孔

include <rack_params.scad>

module bearing_block() {
    color("SlateGray")
    difference() {
        union() {
            // 主块
            cube([bearing_block_w, bearing_block_d, bearing_block_h]);
            // L 形加强脚（向 Y 方向延伸，用于螺丝固定到底板）
            cube([bearing_block_w, bearing_block_d + 8, 3]);
        }
        // 水平轴孔（沿 X 方向穿过主块中心，6.7mm = 6.5mm 轴 + 0.2mm 间隙）
        translate([-eps, bearing_block_d / 2, bearing_block_h / 2])
            rotate([0, 90, 0])
                cylinder(h = bearing_block_w + 2 * eps, r = bearing_hole_d / 2, $fn = 24);
        // M3 沉头安装孔（向下贯穿 L 形脚）
        translate([bearing_block_w / 2, bearing_block_d + 4, -eps])
            cylinder(h = 3 + 2 * eps, r = mount_hole_d / 2, $fn = 24);
    }
}

// 独立渲染
bearing_block();
