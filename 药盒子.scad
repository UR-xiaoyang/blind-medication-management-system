// 盲人取药机 - 低矮药盒子（嵌入式扣盖方案）
// 适配内部空间 61.1 x 47.9mm，总高度 13.5mm。
// 盒体顶部有盖子沉台，盖子放入后与盒体顶部齐平。
// part_id 可选：0=闭合装配示意，1=盒体，2=嵌入盖打印方向，3=打开示意。

part_id = 0;

space_w = 61.1;          // 可用内部宽度
space_d = 47.9;          // 可用内部深度
fit_clearance = 1.2;     // 每侧自由下落公差，FDM打印后不容易卡住

box_w = space_w - 2 * fit_clearance;
box_d = space_d - 2 * fit_clearance;
box_h = 13.5;

wall = 1.6;
bottom_t = 1.2;
corner_chamfer = 1.0;    // 外侧竖角倒角，避免斜着下落时卡角

lid_t = 1.2;             // 盖板厚度，闭合后占用盒体顶部沉台
lid_xy_clearance = 0.35; // 盖板与盒体内壁的单边间隙，适合FDM打印

seat_depth = 1.4;        // 托台向内伸出的宽度
seat_slope_h = 1.4;      // 托台下方45度斜撑高度，避免悬空
seat_overlap = 0.2;      // 托台嵌入侧墙，避免贴面导致非流形
seat_z = box_h - lid_t;  // 盖板底面高度，盖上后顶面齐平到 13.5mm

skirt_h = 1.8;           // 盖子下方内塞裙边高度，防运输漏药
skirt_wall = 1.2;        // 至少约3条0.4mm线宽，更稳
skirt_clearance = 0.35;

front_pick_w = 18;       // 前侧取盖缺口宽度
front_pick_h = 3.2;      // 前侧取盖缺口高度
lid_grip_depth = 0.45;   // 盖面浅槽深度，不打穿盖子

eps = 0.02;

inner_w = box_w - 2 * wall;
inner_d = box_d - 2 * wall;

lid_w = inner_w - 2 * lid_xy_clearance;
lid_d = inner_d - 2 * lid_xy_clearance;
lid_x = wall + lid_xy_clearance;
lid_y = wall + lid_xy_clearance;

seat_inner_w = inner_w - 2 * seat_depth;
seat_inner_d = inner_d - 2 * seat_depth;
skirt_w = seat_inner_w - 2 * skirt_clearance;
skirt_d = seat_inner_d - 2 * skirt_clearance;
skirt_x = (lid_w - skirt_w) / 2;
skirt_y = (lid_d - skirt_d) / 2;

module x_seat_rail(len) {
    z0 = seat_z - seat_slope_h;
    z1 = seat_z;

    polyhedron(
        points=[
            [-seat_overlap, -seat_overlap, z0],
            [-seat_overlap, -seat_overlap, z1],
            [-seat_overlap, seat_depth, z1],
            [len + seat_overlap, -seat_overlap, z0],
            [len + seat_overlap, -seat_overlap, z1],
            [len + seat_overlap, seat_depth, z1]
        ],
        faces=[
            [0, 3, 4, 1],
            [1, 4, 5, 2],
            [0, 2, 5, 3],
            [0, 1, 2],
            [3, 5, 4]
        ]
    );
}

module y_seat_rail(len) {
    z0 = seat_z - seat_slope_h;
    z1 = seat_z;

    polyhedron(
        points=[
            [-seat_overlap, -seat_overlap, z0],
            [-seat_overlap, -seat_overlap, z1],
            [seat_depth, -seat_overlap, z1],
            [-seat_overlap, len + seat_overlap, z0],
            [-seat_overlap, len + seat_overlap, z1],
            [seat_depth, len + seat_overlap, z1]
        ],
        faces=[
            [0, 3, 4, 1],
            [1, 4, 5, 2],
            [0, 2, 5, 3],
            [0, 1, 2],
            [3, 5, 4]
        ]
    );
}

