// stick_rack.scad - 齿条基体（厚 5mm 粘接面）+ 齿（在顶面之上）+ T 型键
// 坐标系：齿条左下角 (X=0, Y=0, Z=0) 在基体底面（粘贴面）
// 顶面：Z = rack_base_h = 5（齿条基体顶面）
// 齿尖：Z = rack_base_h + addendum = 5 + 1 = 6
// T 型键：位于 Y=rack_len 端，向 Y+ 凸出 1.5mm，高 1.5mm（在基体顶部）

include <rack_params.scad>

module body() {
    // 齿条基体：X=rack_w, Y=rack_len, Z=rack_base_h=5
    // 底面 Z=0 是平整的（用于粘贴）
    // 顶面 Z=5 是齿的起始面
    color("SteelBlue")
    cube([rack_w, rack_len, rack_base_h]);
}

module teeth() {
    // 齿：位于基体顶面之上，齿高 = addendum = 1mm
    // 齿底部 Z = rack_base_h - 0.1（0.1mm overlap 与基体融合避免非流形）
    color("SteelBlue")
    for (i = [0 : tooth_cnt - 1]) {
        translate([0, i * pitch, rack_base_h - 0.1])
            linear_extrude(height = rack_w)
                rack_tooth_profile();
    }
}

module t_key() {
    // T 型键：位于齿条 Y=max 端，X 居中，向 Y+ 凸出 1.5mm
    // 底面 Z = rack_base_h - 0.05（与基体顶面 0.05mm overlap 避免非流形）
    // 顶面 Z = rack_base_h + 1.45
    color("OrangeRed")
    translate([(rack_w - 1.0) / 2, rack_len - 0.05, rack_base_h - 0.05])
        cube([1.0, 1.55, 1.5]);
}

module rack_tooth_profile() {
    tooth_half = tooth_thick * 0.55;
    top_half   = tooth_thick * 0.35;
    polygon(points = [
        [-tooth_half - 0.1, 0],
        [ tooth_half + 0.1, 0],
        [ top_half,          addendum],
        [-top_half,          addendum]
    ]);
}

module stick_rack() {
    union() {
        body();
        teeth();
        t_key();
    }
}

stick_rack();
