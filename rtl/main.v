module main_scene (
    input wire visible,
    input wire [9:0] x,
    input wire [9:0] y,
    input wire btnU,
    input wire btnD,
    input wire btnL,
    input wire btnR,
    input wire btnC,
    input wire btn1,
    input wire btn2,
    input wire btn3,
    input wire btn4,
    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue
);
    localparam TILE_SIZE = 26;
    localparam GRID_WIDTH = 24;
    localparam GRID_HEIGHT = 18;
    localparam MAX_ENEMIES = 24;
    localparam MAX_TOWERS = 48;
    localparam MAX_PROJECTILES = 48;
    localparam TOWER_RANGE = 100;
    localparam PROJECTILE_SPEED = 8;
    localparam ENEMY_SPEED = 1;
    localparam TOWER_COST = 50;
    localparam TOWER_UPGRADE_COST = 100;
    localparam ENEMY_REWARD = 10;
    localparam TOWER_SELL_RATIO = 70;
    localparam MAX_LIVES = 10;
    localparam STATE_MENU = 0;
    localparam STATE_GAME = 1;
    localparam STATE_SHOP = 2;
    localparam STATE_GAMEOVER = 3;
    localparam STATE_HIGHSCORE = 4;
    localparam TOWER_BASIC = 0;
    localparam TOWER_FAST = 1;
    localparam TOWER_HEAVY = 2;
    localparam TOWER_SLOW = 3;

    reg [2:0] game_state = STATE_MENU;
    reg [15:0] currency = 200;
    reg [7:0] lives = MAX_LIVES;
    reg [31:0] score = 0;
    reg [31:0] highscore = 0;
    reg [15:0] wave_number = 0;
    reg [19:0] frame_counter = 0;
    reg [19:0] spawn_timer = 0;
    reg paused = 0;
	reg [15:0] min_dist;
	reg [7:0] best_target;
    reg [15:0] _dist;
    reg [9:0] nx, ny;
    
    reg [4:0] cursor_x = 12;
    reg [4:0] cursor_y = 9;
    reg btnU_prev = 0;
    reg btnD_prev = 0;
    reg btnL_prev = 0;
    reg btnR_prev = 0;
    reg btnC_prev = 0;
    reg btn1_prev = 0;
    reg btn2_prev = 0;
    reg btn3_prev = 0;
    reg btn4_prev = 0;
    reg [3:0] btn_delay = 0;
    reg [1:0] selected_tower_type = TOWER_BASIC;
    reg tower_found;
    reg enemy_found;
    reg position_empty;
    reg [7:0] selected_tower_idx;
    reg [9:0] tower_px, tower_py;
    reg [9:0] range;
    reg signed [10:0] dx, dy;
	reg [10:0] abs_dx, abs_dy, move_x, move_y;
    reg [15:0] damage;
    reg [9:0] ex, ey;
    reg [19:0] pos;
    reg [3:0] health_ratio;
    reg [9:0] cx, cy;
    reg [15:0] sell_value;
    reg [1:0] indicator_type;

    function is_path;
        input [9:0] px;
        input [9:0] py;
        begin
            is_path = ((py >= 60 && py <= 86) && (px >= 0 && px <= 520)) ||
                      ((px >= 494 && px <= 520) && (py >= 60 && py <= 320)) ||
                      ((py >= 294 && py <= 320) && (px >= 120 && px <= 520)) ||
                      ((px >= 120 && px <= 146) && (py >= 164 && py <= 320)) ||
                      ((py >= 164 && py <= 190) && (px >= 120 && px <= 400)) ||
                      ((px >= 374 && px <= 400) && (py >= 164 && py <= 420)) ||
                      ((py >= 394 && py <= 420) && (px >= 26 && px <= 400));
        end
    endfunction

    reg [9:0] enemy_x [0:MAX_ENEMIES-1];
    reg [9:0] enemy_y [0:MAX_ENEMIES-1];
    reg [15:0] enemy_health [0:MAX_ENEMIES-1];
    reg [15:0] enemy_max_health [0:MAX_ENEMIES-1];
    reg enemy_active [0:MAX_ENEMIES-1];
    reg [15:0] enemy_progress [0:MAX_ENEMIES-1];
    reg [7:0] enemy_slow [0:MAX_ENEMIES-1];
    
    reg [4:0] tower_x [0:MAX_TOWERS-1];
    reg [4:0] tower_y [0:MAX_TOWERS-1];
    reg [1:0] tower_type [0:MAX_TOWERS-1];
    reg [2:0] tower_level [0:MAX_TOWERS-1];
    reg tower_active [0:MAX_TOWERS-1];
    reg [7:0] tower_cooldown [0:MAX_TOWERS-1];
    reg [7:0] tower_target [0:MAX_TOWERS-1];
    
    reg [9:0] proj_x [0:MAX_PROJECTILES-1];
    reg [9:0] proj_y [0:MAX_PROJECTILES-1];
    reg [9:0] proj_target_x [0:MAX_PROJECTILES-1];
    reg [9:0] proj_target_y [0:MAX_PROJECTILES-1];
    reg proj_active [0:MAX_PROJECTILES-1];
    reg [1:0] proj_type [0:MAX_PROJECTILES-1];
    
    integer i, j, k;
    initial begin
        for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
            enemy_active[i] = 0;
            enemy_x[i] = 0;
            enemy_y[i] = 0;
            enemy_health[i] = 0;
            enemy_max_health[i] = 0;
            enemy_progress[i] = 0;
            enemy_slow[i] = 0;
        end
        for (i = 0; i < MAX_TOWERS; i = i + 1) begin
            tower_active[i] = 0;
            tower_x[i] = 0;
            tower_y[i] = 0;
            tower_type[i] = 0;
            tower_level[i] = 0;
            tower_cooldown[i] = 0;
            tower_target[i] = 255;
        end
        for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
            proj_active[i] = 0;
            proj_x[i] = 0;
            proj_y[i] = 0;
            proj_target_x[i] = 0;
            proj_target_y[i] = 0;
            proj_type[i] = 0;
        end
    end
    
    wire new_frame = (x == 0 && y == 0);
    
    wire btnU_pressed = btnU && !btnU_prev;
    wire btnD_pressed = btnD && !btnD_prev;
    wire btnL_pressed = btnL && !btnL_prev;
    wire btnR_pressed = btnR && !btnR_prev;
    wire btnC_pressed = btnC && !btnC_prev;
    wire btn1_pressed = btn1 && !btn1_prev;
    wire btn2_pressed = btn2 && !btn2_prev;
    wire btn3_pressed = btn3 && !btn3_prev;
    wire btn4_pressed = btn4 && !btn4_prev;
    
    function [19:0] get_enemy_position;
        input [15:0] progress;
        reg [9:0] ex, ey;
        reg [15:0] p;
        begin
            p = progress;
            if (p < 507) begin
                ex = p;
                ey = 73;
            end else if (p < 741) begin
                ex = 507;
                ey = 73 + (p - 507);
            end else if (p < 1115) begin
                ex = 507 - (p - 741);
                ey = 307;
            end else if (p < 1245) begin
                ex = 133;
                ey = 307 - (p - 1115);
            end else if (p < 1499) begin
                ex = 133 + (p - 1245);
                ey = 177;
            end else if (p < 1729) begin
                ex = 387;
                ey = 177 + (p - 1499);
            end else begin
                ex = 387 - (p - 1729);
                ey = 407;
            end
            get_enemy_position = {ex, ey};
        end
    endfunction
    
    always @(posedge new_frame) begin
        frame_counter <= frame_counter + 1;
        btnU_prev <= btnU;
        btnD_prev <= btnD;
        btnL_prev <= btnL;
        btnR_prev <= btnR;
        btnC_prev <= btnC;
        btn1_prev <= btn1;
        btn2_prev <= btn2;
        btn3_prev <= btn3;
        btn4_prev <= btn4;
        
        if (btn_delay > 0)
            btn_delay <= btn_delay - 1;
        
        case (game_state)
            STATE_MENU: begin
                if (btnC_pressed) begin
                    game_state <= STATE_GAME;
                    currency <= 200;
                    lives <= MAX_LIVES;
                    score <= 0;
                    wave_number <= 0;
                    spawn_timer <= 0;
                    paused <= 0;
                    for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                        enemy_active[i] = 0;
                    end
                    for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                        tower_active[i] = 0;
                    end
                    for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
                        proj_active[i] = 0;
                    end
                end else if (btn4_pressed) begin
                    game_state <= STATE_HIGHSCORE;
                end
            end
            
            STATE_GAME: begin
                if (btn4_pressed) begin
                    paused <= !paused;
                end
                
                if (!paused) begin
                    if ((btnU_pressed || (btnU && btn_delay == 0)) && cursor_y > 0) begin
                        cursor_y <= cursor_y - 1;
                        btn_delay <= btnU_pressed ? 0 : 3;
                    end
                    if ((btnD_pressed || (btnD && btn_delay == 0)) && cursor_y < GRID_HEIGHT-1) begin
                        cursor_y <= cursor_y + 1;
                        btn_delay <= btnD_pressed ? 0 : 3;
                    end
                    if ((btnL_pressed || (btnL && btn_delay == 0)) && cursor_x > 0) begin
                        cursor_x <= cursor_x - 1;
                        btn_delay <= btnL_pressed ? 0 : 3;
                    end
                    if ((btnR_pressed || (btnR && btn_delay == 0)) && cursor_x < GRID_WIDTH-1) begin
                        cursor_x <= cursor_x + 1;
                        btn_delay <= btnR_pressed ? 0 : 3;
                    end
                    
                    if (btn1_pressed) selected_tower_type <= TOWER_BASIC;
                    if (btn2_pressed) selected_tower_type <= TOWER_FAST;
                    if (btn3_pressed) selected_tower_type <= TOWER_HEAVY;
                    if (btn4_pressed && !btnC) selected_tower_type <= TOWER_SLOW;
                    if (btnC_pressed) begin
                        cx = cursor_x * TILE_SIZE + 13;
                        cy = cursor_y * TILE_SIZE + 13;
                        
                        if (!is_path(cx, cy)) begin
                            position_empty = 1;
                            selected_tower_idx = 255;
                            for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                                if (tower_active[i] && tower_x[i] == cursor_x && tower_y[i] == cursor_y) begin
                                    position_empty = 0;
                                    selected_tower_idx = i;
                                end
                            end
                            
                            if (position_empty && currency >= TOWER_COST) begin
                                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                                    if (!tower_active[i]) begin
                                        tower_active[i] = 1;
                                        tower_x[i] = cursor_x;
                                        tower_y[i] = cursor_y;
                                        tower_type[i] = selected_tower_type;
                                        tower_level[i] = 0;
                                        tower_cooldown[i] = 0;
                                        tower_target[i] = 255;
                                        currency <= currency - TOWER_COST;
                                        i = MAX_TOWERS;
                                    end
                                end
                            end else if (!position_empty && btnL) begin
                                if (selected_tower_idx < MAX_TOWERS) begin
                                    sell_value = (TOWER_COST + tower_level[selected_tower_idx] * TOWER_UPGRADE_COST) * TOWER_SELL_RATIO / 100;
                                    currency <= currency + sell_value;
                                    tower_active[selected_tower_idx] = 0;
                                end
                            end else if (!position_empty && btnR && currency >= TOWER_UPGRADE_COST) begin
                                if (selected_tower_idx < MAX_TOWERS && tower_level[selected_tower_idx] < 3) begin
                                    tower_level[selected_tower_idx] = tower_level[selected_tower_idx] + 1;
                                    currency <= currency - TOWER_UPGRADE_COST;
                                end
                            end
                        end
                    end
                    
                    spawn_timer <= spawn_timer + 1;
                    if (spawn_timer >= 100) begin
                        spawn_timer <= 0;
                        for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                            if (!enemy_active[i]) begin
                                enemy_active[i] = 1;
                                enemy_progress[i] = 0;
                                enemy_health[i] = 25 + wave_number * 10;
                                enemy_max_health[i] = 25 + wave_number * 10;
                                enemy_slow[i] = 0;
                                pos = get_enemy_position(0);
                                enemy_x[i] = pos[19:10];
                                enemy_y[i] = pos[9:0];
                                i = MAX_ENEMIES;
                            end
                        end
                        wave_number <= wave_number + 1;
                    end
                    
                    for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                        if (enemy_active[i]) begin
                            if (enemy_slow[i] > 0) begin
                                enemy_slow[i] = enemy_slow[i] - 1;
                                if (frame_counter[0] == 0)
                                    enemy_progress[i] = enemy_progress[i] + ENEMY_SPEED;
                            end else begin
                                enemy_progress[i] = enemy_progress[i] + ENEMY_SPEED + (wave_number >> 3);
                            end
                            
                            pos = get_enemy_position(enemy_progress[i]);
                            enemy_x[i] = pos[19:10];
                            enemy_y[i] = pos[9:0];
                            
                            if (enemy_progress[i] > 2200) begin
                                enemy_active[i] = 0;
                                lives <= (lives > 0) ? lives - 1 : 0;
                                if (lives == 1) begin
                                    game_state <= STATE_GAMEOVER;
                                    if (score > highscore)
                                        highscore <= score;
                                end
                            end
                            
                            if (enemy_health[i] == 0) begin
                                enemy_active[i] = 0;
                                currency <= currency + ENEMY_REWARD + (wave_number >> 2);
                                score <= score + 10 + wave_number;
                            end
                        end
                    end
                    
                    for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                        if (tower_active[i]) begin
                            if (tower_cooldown[i] > 0) begin
                                tower_cooldown[i] = tower_cooldown[i] - 1;
                            end else begin
                                tower_px = tower_x[i] * TILE_SIZE + 13;
                                tower_py = tower_y[i] * TILE_SIZE + 13;
                                range = TOWER_RANGE + tower_level[i] * 20;
                                
                                min_dist = 16'hFFFF;
                                best_target = 255;
                                
                                for (j = 0; j < MAX_ENEMIES; j = j + 1) begin
                                    if (enemy_active[j]) begin
                                        dx = $signed({1'b0, enemy_x[j]}) - $signed({1'b0, tower_px});
                                        dy = $signed({1'b0, enemy_y[j]}) - $signed({1'b0, tower_py});
                                        
                                        _dist = (dx[10] ? -dx : dx) + (dy[10] ? -dy : dy);
                                        
                                        if (_dist < range && _dist < min_dist) begin
                                            min_dist = _dist;
                                            best_target = j;
                                        end
                                    end
                                end
                                
                                if (best_target < 255) begin
                                    tower_target[i] = best_target;
                                    
                                    for (k = 0; k < MAX_PROJECTILES; k = k + 1) begin
                                        if (!proj_active[k]) begin
                                            proj_active[k] = 1;
                                            proj_x[k] = tower_px;
                                            proj_y[k] = tower_py;
                                            proj_target_x[k] = enemy_x[best_target];
                                            proj_target_y[k] = enemy_y[best_target];
                                            proj_type[k] = tower_type[i];
                                            
                                            case (tower_type[i])
                                                TOWER_BASIC: damage = 10 + tower_level[i] * 5;
                                                TOWER_FAST: damage = 5 + tower_level[i] * 3;
                                                TOWER_HEAVY: damage = 25 + tower_level[i] * 10;
                                                TOWER_SLOW: damage = 5 + tower_level[i] * 2;
                                            endcase
                                            
                                            if (enemy_health[best_target] > damage) begin
                                                enemy_health[best_target] = enemy_health[best_target] - damage;
                                            end else begin
                                                enemy_health[best_target] = 0;
                                            end
                                            
                                            if (tower_type[i] == TOWER_SLOW) begin
                                                enemy_slow[best_target] = 60;
                                            end
                                            
                                            k = MAX_PROJECTILES;
                                        end
                                    end
                                    
                                    case (tower_type[i])
                                        TOWER_BASIC: tower_cooldown[i] = 30 - tower_level[i] * 3;
                                        TOWER_FAST: tower_cooldown[i] = 10 - tower_level[i];
                                        TOWER_HEAVY: tower_cooldown[i] = 60 - tower_level[i] * 5;
                                        TOWER_SLOW: tower_cooldown[i] = 40 - tower_level[i] * 4;
                                    endcase
                                end else begin
                                    tower_target[i] = 255;
                                end
                            end
                        end
                    end
                    
                    for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
                        if (proj_active[i]) begin
                            dx = $signed({1'b0, proj_target_x[i]}) - $signed({1'b0, proj_x[i]});
                            dy = $signed({1'b0, proj_target_y[i]}) - $signed({1'b0, proj_y[i]});
                            
                            if ((dx[10] ? -dx : dx) < 10 && (dy[10] ? -dy : dy) < 10) begin
                                proj_active[i] = 0;
                            end else begin
                                abs_dx = dx[10] ? -dx : dx;
                                abs_dy = dy[10] ? -dy : dy;
                                
                                if (abs_dx > abs_dy) begin
                                    move_x = dx[10] ? -PROJECTILE_SPEED : PROJECTILE_SPEED;
                                    move_y = (PROJECTILE_SPEED * abs_dy) / abs_dx;
                                    if (dy[10]) move_y = -move_y;
                                end else if (abs_dy > 0) begin
                                    move_y = dy[10] ? -PROJECTILE_SPEED : PROJECTILE_SPEED;
                                    move_x = (PROJECTILE_SPEED * abs_dx) / abs_dy;
                                    if (dx[10]) move_x = -move_x;
                                end else begin
                                    move_x = 0;
                                    move_y = 0;
                                end
                                
                                proj_x[i] = proj_x[i] + move_x;
                                proj_y[i] = proj_y[i] + move_y;
                                if (proj_x[i] > 640 || proj_y[i] > 480) begin
                                    proj_active[i] = 0;
                                end
                            end
                        end
                    end
                end
            end
            
            STATE_GAMEOVER: begin
                if (btnC_pressed)
                    game_state <= STATE_MENU;
            end
            
            STATE_HIGHSCORE: begin
                if (btnC_pressed || btn4_pressed)
                    game_state <= STATE_MENU;
            end
        endcase
    end
    
    wire [4:0] grid_x = x / TILE_SIZE;
    wire [4:0] grid_y = y / TILE_SIZE;
    wire [4:0] pixel_x = x % TILE_SIZE;
    wire [4:0] pixel_y = y % TILE_SIZE;
    
    always @* begin
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;
        
        if (visible) begin
            case (game_state)
                STATE_MENU: begin
                    if (y >= 100 && y < 140 && x >= 160 && x < 480) begin
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'hF;
                    end
                    if (y >= 200 && y < 220 && x >= 230 && x < 410) begin
                        red = 4'h8;
                        green = 4'hF;
                        blue = 4'h8;
                    end
                    if (y >= 250 && y < 270 && x >= 210 && x < 430) begin
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'h8;
                    end
                end
                
                STATE_GAME: begin
                    red = 4'h1;
                    green = 4'h1;
                    blue = 4'h1;
                    if (pixel_x == 0 || pixel_y == 0) begin
                        red = 4'h2;
                        green = 4'h2;
                        blue = 4'h2;
                    end
                    if (is_path(x, y)) begin
                        red = 4'h5;
                        green = 4'h3;
                        blue = 4'h2;
                    end
                    tower_found = 0;
                    for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                        if (tower_active[i] && grid_x == tower_x[i] && grid_y == tower_y[i]) begin
                            if (pixel_x >= 6 && pixel_x <= 19 && pixel_y >= 6 && pixel_y <= 19) begin
                                case (tower_type[i])
                                    TOWER_BASIC: begin
                                        red = 4'h5 + tower_level[i];
                                        green = 4'h5 + tower_level[i];
                                        blue = 4'hD + tower_level[i];
                                    end
                                    TOWER_FAST: begin
                                        red = 4'h5 + tower_level[i];
                                        green = 4'hD + tower_level[i];
                                        blue = 4'h5 + tower_level[i];
                                    end
                                    TOWER_HEAVY: begin
                                        red = 4'hD + tower_level[i];
                                        green = 4'h5 + tower_level[i];
                                        blue = 4'h5 + tower_level[i];
                                    end
                                    TOWER_SLOW: begin
                                        red = 4'hD + tower_level[i];
                                        green = 4'h5 + tower_level[i];
                                        blue = 4'hD + tower_level[i];
                                    end
                                endcase
                                tower_found = 1;
                            end
                            if (tower_target[i] < MAX_ENEMIES && enemy_active[tower_target[i]]) begin
                                reg signed [10:0] ndx, ndy;
                                reg signed [10:0] tpx, tpy;
                                tpx = tower_x[i] * TILE_SIZE + 13;
                                tpy = tower_y[i] * TILE_SIZE + 13;
                                ndx = $signed({1'b0, enemy_x[tower_target[i]]}) - $signed({1'b0, tpx});
                                ndy = $signed({1'b0, enemy_y[tower_target[i]]}) - $signed({1'b0, tpy});
                                if ((ndx[10] ? -ndx : ndx) > (ndy[10] ? -ndy : ndy)) begin
                                    nx = tpx + (ndx[10] ? -8 : 8);
                                    ny = tpy + (ndy[10] ? -(8 * (ndy[10] ? -ndy : ndy) / (ndx[10] ? -ndx : ndx)) : 
                                                           (8 * (ndy[10] ? -ndy : ndy) / (ndx[10] ? -ndx : ndx)));
                                end else begin
                                    ny = tpy + (ndy[10] ? -8 : 8);
                                    nx = tpx + (ndx[10] ? -(8 * (ndx[10] ? -ndx : ndx) / (ndy[10] ? -ndy : ndy)) : 
                                                           (8 * (ndx[10] ? -ndx : ndx) / (ndy[10] ? -ndy : ndy)));
                                end
                                
                                if ((x >= tpx-1 && x <= tpx+1 && y >= tpy-1 && y <= tpy+1) ||
                                    (x >= nx-1 && x <= nx+1 && y >= ny-1 && y <= ny+1)) begin
                                    red = 4'h8;
                                    green = 4'h8;
                                    blue = 4'h8;
                                end
                            end
                        end
                    end
                    for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
                        if (proj_active[i]) begin
                            if (x >= proj_x[i]-1 && x <= proj_x[i]+1 && y >= proj_y[i]-1 && y <= proj_y[i]+1) begin
                                case (proj_type[i])
                                    TOWER_BASIC: begin
                                        red = 4'hA;
                                        green = 4'hA;
                                        blue = 4'hF;
                                    end
                                    TOWER_FAST: begin
                                        red = 4'hA;
                                        green = 4'hF;
                                        blue = 4'hA;
                                    end
                                    TOWER_HEAVY: begin
                                        red = 4'hF;
                                        green = 4'hA;
                                        blue = 4'hA;
                                    end
                                    TOWER_SLOW: begin
                                        red = 4'hF;
                                        green = 4'hA;
                                        blue = 4'hF;
                                    end
                                endcase
                            end
                        end
                    end
                    enemy_found = 0;
                    for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                        if (enemy_active[i]) begin
                            ex = enemy_x[i];
                            ey = enemy_y[i];
                            
                            if (x >= ex-7 && x <= ex+7 && y >= ey-7 && y <= ey+7) begin
                                if (enemy_slow[i] > 0) begin
                                    red = 4'h7;
                                    green = 4'h3;
                                    blue = 4'hB;
                                end else begin
                                    red = 4'hD;
                                    green = 4'h2;
                                    blue = 4'h2;
                                end
                                enemy_found = 1;
                            end
                            
                            if (y >= ey-10 && y <= ey-8 && x >= ex-7 && x <= ex+7) begin
                                health_ratio = (enemy_health[i] * 4'd14) / enemy_max_health[i];
                                if ((x - ex + 7) <= {6'b0, health_ratio}) begin
                                    red = 4'h0;
                                    green = 4'hD;
                                    blue = 4'h0;
                                end else begin
                                    red = 4'h3;
                                    green = 4'h0;
                                    blue = 4'h0;
                                end
                            end
                        end
                    end
                    if (grid_x == cursor_x && grid_y == cursor_y) begin
                        if ((pixel_y == 12 || pixel_y == 13) && pixel_x >= 7 && pixel_x <= 18) begin
                            red = 4'hF;
                            green = 4'hF;
                            blue = 4'h0;
                        end
                        if ((pixel_x == 12 || pixel_x == 13) && pixel_y >= 7 && pixel_y <= 18) begin
                            red = 4'hF;
                            green = 4'hF;
                            blue = 4'h0;
                        end
                    end
                    if (y < 25) begin
                        red = 4'h2;
                        green = 4'h2;
                        blue = 4'h2;
                        
                        if (x >= 10 && x < 90) begin
                            if (x < 10 + {2'b0, lives, 3'b0}) begin
                                red = 4'hF;
                                green = 4'h4;
                                blue = 4'h4;
                            end
                        end
                        else if (x >= 150 && x < 250) begin
                            red = 4'hF;
                            green = 4'hF;
                            blue = 4'h0;
                        end
                        else if (x >= 300 && x < 380) begin
                            red = 4'h8;
                            green = 4'h8;
                            blue = 4'hF;
                        end
                        else if (x >= 430 && x < 530) begin
                            red = 4'hF;
                            green = 4'hF;
                            blue = 4'hF;
                        end
                        if (paused && x >= 580 && x < 630) begin
                            red = 4'hF;
                            green = 4'h8;
                            blue = 4'h0;
                        end
                    end
                    if (y >= 455 && y < 475) begin
                        red = 4'h2;
                        green = 4'h2;
                        blue = 4'h2;
                        
                        if (x >= 200 && x < 440) begin
                            indicator_type = (x - 200) / 60;
                            
                            if (indicator_type == selected_tower_type) begin
                                red = 4'h4;
                                green = 4'h4;
                                blue = 4'h4;
                            end
                            
                            if ((x - 200) % 60 >= 10 && (x - 200) % 60 < 50) begin
                                case (indicator_type)
                                    TOWER_BASIC: begin
                                        red = (red < 4'h8) ? red + 4'h8 : 4'hF;
                                        green = (green < 4'h8) ? green + 4'h8 : 4'hF;
                                        blue = 4'hF;
                                    end
                                    TOWER_FAST: begin
                                        red = (red < 4'h8) ? red + 4'h8 : 4'hF;
                                        green = 4'hF;
                                        blue = (blue < 4'h8) ? blue + 4'h8 : 4'hF;
                                    end
                                    TOWER_HEAVY: begin
                                        red = 4'hF;
                                        green = (green < 4'h8) ? green + 4'h8 : 4'hF;
                                        blue = (blue < 4'h8) ? blue + 4'h8 : 4'hF;
                                    end
                                    TOWER_SLOW: begin
                                        red = 4'hF;
                                        green = (green < 4'h8) ? green + 4'h8 : 4'hF;
                                        blue = 4'hF;
                                    end
                                endcase
                            end
                        end
                    end
                end
                
                STATE_GAMEOVER: begin
                    if (y >= 180 && y < 220 && x >= 200 && x < 440) begin
                        red = 4'hF;
                        green = 4'h0;
                        blue = 4'h0;
                    end
                    if (y >= 240 && y < 260 && x >= 220 && x < 420) begin
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'hF;
                    end
                    if (y >= 300 && y < 320 && x >= 210 && x < 430) begin
                        red = 4'h8;
                        green = 4'h8;
                        blue = 4'h8;
                    end
                end
                
                STATE_HIGHSCORE: begin
                    if (y >= 150 && y < 190 && x >= 200 && x < 440) begin
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'h0;
                    end
                    if (y >= 220 && y < 260 && x >= 240 && x < 400) begin
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'hF;
                    end
                    if (y >= 300 && y < 320 && x >= 210 && x < 430) begin
                        red = 4'h8;
                        green = 4'h8;
                        blue = 4'h8;
                    end
                end
            endcase
        end
    end
endmodule