module raw_body() {
    union() {
        // 底板
        cube([box_w, box_d, bottom_t], center=false);

        // 四面完整侧墙
        cube([wall, box_d, box_h], center=false);
        translate([box_w - wall, 0, 0])
            cube([wall, box_d, box_h], center=false);
        cube([box_w, wall, box_h], center=false);
        translate([0, box_d - wall, 0])
            cube([box_w, wall, box_h], center=false);

        // 盖子托台：45度斜撑托住盖板，直立打印无需支撑。
        translate([wall, wall, 0])
            x_seat_rail(inner_w);
        translate([wall, box_d - wall, 0])
            mirror([0, 1, 0])
                x_seat_rail(inner_w);
        translate([wall, wall + seat_depth, 0])
            y_seat_rail(inner_d - 2 * seat_depth);
        translate([box_w - wall, wall + seat_depth, 0])
            mirror([1, 0, 0])
                y_seat_rail(inner_d - 2 * seat_depth);
    }
}

module outer_corner_chamfers() {
    translate([0, 0, -eps])
        linear_extrude(height=box_h + 2 * eps)
            polygon([
                [-eps, -eps],
                [corner_chamfer, -eps],
                [-eps, corner_chamfer]
            ]);

    translate([0, 0, -eps])
        linear_extrude(height=box_h + 2 * eps)
            polygon([
                [box_w + eps, -eps],
                [box_w - corner_chamfer, -eps],
                [box_w + eps, corner_chamfer]
            ]);

    translate([0, 0, -eps])
        linear_extrude(height=box_h + 2 * eps)
            polygon([
                [-eps, box_d + eps],
                [corner_chamfer, box_d + eps],
                [-eps, box_d - corner_chamfer]
            ]);

    translate([0, 0, -eps])
        linear_extrude(height=box_h + 2 * eps)
            polygon([
                [box_w + eps, box_d + eps],
                [box_w - corner_chamfer, box_d + eps],
                [box_w + eps, box_d - corner_chamfer]
            ]);
}

module box_body() {
    difference() {
        raw_body();

        // 前侧开一个小缺口，方便手指掀起嵌入式盖子。
        translate([(box_w - front_pick_w) / 2, -eps, box_h - front_pick_h])
            cube([front_pick_w, wall + 2 * eps, front_pick_h + eps], center=false);

        outer_corner_chamfers();
    }
}

module lid_skirt() {
    difference() {
        cube([skirt_w, skirt_d, skirt_h], center=false);

        translate([skirt_wall, skirt_wall, -eps])
            cube([
                skirt_w - 2 * skirt_wall,
                skirt_d - 2 * skirt_wall,
                skirt_h + 2 * eps
            ], center=false);
    }
}

module inset_lid() {
    union() {
        difference() {
            translate([0, 0, skirt_h])
                cube([lid_w, lid_d, lid_t], center=false);

            // 顶部浅槽，便于抠起盖子；不打穿盖板。
            translate([(lid_w - 18) / 2, 1.6, skirt_h + lid_t - lid_grip_depth])
                cube([18, 7, lid_grip_depth + eps], center=false);
        }

        translate([skirt_x, skirt_y, 0])
            lid_skirt();
    }
}

module inset_lid_print_orientation() {
    // 盖子单独打印时顶面朝下，盖板贴热床，内塞裙边向上生长。
    translate([0, lid_d, skirt_h + lid_t])
        rotate([180, 0, 0])
            inset_lid();
}

module closed_assembly() {
    box_body();
    translate([lid_x, lid_y, seat_z - skirt_h])
        inset_lid();
}

module open_demo_assembly() {
    box_body();
    translate([lid_x, lid_y - 8, box_h + 4])
        inset_lid();
}

if (part_id == 1) {
    box_body();
} else if (part_id == 2) {
    inset_lid_print_orientation();
} else if (part_id == 3) {
    open_demo_assembly();
} else {
    closed_assembly();
}
