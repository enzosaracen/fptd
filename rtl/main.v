module font_rom(
	input wire clk,
    input wire [7:0] char,
    input wire [3:0] row,
    output reg [7:0] bits
);
	(* ram_style="block" *) reg [7:0] mem [0:2047];

	localparam [5375:0] FONT_BITS = 5376'h000000001818181818181c3663630000000000006363361c1c1c1c36636300000000000063777f6b636363636363000000000000081c36636363636363630000000000003e7f63636363636363630000000000000c0c0c0c0c0c0c0c7f7f0000000000003e7f60607e3f03037f3e0000000000006363331b3f7f63637f3f00000000000060367f6b636363637f3f000000000000030303033f7f63637f3f0000000000003e7f6363636363637f3e000000000000636363737b7f6f67636300000000000063636363636b7f7763630000000000007f7f030303030303030300000000000063331b0f07070f1b33630000000000001e1f1818181818187f7f0000000000007f7f0c0c0c0c0c0c7f7f000000000000636363637f7f636363630000000000006e7f63637f7f03037f3e000000000000030303033f3f03037f7f0000000000007f7f03033f3f03037f7f0000000000003f7f6363636363637f3f0000000000003e7f0303030303037f3e0000000000003f7f63633f3f63637f3f0000000000006363637f7f6363361c080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007e007e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018180000181800000000000000007f7f60607f7f63637f7f0000000000007f7f63637f7f63637f7f00000000000060606060606060607f7f0000000000007f7f63637f7f03037f7f0000000000007f7f60607f7f03037f7f000000000000606060607f7f636363630000000000007f7f60607c7c60607f7f0000000000007f7f03037f7f60607f7f0000000000007e7e18181818181e1c180000000000001c36636363636363361c0000;

	integer i;
	initial begin
		for (i = 0; i < 672; i = i + 1)
			mem[i] = FONT_BITS[i*8+:8];
	end

	always @(posedge clk)
		bits <= mem[{char, row}];
endmodule

