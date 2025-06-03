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
    localparam MAX_TOWERS = 32;
    localparam MAX_PROJECTILES = 32;
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
    
    // game state
    reg [2:0] game_state = STATE_MENU;
    reg [15:0] currency = 200;
    reg [7:0] lives = MAX_LIVES;
    reg [31:0] score = 0;
    reg [31:0] highscore = 0;
    reg [15:0] wave_number = 0;
    reg [19:0] frame_counter = 0;
    reg [19:0] spawn_timer = 0;
    reg paused = 0;
    
    // cursor
    reg [4:0] cursor_x = 12;
    reg [4:0] cursor_y = 9;
    
    // button edge detection
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
    
    // tower selection
    reg [1:0] selected_tower_type = TOWER_BASIC;
    
    // arrays for game objects
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
    
    // game clock divider
	localparam GAME_DIV = 8333;
    reg [$clog2(GAME_DIV)-1:0] game_clk_div = 0;
    wire game_tick = (game_clk_div == 0);
    
    // processing state machine
    reg [3:0] process_state = 0;
    reg [5:0] process_index = 0;
    
    localparam PROC_IDLE = 0;
    localparam PROC_UPDATE_ENEMIES = 1;
    localparam PROC_UPDATE_TOWERS = 2;
    localparam PROC_UPDATE_PROJECTILES = 3;
    localparam PROC_CHECK_COLLISIONS = 4;
    localparam PROC_SPAWN = 5;
    
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
		game_clk_div = GAME_DIV-1;
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
    
    always @(posedge clk) begin
		if (game_clk_div == 0) begin
			game_clk_div <= GAME_DIV-1;
		end else begin
			game_clk_div <= game_clk_div-1;
		end
        /*if (!rst_n) begin
            // Reset all state
            game_state <= STATE_MENU;
            currency <= 200;
            lives <= MAX_LIVES;
            score <= 0;
            wave_number <= 0;
            spawn_timer <= 0;
            paused <= 0;
            frame_counter <= 0;
            cursor_x <= 12;
            cursor_y <= 9;
            btn_delay <= 0;
            selected_tower_type <= TOWER_BASIC;
            process_state <= PROC_IDLE;
            process_index <= 0;
            game_clk_div <= 0;
        end*/
        if (new_frame) begin
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
                        
                        if (btn1_pressed)
							selected_tower_type <= TOWER_BASIC;
                        if (btn2_pressed)
							selected_tower_type <= TOWER_FAST;
                        if (btn3_pressed)
							selected_tower_type <= TOWER_HEAVY;
                        if (btn4_pressed && !btnC)
							selected_tower_type <= TOWER_SLOW;
                        if (btnC_pressed)
							handle_tower_action();
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
                    if (spawn_timer >= 30) begin
                        spawn_timer <= 0;
                        spawn_enemy();
                        wave_number <= wave_number + 1;
                    end
                    process_state <= PROC_IDLE;
                end
            endcase
        end
    end
    
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
                
                // check if position has a tower
                for (i = 0; i < MAX_TOWERS; i = i + 1) begin
                    if (tower_active[i] && tower_x[i] == cursor_x && tower_y[i] == cursor_y) begin
                        position_empty = 0;
                        tower_idx = i;
                    end
                end
                
                if (position_empty && currency >= TOWER_COST) begin
                    // place new tower
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
						tower_type[i] <= selected_tower_type;
						tower_level[i] <= 0;
						tower_cooldown[i] <= 0;
						tower_target[i] <= 255;
						currency <= currency - TOWER_COST;
					end

                end else if (!position_empty && btnL && tower_idx < MAX_TOWERS) begin
                    // sell tower
                    currency <= currency + (TOWER_COST + tower_level[tower_idx] * TOWER_UPGRADE_COST) * TOWER_SELL_RATIO / 100;
                    tower_active[tower_idx] <= 0;
                end else if (!position_empty && btnR && currency >= TOWER_UPGRADE_COST && tower_idx < MAX_TOWERS) begin
                    // upgrade tower
                    if (tower_level[tower_idx] < 3) begin
                        tower_level[tower_idx] <= tower_level[tower_idx] + 1;
                        currency <= currency - TOWER_UPGRADE_COST;
                    end
                end
            end
        end
    endtask
    
    task update_enemy;
        input [4:0] idx;
        reg [19:0] pos;
        begin
			if (enemy_slow[idx] > 0) begin
				enemy_slow[idx] <= enemy_slow[idx] - 1;
				if (frame_counter[0] == 0)
					enemy_progress[idx] <= enemy_progress[idx] + ENEMY_SPEED;
			end else begin
				enemy_progress[idx] <= enemy_progress[idx] + ENEMY_SPEED + (wave_number >> 3);
			end
			
			pos = get_enemy_position(enemy_progress[idx]);
			enemy_x[idx] <= pos[19:10];
			enemy_y[idx] <= pos[9:0];
			
			if (enemy_progress[idx] > 2200) begin
				enemy_active[idx] <= 0;
				lives <= (lives > 0) ? lives - 1 : 0;
				if (lives == 1) begin
					game_state <= STATE_GAMEOVER;
					if (score > highscore)
						highscore <= score;
				end
			end
			
			if (enemy_health[idx] == 0) begin
				enemy_active[idx] <= 0;
				currency <= currency + ENEMY_REWARD + (wave_number >> 2);
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
				
				// find closest enemy
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
					// set cooldown
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
				
				if (proj_x[idx] > 640 || proj_y[idx] > 480)
					proj_active[idx] <= 0;
			end
        end
    endtask
    
    task spawn_enemy;
        reg [19:0] pos;
        integer i, slot;
		reg found;
        begin
			found = 0;
			for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
				if (!found && !enemy_active[i]) begin
					slot = i;
					found = 1;
				end
			end
			i = slot;
			if (found) begin
				enemy_active[i] <= 1;
				enemy_progress[i] <= 0;
				enemy_health[i] <= 25 + wave_number * 10;
				enemy_max_health[i] <= 25 + wave_number * 10;
				enemy_slow[i] <= 0;
				pos = get_enemy_position(0);
				enemy_x[i] <= pos[19:10];
				enemy_y[i] <= pos[9:0];
			end
        end
    endtask

	task render_towers;
		integer i;
		reg signed [10:0] ndx, ndy;
		reg signed [10:0] tpx, tpy;
		reg [9:0] nx, ny;
		begin
			for (i = 0; i < MAX_TOWERS; i = i + 1) begin
				if (tower_active[i] && grid_x == tower_x[i] && grid_y == tower_y[i]) begin
					if (pixel_x >= 6 && pixel_x <= 19 && pixel_y >= 6 && pixel_y <= 19) begin
						case (tower_type[i])
							TOWER_BASIC: begin red = 4'h5; green = 4'h5; blue = 4'hD; end
							TOWER_FAST: begin red = 4'h5; green = 4'hD; blue = 4'h5; end
							TOWER_HEAVY: begin red = 4'hD; green = 4'h5; blue = 4'h5; end
							TOWER_SLOW: begin red = 4'hD; green = 4'h5; blue = 4'hD; end
						endcase
					end
					if (tower_target[i] < MAX_ENEMIES && enemy_active[tower_target[i]]) begin
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
		end
	endtask

	task render_enemies;
		integer i;
		begin
			for (i = 0; i < MAX_ENEMIES; i = i + 1) begin
				if (enemy_active[i]) begin
					if (x >= enemy_x[i]-7 && x <= enemy_x[i]+7 && 
						y >= enemy_y[i]-7 && y <= enemy_y[i]+7) begin
						if (enemy_slow[i] > 0) begin
							red = 4'h7; green = 4'h3; blue = 4'hB;
						end else begin
							red = 4'hD; green = 4'h2; blue = 4'h2;
						end
					end
					if (y >= enemy_y[i]-10 && y <= enemy_y[i]-8
						&& x >= enemy_x[i]-7 && x <= enemy_x[i]+7) begin
						if ((x - enemy_x[i] + 7) <= {6'b0,
						(enemy_health[i] * 4'd14) / enemy_max_health[i]}) begin
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
		end
	endtask

	task render_projectiles;
		integer i;
		begin
			for (i = 0; i < MAX_PROJECTILES; i = i + 1) begin
				if (proj_active[i]) begin
					if (x >= proj_x[i]-1 && x <= proj_x[i]+1 && 
						y >= proj_y[i]-1 && y <= proj_y[i]+1) begin
						red = 4'hF; green = 4'hF; blue = 4'hF;
					end
				end
            end
		end
	endtask
    
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
                        red = 4'hF; green = 4'hF; blue = 4'hF;
                    end
                end
                
                STATE_GAME: begin
					// background and grid
                    red = 4'h1; green = 4'h1; blue = 4'h1;
					if (pixel_x == 0 || pixel_y == 0) begin
						red = 4'h2;
						green = 4'h2;
						blue = 4'h2;
					end
                   
					// path
                    if (is_path(x, y)) begin
                        red = 4'h5; green = 4'h3; blue = 4'h2;
                    end
                    
					render_towers();
					render_enemies();
					render_projectiles();
                    
                    // cursor
                    if (grid_x == cursor_x && grid_y == cursor_y) begin
                        if ((pixel_y == 12 || pixel_y == 13) && pixel_x >= 7 && pixel_x <= 18) begin
                            red = 4'hF; green = 4'hF; blue = 4'h0;
                        end
                        if ((pixel_x == 12 || pixel_x == 13) && pixel_y >= 7 && pixel_y <= 18) begin
                            red = 4'hF; green = 4'hF; blue = 4'h0;
                        end
                    end
                    
                    // ui bar
                    if (y < 25) begin
                        red = 4'h2; green = 4'h2; blue = 4'h2;
                    end
                end
                
                STATE_GAMEOVER: begin
                    if (y >= 180 && y < 220 && x >= 200 && x < 440) begin
                        red = 4'hF; green = 4'h0; blue = 4'h0;
                    end
                end
            endcase
        end
    end
endmodule
