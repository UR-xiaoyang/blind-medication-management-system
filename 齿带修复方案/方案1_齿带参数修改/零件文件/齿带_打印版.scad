// 齿带 - 打印版（齿与板 union 在一起）
// 坐标系：齿带左下角 (X=0, Y=0, Z=0) 在底面
// 来源：齿带修复方案/方案1_齿带参数修改/装配图/齿带齿轮装配图.scad
// 原版齿和板是分开的，无法打印，改成 union

include <rack_params.scad>

// ====== 方案1修复参数（与原装配图保持一致）======
// 加厚提高刚性：弯曲刚度与厚度的三次方成正比
// 2.5→4.0mm，刚度提升 4.1 倍
rack_sleeve_thick = 4.0;    // 齿带本体厚度 (原 1.0→2.5→4.0)
rack_w_extended = 9.0;      // 齿带宽度 (8→9mm)
teeth_height_belt = 1.2;    // 齿高 (1.0→1.2mm)

// ====== 齿带（齿与板 union，可直接打印）======
module rack_belt_solid() {
    // 齿形先做出来，再与板 union
    union() {
        // 齿带本体（板）
        cube([rack_len, rack_w_extended, rack_sleeve_thick]);

        // 齿形（粘在齿带顶面，0.05mm overlap 避免非流形）
        for (i = [0 : tooth_cnt - 1]) {
            translate([i * pitch + tooth_thick/2, 0, rack_sleeve_thick - 0.05])
                cube([tooth_thick, rack_w_extended, teeth_height_belt]);
        }
    }
}

rack_belt_solid();