module main_scene (
    input wire clk,
    input wire rst_n,
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
    localparam MAX_ENEMIES = 16;
    localparam MAX_TOWERS = 8;
    localparam MAX_PROJECTILES = 32;
    localparam TOWER_RANGE = 100;
    localparam PROJECTILE_SPEED = 8;
    localparam ENEMY_SPEED = 1;
    localparam TOWER_COST = 50;
    localparam TOWER_UPGRADE_COST = 100;
    localparam ENEMY_REWARD = 10;
    localparam TOWER_SELL_RATIO = 70;
    localparam MAX_LIVES = 10;
    localparam MAX_HIGHSCORES = 3;
    
    localparam STATE_MENU = 0;
    localparam STATE_GAME = 1;
    localparam STATE_SHOP = 2;
    localparam STATE_GAMEOVER = 3;
    localparam STATE_HIGHSCORE = 4;
    localparam STATE_TOWER_MENU = 5;
    
    localparam TOWER_BASIC = 0;
    localparam TOWER_FAST = 1;
    localparam TOWER_HEAVY = 2;
    localparam TOWER_SLOW = 3;
    
    localparam ENEMY_NORMAL = 0;

	localparam REPEAT_RATE = 10;
    
    reg [2:0] game_state = STATE_MENU;
    reg [15:0] currency = 200;
    reg [7:0] lives = MAX_LIVES;
    reg [31:0] score = 0;
    reg [31:0] highscores [0:MAX_HIGHSCORES-1];
    reg [15:0] wave_number = 0;
    reg [19:0] frame_counter = 0;
    reg [19:0] spawn_timer = 0;
    reg [7:0] enemies_in_wave = 0;
    reg [7:0] enemies_spawned = 0;
    reg paused = 0;
    
    reg [4:0] cursor_x = 12;
    reg [4:0] cursor_y = 9;
    reg [1:0] menu_selection = 0;
    reg [1:0] shop_selection = 0;
    reg [4:0] selected_tower_idx = 0;
    reg show_tower_range = 0;
    
    reg btnU_prev = 0;
    reg btnD_prev = 0;
    reg btnL_prev = 0;
    reg btnR_prev = 0;
    reg btnC_prev = 0;
    reg btn1_prev = 0;
    reg btn2_prev = 0;
    reg btn3_prev = 0;
    reg btn4_prev = 0;
    reg [5:0] btn_delay = 0;

    reg text_hit;

    reg [1:0] selected_tower_type = TOWER_BASIC;
    
    reg [9:0] enemy_x [0:MAX_ENEMIES-1];
    reg [9:0] enemy_y [0:MAX_ENEMIES-1];
    reg [15:0] enemy_health [0:MAX_ENEMIES-1];
    reg [15:0] enemy_max_health [0:MAX_ENEMIES-1];
    reg enemy_active [0:MAX_ENEMIES-1];
    reg [15:0] enemy_progress [0:MAX_ENEMIES-1];
    reg [7:0] enemy_slow [0:MAX_ENEMIES-1];
    reg [1:0] enemy_type [0:MAX_ENEMIES-1];
    
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
    
    localparam GAME_DIV = 8333;
    reg [$clog2(GAME_DIV)-1:0] game_clk_div = 0;
    wire game_tick = (game_clk_div == 0);
    
    reg [3:0] process_state = 0;
    reg [5:0] process_index = 0;
    
    localparam PROC_IDLE = 0;
    localparam PROC_UPDATE_ENEMIES = 1;
    localparam PROC_UPDATE_TOWERS = 2;
    localparam PROC_UPDATE_PROJECTILES = 3;
    localparam PROC_CHECK_COLLISIONS = 4;
    localparam PROC_SPAWN = 5;

    localparam ZONE_SIZE = 80;
    localparam ZONES_X = 8;
    localparam ZONES_Y = 6;
    
    wire [2:0] zone_x = x / ZONE_SIZE;
    wire [2:0] zone_y = y / ZONE_SIZE;
    reg frame_odd = 0;

	reg [9:0] x_d, y_d, x_pd, y_pd, x_ppd, y_ppd;
	reg vis_d, vis_pd, vis_ppd;
	always @(posedge clk) begin
		x_ppd <= x;
		y_ppd <= y;
		vis_ppd <= visible;
		x_pd <= x_ppd;
		y_pd <= y_ppd;
		vis_pd <= vis_ppd;
		x_d <= x_pd;
		y_d <= y_pd;
		vis_d <= vis_pd;
	end

	wire [4:0] grid_x_d  = x_d / TILE_SIZE;
	wire [4:0] grid_y_d  = y_d / TILE_SIZE;
	wire [4:0] pixel_x_d = x_d % TILE_SIZE;
	wire [4:0] pixel_y_d = y_d % TILE_SIZE;
	wire [2:0] zone_x_d  = x_d / ZONE_SIZE;
	wire [2:0] zone_y_d  = y_d / ZONE_SIZE;

	reg [7:0] glyph_char;
	reg [3:0] glyph_row;
	reg [2:0] glyph_col;
	wire [7:0] glyph_bits;

	font_rom FONT (
		.clk (clk),
		.char(glyph_char),
		.row (glyph_row),
		.bits(glyph_bits)
	);
	reg [2:0] col_r, col_p;
	reg [7:0] bits_r;
	wire font_bit;

	always @(posedge clk) begin
		col_p <= glyph_col;
		bits_r <= glyph_bits;
		col_r <= col_p;
	end

	assign font_bit = bits_r[col_r];

	function is_text_pixel;
		input [9:0] px, py;
		input [9:0] text_x, text_y;
		input [7:0] char_code;
		begin
			is_text_pixel = 0;
			if (px >= text_x && px < text_x + 8 && py >= text_y && py < text_y + 16) begin
				glyph_col = px - text_x;
				glyph_row = py - text_y;
				glyph_char = char_code;
				is_text_pixel = font_bit;
			end
		end
	endfunction

	task render_text;
		input [9:0] px, py;
		input [9:0] start_x, start_y;
		input [255:0] text_str;
		input [4:0] text_len;
		output hit;
		reg [4:0] idx;
		reg [7:0] char;
		begin
			hit = 0;
			if (px >= start_x && px < start_x + (text_len << 3)) begin
				idx = (px - start_x) >> 3;
				if (idx < text_len) begin
					char = text_str[((text_len-1-idx)<<3) +: 8]-8'h30;
					hit = is_text_pixel(px, py, start_x + (idx<<3), start_y, char);
				end
			end
		end
	endtask

	task render_number;
		input [9:0] px, py;
		input [9:0] start_x, start_y;
		input [31:0] num;
		input [3:0] digits;
		output hit;
		reg [3:0] digit_mem [0:9];
		reg [31:0] tmp;
		integer k;
		reg [4:0] col;
		reg [7:0] char;
		begin
			tmp = num;
			for (k = digits-1; k >= 0; k = k-1) begin
				digit_mem[k] = tmp % 10;
				tmp = tmp / 10;
			end
			hit = 0;
			if (px >= start_x && px < start_x + (digits << 3)) begin
				col = (px - start_x) >> 3;
				if (col < digits) begin
					char = digit_mem[col];
					hit = is_text_pixel(px, py, start_x + (col<<3), start_y, char);
				end
			end
		end
	endtask

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
                      ((py >= 394 && py <= 420) && (px >= 0 && px <= 400));
        end
    endfunction
    
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
    
	function is_range_pixel;
        input [9:0] px, py;
        input [9:0] cx, cy;
        input [9:0] range;
        reg signed [10:0] dx, dy;
        reg [19:0] dist_sq, range_sq, inner_sq;
        begin
            dx = $signed({1'b0, px}) - $signed({1'b0, cx});
            dy = $signed({1'b0, py}) - $signed({1'b0, cy});
            //dist_sq = abs(dx)+abs(dy);//dx * dx + dy * dy;
            dist_sq = dx * dx + dy * dy;
            range_sq = range * range;
            inner_sq = (range - 2) * (range - 2);
            is_range_pixel = (dist_sq <= range_sq) && (dist_sq >= inner_sq);
        end
    endfunction
    
    function [15:0] get_tower_cost;
        input [1:0] ttype;
        begin
            case (ttype)
                TOWER_BASIC: get_tower_cost = 50;
                TOWER_FAST: get_tower_cost = 75;
                TOWER_HEAVY: get_tower_cost = 150;
                TOWER_SLOW: get_tower_cost = 100;
            endcase
        end
    endfunction
    
    function [31:0] get_enemy_stats;
        input [1:0] etype;
        input [15:0] wave;
        reg [15:0] health;
        reg [7:0] speed;
        reg [7:0] reward;
        begin
            case (etype)
                ENEMY_NORMAL: begin
                    health = 20 + wave * 5;
                    speed = 1;
                    reward = 10 + wave / 4;
                end
				/*
                ENEMY_HEAVY: begin
                    health = 40 + wave * 8;
                    speed = 1;
                    reward = 20 + wave / 2;
                end*/
            endcase
            get_enemy_stats = {8'b0, reward, speed, health};
        end
    endfunction
    
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MAX_ENEMIES; init_i = init_i + 1) begin
            enemy_active[init_i] = 0;
        end
        for (init_i = 0; init_i < MAX_TOWERS; init_i = init_i + 1) begin
            tower_active[init_i] = 0;
        end
        for (init_i = 0; init_i < MAX_PROJECTILES; init_i = init_i + 1) begin
            proj_active[init_i] = 0;
        end
        for (init_i = 0; init_i < MAX_HIGHSCORES; init_i = init_i + 1) begin
            highscores[init_i] = 0;
        end
        game_clk_div = GAME_DIV-1;
    end
    
    task reset_game_state;
        integer i;
        begin
            currency <= 200;
            lives <= MAX_LIVES;
            score <= 0;
            wave_number <= 0;
            spawn_timer <= 0;
            paused <= 0;
            frame_counter <= 0;
            process_state <= PROC_IDLE;
            process_index <= 0;
            enemies_in_wave <= 5;
            enemies_spawned <= 0;
            
            for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                enemy_active[i] <= 0;
                enemy_health[i] <= 0;
                enemy_progress[i] <= 0;
                enemy_slow[i] <= 0;
            end
            
            for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                tower_active[i] <= 0;
                tower_cooldown[i] <= 0;
                tower_target[i] <= 255;
            end
            
            for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
                proj_active[i] <= 0;
            end
        end
    endtask
    
    task update_highscores;
        integer i;
        reg [31:0] temp;
        begin
            if (score > highscores[2]) begin
                highscores[2] <= score;
                for (i = 2; i > 0; i = i - 1) begin
                    if (highscores[i] > highscores[i-1]) begin
                        temp = highscores[i];
                        highscores[i] <= highscores[i-1];
                        highscores[i-1] <= temp;
                    end
                end
            end
        end
    endtask
    
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
    
    task handle_tower_action;
        reg [9:0] cx, cy;
        reg position_empty;
        reg [4:0] tower_idx;
        integer i, slot;
        reg found;
        begin
            cx = cursor_x * TILE_SIZE + 13;
            cy = cursor_y * TILE_SIZE + 13;
            
            if (!is_path(cx, cy)) begin
                position_empty = 1;
                tower_idx = 31;
                
                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                    if (tower_active[i] && tower_x[i] == cursor_x && tower_y[i] == cursor_y) begin
                        position_empty = 0;
                        tower_idx = i;
                    end
                end
                
                if (position_empty) begin
                    game_state <= STATE_SHOP;
                    shop_selection <= 0;
                end else begin
                    selected_tower_idx <= tower_idx;
                    game_state <= STATE_TOWER_MENU;
                    menu_selection <= 0;
                end
            end
        end
    endtask
    
    task place_tower;
        input [1:0] ttype;
        reg [15:0] cost;
        integer i, slot;
        reg found;
        begin
            cost = get_tower_cost(ttype);
            if (currency >= cost) begin
                found = 0;
                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                    if (!found && !tower_active[i]) begin
                        slot = i;
                        found = 1;
                    end
                end
                i = slot;
                if (found) begin
                    tower_active[i] <= 1;
                    tower_x[i] <= cursor_x;
                    tower_y[i] <= cursor_y;
                    tower_type[i] <= ttype;
                    tower_level[i] <= 0;
                    tower_cooldown[i] <= 0;
                    tower_target[i] <= 255;
                    currency <= currency - cost;
                    game_state <= STATE_GAME;
                end
            end
        end
    endtask
    
    task update_enemy;
        input [4:0] idx;
        reg [19:0] pos;
        reg [31:0] stats;
        reg [7:0] speed;
        begin
            stats = get_enemy_stats(enemy_type[idx], wave_number);
            speed = stats[23:16];
            
            if (enemy_slow[idx] > 0) begin
                enemy_slow[idx] <= enemy_slow[idx] - 1;
                if (frame_counter[0] == 0)
                    enemy_progress[idx] <= enemy_progress[idx] + speed;
            end else begin
                enemy_progress[idx] <= enemy_progress[idx] + speed;
            end
            
            pos = get_enemy_position(enemy_progress[idx]);
            enemy_x[idx] <= pos[19:10];
            enemy_y[idx] <= pos[9:0];
            
            if (enemy_progress[idx] > 2200) begin
                enemy_active[idx] <= 0;
                lives <= (lives > 0) ? lives - 1 : 0;
                if (lives == 0) begin
                    game_state <= STATE_GAMEOVER;
                    update_highscores();
                end
            end
            
            if (enemy_health[idx] == 0) begin
                enemy_active[idx] <= 0;
                currency <= currency + stats[31:24];
                score <= score + 10 + wave_number;
            end
        end
    endtask
    
    task update_tower;
        input [4:0] idx;
        reg [9:0] range;
        reg [15:0] min_dist;
        reg [7:0] best_target;
        reg signed [10:0] dx, dy;
        reg [15:0] _dist;
        reg [9:0] tower_px, tower_py;
        integer j;
        begin
            if (tower_cooldown[idx] > 0) begin
                tower_cooldown[idx] <= tower_cooldown[idx] - 1;
            end else begin
                tower_px = tower_x[idx] * TILE_SIZE + 13;
                tower_py = tower_y[idx] * TILE_SIZE + 13;
                range = TOWER_RANGE + tower_level[idx] * 20;
                
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
                    tower_target[idx] <= best_target;
                    fire_projectile(tower_px, tower_py, best_target, tower_type[idx], tower_level[idx]);
                    
                    case (tower_type[idx])
                        TOWER_BASIC: tower_cooldown[idx] <= 30 - tower_level[idx] * 3;
                        TOWER_FAST: tower_cooldown[idx] <= 10 - tower_level[idx];
                        TOWER_HEAVY: tower_cooldown[idx] <= 60 - tower_level[idx] * 5;
                        TOWER_SLOW: tower_cooldown[idx] <= 40 - tower_level[idx] * 4;
                    endcase
                end else begin
                    tower_target[idx] <= 255;
                end
            end
        end
    endtask
    
    task fire_projectile;
        input [9:0] px, py;
        input [7:0] target;
        input [1:0] ptype;
        input [2:0] level;
        reg [15:0] damage;
        integer k, slot;
        reg found;
        begin
            found = 0;
            for (k = 0; k < MAX_PROJECTILES; k = k + 1) begin
                if (!found && !proj_active[k]) begin
                    slot = k;
                    found = 1;
                end
            end
            k = slot;
            if (found) begin
                proj_active[k] <= 1;
                proj_x[k] <= px;
                proj_y[k] <= py;
                proj_target_x[k] <= enemy_x[target];
                proj_target_y[k] <= enemy_y[target];
                proj_type[k] <= ptype;
                
                case (ptype)
                    TOWER_BASIC: damage = 10 + level * 5;
                    TOWER_FAST: damage = 5 + level * 3;
                    TOWER_HEAVY: damage = 25 + level * 10;
                    TOWER_SLOW: damage = 5 + level * 2;
                endcase
                
                if (enemy_health[target] > damage) begin
                    enemy_health[target] <= enemy_health[target] - damage;
                end else begin
                    enemy_health[target] <= 0;
                end
                
                if (ptype == TOWER_SLOW) begin
                    enemy_slow[target] <= 60;
                end
            end
        end
    endtask
    
    task update_projectile;
        input [4:0] idx;
        reg signed [10:0] dx, dy;
        reg [10:0] abs_dx, abs_dy, move_x, move_y;
        begin
            dx = $signed({1'b0, proj_target_x[idx]}) - $signed({1'b0, proj_x[idx]});
            dy = $signed({1'b0, proj_target_y[idx]}) - $signed({1'b0, proj_y[idx]});
            
            if ((dx[10] ? -dx : dx) < 10 && (dy[10] ? -dy : dy) < 10) begin
                proj_active[idx] <= 0;
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
                
                proj_x[idx] <= proj_x[idx] + move_x;
                proj_y[idx] <= proj_y[idx] + move_y;
                
                if (proj_x[idx] > 640 || proj_y[idx] > 480) begin
                    proj_active[idx] <= 0;
                end
            end
        end
    endtask
    
    task spawn_enemy;
        reg [19:0] pos;
        reg [1:0] etype;
        reg [31:0] stats;
        integer i, slot;
        reg found;
        begin
			etype = ENEMY_NORMAL;
            /*if (wave_number < 5) begin
                etype = ENEMY_NORMAL;
            end else if (wave_number < 10) begin
                etype = (enemies_spawned[0] ? ENEMY_FAST : ENEMY_NORMAL);
            end else if (wave_number < 15) begin
                etype = (enemies_spawned % 3 == 0) ? ENEMY_HEAVY : 
                       (enemies_spawned[0] ? ENEMY_FAST : ENEMY_NORMAL);
            end else if (wave_number % 10 == 0) begin
                etype = ENEMY_BOSS;
            end else begin
                etype = enemies_spawned[1:0];
            end*/
            
            found = 0;
            for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                if (!found && !enemy_active[i]) begin
                    slot = i;
                    found = 1;
                end
            end
            i = slot;
            if (found) begin
                stats = get_enemy_stats(etype, wave_number);
                enemy_active[i] <= 1;
                enemy_type[i] <= etype;
                enemy_progress[i] <= 0;
                enemy_health[i] <= stats[15:0];
                enemy_max_health[i] <= stats[15:0];
                enemy_slow[i] <= 0;
                pos = get_enemy_position(0);
                enemy_x[i] <= pos[19:10];
                enemy_y[i] <= pos[9:0];
                enemies_spawned <= enemies_spawned + 1;
            end
        end
    endtask
    
    always @(posedge clk) begin
        if (game_clk_div == 0) begin
            game_clk_div <= GAME_DIV-1;
        end else begin
            game_clk_div <= game_clk_div - 1;
        end
        
        if (new_frame) begin
            frame_counter <= frame_counter + 1;
            frame_odd <= ~frame_odd;
            
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
            
            show_tower_range <= 0;
            begin: check_tower_range
                integer i;
                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                    if (tower_active[i] && tower_x[i] == cursor_x && tower_y[i] == cursor_y) begin
                        show_tower_range <= 1;
                        selected_tower_idx <= i;
                    end
                end
            end
            
            case (game_state)
                STATE_MENU: begin
                    if (btnU_pressed && menu_selection > 0) menu_selection <= menu_selection - 1;
                    if (btnD_pressed && menu_selection < 1) menu_selection <= menu_selection + 1;
                    
                    if (btnC_pressed) begin
                        case (menu_selection)
                            0: begin
                                game_state <= STATE_GAME;
                                reset_game_state();
                            end
                            1: game_state <= STATE_HIGHSCORE;
                            2: ;
                        endcase
                    end
                end
                
                STATE_GAME: begin
                    if (btn4_pressed) begin
                        paused <= !paused;
                    end
                    
                    if (!paused) begin
                        if ((btnU_pressed || (btnU && btn_delay == 0)) && cursor_y > 0) begin
                            cursor_y <= cursor_y - 1;
                            btn_delay <= REPEAT_RATE;
                        end
                        if ((btnD_pressed || (btnD && btn_delay == 0)) && cursor_y < GRID_HEIGHT-1) begin
                            cursor_y <= cursor_y + 1;
                            btn_delay <= REPEAT_RATE;
                        end
                        if ((btnL_pressed || (btnL && btn_delay == 0)) && cursor_x > 0) begin
                            cursor_x <= cursor_x - 1;
                            btn_delay <= REPEAT_RATE;
                        end
                        if ((btnR_pressed || (btnR && btn_delay == 0)) && cursor_x < GRID_WIDTH-1) begin
                            cursor_x <= cursor_x + 1;
                            btn_delay <= REPEAT_RATE;
                        end
                        
                        if (btnC_pressed) begin
                            handle_tower_action();
                        end
                    end
                end
                
                STATE_SHOP: begin
                    if (btnU_pressed && shop_selection > 0) shop_selection <= shop_selection - 1;
                    if (btnD_pressed && shop_selection < 3) shop_selection <= shop_selection + 1;
                    
                    if (btnC_pressed) begin
                        place_tower(shop_selection);
                    end
                    
                    if (btn4_pressed || btnL_pressed || btnR_pressed) begin
                        game_state <= STATE_GAME;
                    end
                end
                
                STATE_TOWER_MENU: begin
                    if (btnU_pressed && menu_selection > 0) menu_selection <= menu_selection - 1;
                    if (btnD_pressed && menu_selection < 1) menu_selection <= menu_selection + 1;
                    
                    if (btnC_pressed && selected_tower_idx < MAX_TOWERS) begin
                        case (menu_selection)
                            0: begin // upgrade
                                if (currency >= TOWER_UPGRADE_COST && tower_level[selected_tower_idx] < 3) begin
                                    tower_level[selected_tower_idx] <= tower_level[selected_tower_idx] + 1;
                                    currency <= currency - TOWER_UPGRADE_COST;
                                end
                            end
                            1: begin // sell
                                currency <= currency + (TOWER_COST + tower_level[selected_tower_idx] * TOWER_UPGRADE_COST) * TOWER_SELL_RATIO / 100;
                                tower_active[selected_tower_idx] <= 0;
                            end
                        endcase
                        game_state <= STATE_GAME;
                    end
                    
                    if (btn4_pressed || btnL_pressed || btnR_pressed) begin
                        game_state <= STATE_GAME;
                    end
                end
                
                STATE_GAMEOVER: begin
                    if (btnC_pressed) begin
                        game_state <= STATE_MENU;
                    end
                end
                
                STATE_HIGHSCORE: begin
                    if (btnC_pressed || btn4_pressed)
                        game_state <= STATE_MENU;
                end
            endcase
        end
        
        if (game_state == STATE_GAME && !paused && game_tick) begin
            case (process_state)
                PROC_IDLE: begin
                    process_state <= PROC_UPDATE_ENEMIES;
                    process_index <= 0;
                end
                
                PROC_UPDATE_ENEMIES: begin
                    if (process_index < MAX_ENEMIES) begin
                        if (enemy_active[process_index]) begin
                            update_enemy(process_index);
                        end
                        process_index <= process_index + 1;
                    end else begin
                        process_state <= PROC_UPDATE_TOWERS;
                        process_index <= 0;
                    end
                end
                
                PROC_UPDATE_TOWERS: begin
                    if (process_index < MAX_TOWERS) begin
                        if (tower_active[process_index]) begin
                            update_tower(process_index);
                        end
                        process_index <= process_index + 1;
                    end else begin
                        process_state <= PROC_UPDATE_PROJECTILES;
                        process_index <= 0;
                    end
                end
                
                PROC_UPDATE_PROJECTILES: begin
                    if (process_index < MAX_PROJECTILES) begin
                        if (proj_active[process_index]) begin
                            update_projectile(process_index);
                        end
                        process_index <= process_index + 1;
                    end else begin
                        process_state <= PROC_SPAWN;
                        process_index <= 0;
                    end
                end
                
                PROC_SPAWN: begin
                    spawn_timer <= spawn_timer + 1;
                    if (spawn_timer >= 60 - (wave_number / 2)) begin
                        spawn_timer <= 0;
                        if (enemies_spawned < enemies_in_wave) begin
                            spawn_enemy();
                        end else begin
                            begin: check_wave_complete
                                integer i;
                                reg all_clear;
                                all_clear = 1;
                                for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
                                    if (enemy_active[i]) all_clear = 0;
                                end
                                if (all_clear) begin
                                    wave_number <= wave_number + 1;
                                    enemies_in_wave <= 5 + wave_number / 2;
                                    enemies_spawned <= 0;
                                end
                            end
                        end
                    end
                    process_state <= PROC_IDLE;
                end
            endcase
        end
    end
    
    wire [4:0] grid_x = x / TILE_SIZE;
    wire [4:0] grid_y = y / TILE_SIZE;
    wire [4:0] pixel_x = x % TILE_SIZE;
    wire [4:0] pixel_y = y % TILE_SIZE;
    
    reg enemy_hit;
    reg tower_hit;
    reg proj_hit;
    reg nozzle_hit;
    reg [3:0] obj_red;
    reg [3:0] obj_green;
    reg [3:0] obj_blue;
    integer ri;
    
    wire [2:0] check_zone_x;
    wire [2:0] check_zone_y;
    reg [5:0] obj_idx;
    reg [2:0] zone_offset;
    reg [9:0] range;
	reg [9:0] tx, ty, ex, ey;
	reg signed [10:0] dx, dy;
    
    always @* begin
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;
        enemy_hit = 0;
        tower_hit = 0;
        proj_hit = 0;
        nozzle_hit = 0;
        obj_red = 4'h0;
        obj_green = 4'h0;
        obj_blue = 4'h0;
        
        if (vis_d) begin
            case (game_state)
                STATE_MENU: begin
                    red = 4'h1; green = 4'h1; blue = 4'h2;
                    render_text(x_d, y_d, 250, 100, "TOWER DEFENSE!", 14, text_hit);
					if (text_hit) begin
						red = 4'hF; green = 4'hF; blue = 4'hF;
					end
                    
                    render_text(x_d, y_d, 260, 150, "NEW GAME", 8, text_hit);
                    if (text_hit) begin
                        red = (menu_selection == 0) ? 4'hF : 4'h8;
                        green = (menu_selection == 0) ? 4'hF : 4'h8;
                        blue = (menu_selection == 0) ? 4'h0 : 4'h8;
                    end
                    
                    render_text(x_d, y_d, 260, 180, "HIGH SCORES", 11, text_hit);
                    if (text_hit) begin
                        red = (menu_selection == 1) ? 4'hF : 4'h8;
                        green = (menu_selection == 1) ? 4'hF : 4'h8;
                        blue = (menu_selection == 1) ? 4'h0 : 4'h8;
                    end
                end
                
                STATE_GAME: begin
                    red = 4'h1; green = 4'h1; blue = 4'h1;
                    if (pixel_x_d == 0 || pixel_y_d == 0) begin
                        red = 4'h2; green = 4'h2; blue = 4'h2;
                    end
                    
                    if (is_path(x_d, y_d)) begin
                        red = 4'h5; green = 4'h3; blue = 4'h2;
                    end
                    
                    for (ri = 0; ri < MAX_ENEMIES; ri = ri + 1) begin
                        if (enemy_active[ri] && !enemy_hit) begin
                            if ((enemy_x[ri] / ZONE_SIZE >= (zone_x_d > 0 ? zone_x_d - 1 : 0)) &&
                                (enemy_x[ri] / ZONE_SIZE <= (zone_x_d < ZONES_X - 1 ? zone_x_d + 1 : ZONES_X - 1)) &&
                                (enemy_y[ri] / ZONE_SIZE >= (zone_y_d > 0 ? zone_y_d - 1 : 0)) &&
                                (enemy_y[ri] / ZONE_SIZE <= (zone_y_d < ZONES_Y - 1 ? zone_y_d + 1 : ZONES_Y - 1))) begin

                                if (x_d >= enemy_x[ri]-7 && x_d <= enemy_x[ri]+7 && 
                                    y_d >= enemy_y[ri]-7 && y_d <= enemy_y[ri]+7) begin
                                    enemy_hit = 1;
                                    case (enemy_type[ri])
                                        ENEMY_NORMAL: begin
                                            if (enemy_slow[ri] > 0) begin
                                                obj_red = 4'h7; obj_green = 4'h3; obj_blue = 4'hB;
                                            end else begin
                                                obj_red = 4'hD; obj_green = 4'h2; obj_blue = 4'h2;
                                            end
                                        end
                                    endcase
                                end
                                
                                if (y_d >= enemy_y[ri]-10 && y_d <= enemy_y[ri]-8 &&
                                    x_d >= enemy_x[ri]-7 && x_d <= enemy_x[ri]+7 && !enemy_hit) begin
                                    enemy_hit = 1;
                                    if ((x_d - enemy_x[ri] + 7) <= {6'b0, (enemy_health[ri] * 4'd14) / enemy_max_health[ri]}) begin
                                        obj_red = 4'h0; obj_green = 4'hD; obj_blue = 4'h0;
                                    end else begin
                                        obj_red = 4'h3; obj_green = 4'h0; obj_blue = 4'h0;
                                    end
                                end
                            end
                        end
                    end

                    for (ri = 0; ri < MAX_TOWERS; ri = ri + 1) begin
                        if (tower_active[ri] && !tower_hit && !enemy_hit) begin
                            if (grid_x_d == tower_x[ri] && grid_y_d == tower_y[ri]) begin
                                if (pixel_x_d >= 6 && pixel_x_d <= 19 && pixel_y_d >= 6 && pixel_y_d <= 19) begin
                                    tower_hit = 1;
                                    case (tower_type[ri])
                                        TOWER_BASIC: begin obj_red = 4'h5; obj_green = 4'h5; obj_blue = 4'hD; end
                                        TOWER_FAST: begin obj_red = 4'h5; obj_green = 4'hD; obj_blue = 4'h5; end
                                        TOWER_HEAVY: begin obj_red = 4'hD; obj_green = 4'h5; obj_blue = 4'h5; end
                                        TOWER_SLOW: begin obj_red = 4'hD; obj_green = 4'h5; obj_blue = 4'hD; end
                                    endcase
                                end
                            end
                           
							// broken nozzle
                            /*if (tower_target[ri] < MAX_ENEMIES && enemy_active[tower_target[ri]]) begin
                                tx = tower_x[ri] * TILE_SIZE + 13;
                                ty = tower_y[ri] * TILE_SIZE + 13;
                                ex_d = enemy_x[tower_target[ri]];
                                ey_d = enemy_y[tower_target[ri]];
                                dx_d = $signed({1'b0, ex_d}) - $signed({1'b0, tx});
                                dy_d = $signed({1'b0, ey_d}) - $signed({1'b0, ty});
                                if (!nozzle_hit && !enemy_hit && !tower_hit) begin
                                    if ((dx_d[10] ? -dx_d : dx_d) > (dy_d[10] ? -dy_d : dy_d)) begin
                                        if (dx_d[10]) begin
                                            if (x_d >= tx - 12 && x_d <= tx - 8 && y_d >= ty - 2 && y_d <= ty + 2) nozzle_hit = 1;
                                        end else begin
                                            if (x_d >= tx + 8 && x_d <= tx + 12 && y_d >= ty - 2 && y_d <= ty + 2) nozzle_hit = 1;
                                        end
                                    end else begin
                                        if (dy_d[10]) begin
                                            if (x_d >= tx - 2 && x_d <= tx + 2 && y_d >= ty - 12 && y_d <= ty - 8) nozzle_hit = 1;
                                        end else begin
                                            if (x_d >= tx - 2 && x_d <= tx + 2 && y_d >= ty + 8 && y_d <= ty + 12) nozzle_hit = 1;
                                        end
                                    end
                                    if (nozzle_hit) begin
                                        obj_red = 4'h8; obj_green = 4'h8; obj_blue = 4'h8;
                                    end
                                end
                            end*/
                        end
                    end
                    
                    if (show_tower_range && selected_tower_idx < MAX_TOWERS && tower_active[selected_tower_idx]) begin
                        tx = tower_x[selected_tower_idx] * TILE_SIZE + 13;
                        ty = tower_y[selected_tower_idx] * TILE_SIZE + 13;
                        range = TOWER_RANGE + tower_level[selected_tower_idx] * 20;
                        
						if (!enemy_hit && !tower_hit && !proj_hit && !nozzle_hit) begin
							if (is_range_pixel(x_d, y_d, tx, ty, range)) begin
                                red = 4'h8; green = 4'h8; blue = 4'h0;
							end
						end
                    end

                    for (ri = 0; ri < 8; ri = ri + 1) begin
                        obj_idx = (ri + (frame_odd ? 8 : 0)) % MAX_PROJECTILES;
                        if (proj_active[obj_idx] && !proj_hit && !enemy_hit && !tower_hit && !nozzle_hit) begin
                            if (x_d >= proj_x[obj_idx]-1 && x_d <= proj_x[obj_idx]+1 && 
                                y_d >= proj_y[obj_idx]-1 && y_d <= proj_y[obj_idx]+1) begin
                                proj_hit = 1;
                                obj_red = 4'hF; obj_green = 4'hF; obj_blue = 4'hF;
                            end
                        end
                    end
                    
                    if (enemy_hit || tower_hit || proj_hit || nozzle_hit) begin
                        red = obj_red;
                        green = obj_green;
                        blue = obj_blue;
                    end
                    
                    if (grid_x_d == cursor_x && grid_y_d == cursor_y) begin
                        if ((pixel_y_d == 12 || pixel_y_d == 13) && pixel_x_d >= 7 && pixel_x_d <= 18) begin
                            red = 4'hF; green = 4'hF; blue = 4'h0;
                        end
                        if ((pixel_x_d == 12 || pixel_x_d == 13) && pixel_y_d >= 7 && pixel_y_d <= 18) begin
                            red = 4'hF; green = 4'hF; blue = 4'h0;
                        end
                    end
                    if (y_d < 25) begin
                        red = 4'h2; green = 4'h2; blue = 4'h2;
                        
                        render_text(x_d, y_d, 10, 5, "WAVE:", 5, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        render_number(x_d, y_d, 50, 5, wave_number, 3, text_hit);
                        if (text_hit) begin red = 4'h0; green = 4'h0; blue = 4'hF; end
                        
                        render_text(x_d, y_d, 150, 5, "LIVES:", 6, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        render_number(x_d, y_d, 198, 5, lives, 2, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'h0; blue = 4'h0; end
                        
                        render_text(x_d, y_d, 280, 5, "GOLD:", 5, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        render_number(x_d, y_d, 320, 5, currency, 4, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'h0; end
                        
                        render_text(x_d, y_d, 450, 5, "SCORE:", 6, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        render_number(x_d, y_d, 498, 5, score, 5, text_hit);
                        if (text_hit) begin red = 4'h0; green = 4'hF; blue = 4'h0; end
                    end
                    
                    if (paused) begin
						// remove the space after paused this is
						// just so text editor doesn't fuck up syntax_d highlighiting
                        render_text(x_d, y_d, 280, 240, "PAUSED ", 6, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    end
                end
                
                STATE_SHOP: begin
                    red = 4'h0; green = 4'h0; blue = 4'h0;

                    if (x_d >= 170 && x_d <= 470 && y_d >= 140 && y_d <= 340) begin
                        red = 4'h2; green = 4'h2; blue = 4'h3;
                        
                        render_text(x_d, y_d, 260, 150, "SELECT TOWER", 12, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        
                        render_text(x_d, y_d, 190, 190, "BASIC TOWER", 11, text_hit);
                        if (text_hit) begin
                            red = (shop_selection == 0) ? 4'hF : 4'h8;
                            green = (shop_selection == 0) ? 4'hF : 4'h8;
                            blue = (shop_selection == 0) ? 4'h0 : 4'h8;
                        end
                        render_text(x_d, y_d, 350, 190, "COST: 50", 8, text_hit);
                        if (text_hit && currency >= 50) begin
                            red = 4'h0; green = 4'hF; blue = 4'h0;
                        end else if (text_hit) begin
                            red = 4'hF; green = 4'h0; blue = 4'h0;
                        end
                        
                        render_text(x_d, y_d, 190, 220, "FAST TOWER", 10, text_hit);
                        if (text_hit) begin
                            red = (shop_selection == 1) ? 4'hF : 4'h8;
                            green = (shop_selection == 1) ? 4'hF : 4'h8;
                            blue = (shop_selection == 1) ? 4'h0 : 4'h8;
                        end
                        render_text(x_d, y_d, 350, 220, "COST: 75", 8, text_hit);
                        if (text_hit && currency >= 75) begin
                            red = 4'h0; green = 4'hF; blue = 4'h0;
                        end else if (text_hit) begin
                            red = 4'hF; green = 4'h0; blue = 4'h0;
                        end
                        
                        render_text(x_d, y_d, 190, 250, "HEAVY TOWER", 11, text_hit);
                        if (text_hit) begin
                            red = (shop_selection == 2) ? 4'hF : 4'h8;
                            green = (shop_selection == 2) ? 4'hF : 4'h8;
                            blue = (shop_selection == 2) ? 4'h0 : 4'h8;
                        end
                        render_text(x_d, y_d, 350, 250, "COST: 150", 9, text_hit);
                        if (text_hit && currency >= 150) begin
                            red = 4'h0; green = 4'hF; blue = 4'h0;
                        end else if (text_hit) begin
                            red = 4'hF; green = 4'h0; blue = 4'h0;
                        end
                        
                        render_text(x_d, y_d, 190, 280, "SLOW TOWER", 10, text_hit);
                        if (text_hit) begin
                            red = (shop_selection == 3) ? 4'hF : 4'h8;
                            green = (shop_selection == 3) ? 4'hF : 4'h8;
                            blue = (shop_selection == 3) ? 4'h0 : 4'h8;
                        end
                        render_text(x_d, y_d, 350, 280, "COST: 100", 9, text_hit);
                        if (text_hit && currency >= 100) begin
                            red = 4'h0; green = 4'hF; blue = 4'h0;
                        end else if (text_hit) begin
                            red = 4'hF; green = 4'h0; blue = 4'h0;
                        end
                    end
                end
                
                STATE_TOWER_MENU: begin
                    red = 4'h0; green = 4'h0; blue = 4'h0;
                    
                    if (x_d >= 170 && x_d <= 470 && y_d >= 140 && y_d <= 340) begin
                        red = 4'h2; green = 4'h2; blue = 4'h3;
                        
                        render_text(x_d, y_d, 260, 150, "TOWER MENU", 10, text_hit);
                        if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                        
                        if (selected_tower_idx < MAX_TOWERS && tower_active[selected_tower_idx]) begin
                            render_text(x_d, y_d, 190, 190, "LEVEL:", 6, text_hit);
                            if (text_hit) begin red = 4'hA; green = 4'hA; blue = 4'hA; end
                            render_number(x_d, y_d, 238, 190, tower_level[selected_tower_idx] + 1, 1, text_hit);
                            if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                            
                            render_text(x_d, y_d, 190, 230, "UPGRADE", 7, text_hit);
                            if (text_hit) begin
                                red = (menu_selection == 0) ? 4'hF : 4'h8;
                                green = (menu_selection == 0) ? 4'hF : 4'h8;
                                blue = (menu_selection == 0) ? 4'h0 : 4'h8;
                            end
                            
                            if (tower_level[selected_tower_idx] < 3) begin
                                render_text(x_d, y_d, 350, 230, "COST:", 5, text_hit);
                                if (text_hit) begin red = 4'h8; green = 4'h8; blue = 4'h8; end
                                render_number(x_d, y_d, 390, 230, TOWER_UPGRADE_COST, 3, text_hit);
                                if (text_hit && currency >= TOWER_UPGRADE_COST) begin
                                    red = 4'h0; green = 4'hF; blue = 4'h0;
                                end else if (text_hit) begin
                                    red = 4'hF; green = 4'h0; blue = 4'h0;
                                end
                            end else begin
                                render_text(x_d, y_d, 350, 230, "MAx_d LVL", 7, text_hit);
                                if (text_hit) begin red = 4'h8; green = 4'h8; blue = 4'h8; end
                            end
                            
                            render_text(x_d, y_d, 190, 260, "SELL", 4, text_hit);
                            if (text_hit) begin
                                red = (menu_selection == 1) ? 4'hF : 4'h8;
                                green = (menu_selection == 1) ? 4'hF : 4'h8;
                                blue = (menu_selection == 1) ? 4'h0 : 4'h8;
                            end
                            
                            render_text(x_d, y_d, 350, 260, "VALUE:", 6, text_hit);
                            if (text_hit) begin red = 4'h8; green = 4'h8; blue = 4'h8; end
                            render_number(x_d, y_d, 398, 260, (TOWER_COST + tower_level[selected_tower_idx] * TOWER_UPGRADE_COST) * TOWER_SELL_RATIO / 100, 3, text_hit);
                            if (text_hit) begin red = 4'h0; green = 4'hF; blue = 4'h0; end
                        end
                    end
                end
                
                STATE_GAMEOVER: begin
                    red = 4'h1; green = 4'h0; blue = 4'h0;
                    render_text(x_d, y_d, 240, 180, "GAME OVER", 9, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    
                    render_text(x_d, y_d, 240, 220, "FINAL SCORE:", 12, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    render_number(x_d, y_d, 350, 220, score, 5, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    
                    render_text(x_d, y_d, 240, 250, "WAVE REACHED:", 13, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    render_number(x_d, y_d, 350, 250, wave_number, 3, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                end
                
                STATE_HIGHSCORE: begin
                    red = 4'h1; green = 4'h1; blue = 4'h2;
                    
                    render_text(x_d, y_d, 250, 80, "HIGH SCORES", 11, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hF; blue = 4'hF; end
                    
                    render_text(x_d, y_d, 240, 140, "1ST:", 4, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hD; blue = 4'h0; end
                    render_number(x_d, y_d, 300, 140, highscores[0], 6, text_hit);
                    if (text_hit) begin red = 4'hF; green = 4'hD; blue = 4'h0; end
                    
                    render_text(x_d, y_d, 240, 180, "2ND:", 4, text_hit);
                    if (text_hit) begin red = 4'hC; green = 4'hC; blue = 4'hC; end
                    render_number(x_d, y_d, 300, 180, highscores[1], 6, text_hit);
                    if (text_hit) begin red = 4'hC; green = 4'hC; blue = 4'hC; end
                    
                    render_text(x_d, y_d, 240, 220, "3RD:", 4, text_hit);
                    if (text_hit) begin red = 4'h8; green = 4'h4; blue = 4'h0; end
                    render_number(x_d, y_d, 300, 220, highscores[2], 6, text_hit);
                    if (text_hit) begin red = 4'h8; green = 4'h4; blue = 4'h0; end
                end
            endcase
        end
    end
endmodule
