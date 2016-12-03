# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800


#########################################INTERRUPT HANDLER###########################################
.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 44	# space for 10 registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, 	chunkIH
	sw	$a0, 	0($k0)		# Get some free registers                  
	sw	$a1, 	4($k0)		# by storing them to a global variable
	sw 	$t0,	8($k0)     
	sw 	$t1,	12($k0)
	sw 	$t2,	16($k0)
	sw 	$t3,	20($k0)
	sw 	$t4,	24($k0)
	sw 	$t5,	28($k0)
	sw 	$t6,	32($k0)
	sw 	$t7,	36($k0)
	sw 	$v0,	40($k0)

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt      

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts

	#and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?                
	#bne	$a0, 0, bonk_interrupt   

	#and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	#bne	$a0, 0, timer_interrupt

	and	$a0,	$k0,	ON_FIRE_MASK	# is there an on_fire interrupt?
	bne 	$a0,	0,	on_fire_interrupt

	and 	$a0,	$k0,	REQUEST_PUZZLE_INT_MASK
	bne 	$a0,	0,	puzzle_interrupt


	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

puzzle_interrupt:
	sw	$a1,	REQUEST_PUZZLE_ACK	# acknowledge interrupt

	# Set SOLVE_PUZZLE to 1
	li 	$t0,	1
	la 	$t1,	SOLVE_PUZZLE
	sw 	$t0,	0($t1)


	j	interrupt_dispatch	# see if other interrupts are waiting


on_fire_interrupt:
	sw	$a1,	ON_FIRE_ACK		# acknowledge interrupt

	lw 	$a1,	GET_FIRE_LOC
	srl 	$t0,	$a1,	16		# $t0 = fire location x index 
	and 	$t1,	$a1,	0x0000ffff	# $t1 = fire location y index 
	li 	$t7,	30
	mul 	$t0,	$t0,	$t7
	add 	$t0,	$t0,	15	# $t0 = 15 + x * 30
	mul 	$t1,	$t1,	$t7
	add 	$t1,	$t1,	15	# $t1 = 15 + y * 30
	lw 	$t2,	BOT_X 
	lw 	$t3,	BOT_Y

	# Put out fire!
	li	$t7, 	0
	sw 	$t7,	ANGLE
	
	li 	$t7, 	1
	sw 	$t7, 	ANGLE_CONTROL

xmove_loop:
	lw 	$t2,	BOT_X	
	sub 	$t4,	$t0,	$t2	# xdif
	beq 	$t4,	0,	xmove_endloop
	blt	$t4,	0,	xmove_negative
	li 	$t7,	10
	sw 	$t7,	VELOCITY
	j 	xmove_loop
	
xmove_negative:
	li 	$t7,	-10
	sw 	$t7,	VELOCITY
	j 	xmove_loop

xmove_endloop:

	# set angle to 90
	li	$t7, 	90
	sw 	$t7,	ANGLE

	li 	$t7, 	1
	sw 	$t7, 	ANGLE_CONTROL

ymove_loop:
	lw 	$t3,	BOT_Y
	sub 	$t4,	$t1,	$t3	# ydif
	beq 	$t4,	0,	ymove_endloop
	blt	$t4,	0,	ymove_negative
	li 	$t7,	10
	sw 	$t7,	VELOCITY
	j 	ymove_loop
	
ymove_negative:
	li 	$t7,	-10
	sw 	$t7,	VELOCITY
	j 	ymove_loop

ymove_endloop:
	sw 	$t7 	PUT_OUT_FIRE
	sw 	$zero	VELOCITY

	j	interrupt_dispatch	# see if other interrupts are waiting




non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, 	chunkIH
	lw	$a0, 	0($k0)		# Restore saved registers
	lw	$a1, 	4($k0)
	lw 	$t0,	8($k0)     
	lw 	$t1,	12($k0)
	lw 	$t2,	16($k0)
	lw 	$t3,	20($k0)
	lw 	$t4,	24($k0)
	lw 	$t5,	28($k0)
	lw 	$t6,	32($k0)
	lw 	$t7,	36($k0)
	lw 	$v0,	40($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret   


#########################################MAIN###########################################
.data
# put your data things here

.align 2
tile_data: .space 1600
puzzle_data: .space 4096
solution_data: .space 328
SOLVE_PUZZLE: .space 4



.text
main:
	# go wild
	# the world is your oyster :)

	# Enable interrupts
	li	$t4, 	ON_FIRE_MASK	# on fire interrupt enable bit
	or 	$t4,	REQUEST_PUZZLE_INT_MASK
	or	$t4, 	$t4, 1		# global interrupt enable
	mtc0	$t4, 	$12		# set interrupt mask (Status register)


	li 	$t0,	0
	sw 	$t0,	VELOCITY

	li  	$t0, 	1  # 0 for water, 1 for seeds, 2 for fire starters
	sw  	$t0, 	SET_RESOURCE_TYPE
    	la  	$t0, 	puzzle_data
    	sw  	$t0, 	REQUEST_PUZZLE


# Wait for puzzle to be loaded
infinite:
	la 	$t0,	SOLVE_PUZZLE	
	lw 	$t0,	0($t0)
	bne 	$t0,	1,	infinite

	li 	$t0,	0
	la 	$t1,	solution_data
pi_loop:
	bge 	$t0,	328,	pi_endloop
	sll 	$t2,	$t0,	2		#t0 << 2
	add 	$t2,	$t2,	$t1
	sw 	$0,	0($t2)
	add 	$t0,	$t0,	1
	j 	pi_loop
pi_endloop:

	la	$a0, 	solution_data
	la	$a1, 	puzzle_data
	jal	recursive_backtracking

	la 	$t0,	solution_data
	sw	$t0,	SUBMIT_SOLUTION

	# Set SOLVE_PUZZLE to 0;
	li 	$t0,	0
	la 	$t1,	SOLVE_PUZZLE
	sw 	$t0,	0($t1)

	lw	$t0,	GET_NUM_SEEDS
	sw	$t0,	PRINT_INT_ADDR	# print number of seeds
	j 	infinite

	j 	main



#########################################FUNCTIONS###########################################
.globl recursive_backtracking
recursive_backtracking:
	# Your code goes here :)
	sub 	$sp,	$sp,	692
	sw 	$ra,	0($sp)
	sw 	$s0,	4($sp)
	sw 	$s1,	8($sp)
	sw 	$s2,	12($sp)
	sw 	$s3,	16($sp)
	sw 	$s4,	20($sp)
	sw 	$s5,	24($sp)
	sw 	$s6,	28($sp)
	sw 	$s7,	32($sp)


	move 	$s0,	$a0		# $s0 = solution
	move 	$s1,	$a1 		# $s1 = puzzle
	jal 	is_complete 		# $v0 = is_complete(solution, puzzle)
	beq 	$v0,	$zero,	rb_endif1

	li 	$v0,	1		# return 1;
	lw 	$ra,	0($sp)		
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	lw 	$s3,	16($sp)
	lw 	$s4,	20($sp)
	lw 	$s5,	24($sp)
	lw 	$s6,	28($sp)
	lw 	$s7,	32($sp)
	add 	$sp,	$sp,	692
	jr 	$ra
rb_endif1:
	move 	$a0,	$s0		# $a0 = solution
	move 	$a1,	$s1		# $a1 = puzzle
	jal 	get_unassigned_position	# $v0 = get_unassigned_position(solution, puzzle)
	move 	$s2,	$v0 		# $s2 = position
	li 	$s3,	1		# $s3 = val
	lw 	$s4,	0($s1) 		
	add 	$s4,	$s4,	1	# $s4 = puzzle->size + 1
rb_loop1:
	bge 	$s3,	$s4,	rb_endloop
	sll 	$t0,	$s2,	3 	# position << 3
	lw 	$t1,	4($s1)		# &grid ($t1 free)
	add 	$t0,	$t0,	$t1 	# &grid[position].domain
	lw 	$t1,	0($t0)		# $t1 = grid[position].domain ($t0 free)
	li 	$s5,	1
	sub 	$t2,	$s3,	1	# $t2 = val - 1
	sll 	$s5,	$s5,	$t2	# $s5 = 0x1 << (val - 1) ($t2 free)
	and 	$t1,	$t1,	$s5 	# $t1 = puzzle->grid[position].domain & (0x1 << (val - 1))
	beq 	$t1,	0,	rb_endif2	# ($t1 free)
	sll 	$t0,	$s2,	2 	# position << 2
	add 	$t1,	$s0,	$t0 	# $t1 = &solution->assignement[position] - 4 ($t0 free)
	sw 	$s3,	4($t1) 		# store val to &solution->assignement[position] ($t1 free)
	lw 	$t0,	0($s0)		# $t0 = solution->size
	add 	$t0,	$t0,	1
	sw 	$t0,	0($s0)		# solution->size += 1 ($t0 free)
	add 	$s6,	$sp,	36	# $s6 = &puzzle_copy (memsize = 8)
	add 	$s7,	$sp,	44	# $s7 = &grid_copy (memsize = 8 * 81)
	sw 	$s7,	4($s6) 		# puzzle_copy.grid = grid_copy
	move 	$a0,	$s1 		# $a0 = puzzle
	move 	$a1,	$s6 		# $a1 = &puzzle_copy
	jal 	clone
	lw 	$t0,	4($s6)		# $t0 = puzzle_copy.&grid
	sll 	$t1,	$s2,	3	# $t1 = position << 3
	add 	$t0,	$t0,	$t1	# $t0 = &puzzle_copy.grid[position].domain
	sw	$s5,	0($t0)		# puzzle_copy.grid[position].domain = 0x1 << (val - 1) 
	move 	$a0,	$s2 		# $a0 = position
	move 	$a1,	$s6 		# $a1 = &puzzle_copy
	jal	forward_checking 	# $v0 = forward_checking(solution, &puzzle_copy)
	beq 	$v0,	0,	rb_endif3 	# $v0 free
	move 	$a0,	$s0 		# $a0 = solution
	move 	$a1,	$s6 		# $a1 = &puzzle_copy
	jal 	recursive_backtracking 	# $v0 = recursive_backtracking(solution, &puzzle_copy)
	beq 	$v0,	0,	rb_endif3 	# $v0 free
	li 	$v0,	1
	lw 	$ra,	0($sp)
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	lw 	$s3,	16($sp)
	lw 	$s4,	20($sp)
	lw 	$s5,	24($sp)
	lw 	$s6,	28($sp)
	lw 	$s7,	32($sp)
	add 	$sp,	$sp,	692
	jr 	$ra			# return 1
rb_endif3:
	sll 	$t0,	$s2,	2 	# position << 2
	add 	$t1,	$s0,	$t0 	# $t1 = &solution->assignement[position] - 4 ($t0 free)
	sw 	$zero,	4($t1) 		# solution->assignement[position] = 0 ($t1 free)
	lw 	$t0,	0($s0)
	sub 	$t0,	$t0,	1
	sw 	$t0,	0($s0) 		# solution->size -= 1
rb_endif2:
	add 	$s3,	$s3,	1	# val++
	j	rb_loop1
rb_endloop:
	li 	$v0,	0
	lw 	$ra,	0($sp)
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	lw 	$s3,	16($sp)
	lw 	$s4,	20($sp)
	lw 	$s5,	24($sp)
	lw 	$s6,	28($sp)
	lw 	$s7,	32($sp)
	add 	$sp,	$sp,	692
	jr  	$ra			# return 0


.globl is_complete
is_complete:
	# Your code goes here :)
	lw	$t0	0($a0)		# $t0 = solution->size
	lw 	$t1	0($a1)		# $t1 = puzzle->size
	mul 	$t1 	$t1 	$t1	# $t1 = puzzle->size * puzzle->size
	seq 	$v0	$t0 	$t1
	jr	$ra


.globl get_unassigned_position
get_unassigned_position:
	# Your code goes here :)
	li 	$v0,	0			# unassigned_pos = 0
	lw	$t1,	0($a1)	
	mul 	$t1,	$t1,	$t1 		# puzzle->size * puzzle->size
gup_loop:
	bge 	$v0,	$t1,	gup_endloop
	sll 	$t3,	$v0,	2		# unassigned_pos << 2
	add 	$t2,	$a0,	$t3		# &solution[unassigned_pos] - 4
	lw 	$t2,	4($t2)			# $t2 = solution[unassigned_poz]
	beq 	$t2,	$zero,	gup_endloop	# break if $t2 equal to 0
	add 	$v0,	$v0,	1		# unassigned_pos++
	j	gup_loop
gup_endloop:
	jr  	$ra


.globl forward_checking
forward_checking:
    # Your code goes here :)
	lw	$t0,	0($a1)		# size
	li	$t1, 	0		# col = 0
fc_loop1:
	bge	$t1, 	$t0, 	fc_endloop1
	rem 	$t2, 	$a0,	$t0	# position % size
	beq 	$t1,	$t2,	fc_endif1
	div 	$t3,	$a0,	$t0
	mul	$t3,	$t3,	$t0
	add 	$t3,	$t3,	$t1 	# row_pos
	lw 	$t5,	4($a1)		# &grid	DO NOT CHANGE
	sll	$t3,	$t3,	3	# row_pos << 3 (size of a Cell is 8 bytes)
	add 	$t4,	$t5,	$t3 	# &grid[row_pos].domain
	lw 	$t6,	0($t4)		# grid[row_pos].domain
	sll 	$t2,	$a0,	3	# position << 3
	add 	$t2,	$t5,	$t2	# &grid[position].domain
	lw 	$t2,	0($t2) 		# grid[position].domain
	not 	$t2,	$t2 		# ~grid[position].domain
	and 	$t6,	$t6,	$t2	# puzzle->grid[row_pos].domain &= ~puzzle->grid[position].domain;
	sw	$t6,	0($t4)		# store puzzle->grid[row_pos].domain
	bne 	$t6,	$zero,	fc_endif1
	li 	$v0,	0
	jr 	$ra
fc_endif1:
	add 	$t1, 	$t1, 	1	# col++
	j	fc_loop1
fc_endloop1:

	li 	$t1,	0		# row = 0
fc_loop2:
	bge 	$t1,	$t0,	fc_endloop2
	div 	$t2,	$a0,	$t0
	beq 	$t1,	$t2,	fc_endif2
	mul 	$t2,	$t1,	$t0
	rem 	$t3,	$a0,	$t0
	add 	$t2,	$t2,	$t3 	# col_pos
	sll 	$t2,	$t2,	3	# col_pos << 3
	add 	$t3,	$t5,	$t2	# &grid[col_pos].domain
	lw 	$t2,	0($t3) 		# grid[col_pos].domain
	sll 	$t4,	$a0,	3 	# position << 3
	add 	$t4,	$t5,	$t4	# &grid[position].domain
	lw 	$t4,	0($t4) 		# grid[position].domain
	not 	$t4,	$t4 		# ~grid[position].domain
	and 	$t2,	$t2,	$t4 	# puzzle->grid[row_pos].domain &= ~puzzle->grid[position].domain;
	sw 	$t2,	0($t3) 		# store puzzle->grid[col_pos].domain
	bne 	$t2,	$zero,	fc_endif2
	li 	$v0,	0
	jr 	$ra
fc_endif2:
	add 	$t1,	$t1,	1	# row++
	j 	fc_loop2
fc_endloop2:

	sub 	$sp,	$sp,	36
    	sw     	$ra, 	0($sp)
   	sw    	$s0, 	4($sp)
    	sw  	$s1, 	8($sp)
    	sw    	$s2, 	12($sp)
    	sw     	$s3, 	16($sp)
	sw 	$s4,	20($sp)
	sw 	$s5,	24($sp)
	sw 	$s6,	28($sp)
	sw 	$s7 	32($sp)
	move 	$s0,	$a0 		# $s0 = position
	move 	$s1,	$a1 		# $s1 = puzzle 


	li 	$s2,	0		# i = 0;
	sll 	$s3,	$s0,	3 	# position << 3
	lw 	$s6,	4($s1)		# &grid	
	add 	$s3,	$s3,	$s6	# &grid[position]
	lw 	$s4,	4($s3)		# &grid[position].cage DO NOT CHANGE before the function call
	lw 	$s3,	8($s4) 		# grid[position].cage->num_cell DO NOT CHANGE before the function call
fc_loop3:
	bge 	$s2,	$s3,	fc_endloop3
	lw 	$t4,	12($s4)		# &puzzle->grid[position].cage->positions
	sll 	$s5,	$s2,	2	# i << 2
	add 	$t4,	$t4,	$s5 	# &puzzle->grid[position].cage->positions[i]
	lw 	$t4,	0($t4) 		# cage_pos = puzzle->grid[position].cage->positions[i]
	sll 	$s5,	$t4,	3 	# cage_pos << 3
	add 	$s7,	$s5,	$s6 	# &grid[cage_pos].domain
	lw 	$s5,	0($s7)		# grid[cage_pos].domain
	# FUNCTION CALL
	# What we need after the call: $a0, $a1, $ra, i($s2), grid[position].cage->num_cell($s3), &grid[position].cage($s4), grid[cage_pos].domain($s5), &grid($s6), &grid[cage_pos].domain($s7)
	move 	$a0,	$t4
	move 	$a1,	$s1
	jal	get_domain_for_cell	# $v0 = get_domain_for_cell(cage_pos, puzzle)
	and 	$s5,	$s5,	$v0
	sw 	$s5,	0($s7)		# store grid[cage_pos].domain to &grid[cage_pos].domain
	bne 	$s5,	$zero,	fc_endif3
	li 	$v0,	0
    	lw     	$ra, 	0($sp)
   	lw    	$s0, 	4($sp)
    	lw  	$s1, 	8($sp)
    	lw    	$s2, 	12($sp)
    	lw     	$s3, 	16($sp)
	lw 	$s4,	20($sp)
	lw 	$s5,	24($sp)
	lw 	$s6,	28($sp)
	lw 	$s7 	32($sp)
	add 	$sp,	$sp,	36
	jr 	$ra			# return 0;
fc_endif3:
	add 	$s2,	$s2,	1
	j	fc_loop3
fc_endloop3:
	li 	$v0,	1 		# return 1;
    	lw     	$ra, 	0($sp)
   	lw    	$s0, 	4($sp)
    	lw  	$s1, 	8($sp)
    	lw    	$s2, 	12($sp)
    	lw     	$s3, 	16($sp)
	lw 	$s4,	20($sp)
	lw 	$s5,	24($sp)
	lw 	$s6,	28($sp)
	lw 	$s7 	32($sp)
	add 	$sp,	$sp,	36
    	jr  	$ra



.globl convert_highest_bit_to_int
convert_highest_bit_to_int:
    move  $v0, $0             # result = 0

chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop

chbti_end:
    jr    $ra

.globl is_single_value_domain
is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1	          # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr	   $ra

isvd_zero:	   
    li	   $v0, 0
    jr	   $ra
    
.globl get_domain_for_addition
get_domain_for_addition:

    # We highly recommend that you copy in our 
    # solution when it is released on Tuesday night 
    # after the late deadline for Lab7.2
    #
    # If you reach this part before Tuesday night,
    # you can paste your Lab7.2 solution here for now

    sub    $sp, $sp, 20
    sw     $ra, 0($sp)
    sw     $s0, 4($sp)
    sw     $s1, 8($sp)
    sw     $s2, 12($sp)
    sw     $s3, 16($sp)
    move   $s0, $a0                     # s0 = target
    move   $s1, $a1                     # s1 = num_cell
    move   $s2, $a2                     # s2 = domain

    move   $a0, $a2
    jal    convert_highest_bit_to_int
    move   $s3, $v0                     # s3 = upper_bound

    sub    $a0, $0, $s2	                # -domain
    and    $a0, $a0, $s2                # domain & (-domain)
    jal    convert_highest_bit_to_int   # v0 = lower_bound
	   
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
    sub    $t0, $s0, $t0                # t0 = high_bits
    bge    $t0, $s3, gdfa_skip1

    li     $t1, 1          
    sll    $t0, $t1, $t0                # 1 << high_bits
    sub    $t0, $t0, 1                  # (1 << high_bits) - 1
    and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)

gdfa_skip1:	   
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
    sub    $t0, $s0, $t0                # t0 = low_bits
    ble    $t0, $0, gdfa_skip2

    sub    $t0, $t0, 1                  # low_bits - 1
    sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
    sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)

gdfa_skip2:	   
    move   $v0, $s2                     # return domain
    lw     $ra, 0($sp)
    lw     $s0, 4($sp)
    lw     $s1, 8($sp)
    lw     $s2, 12($sp)
    lw     $s3, 16($sp)
    add    $sp, $sp, 20
    jr     $ra

#loop_4ever:
   # j loop_4ever

    # And don't forget to delete the infinite loop :)


.globl get_domain_for_subtraction
get_domain_for_subtraction:
    
    # We highly recommend that you copy in our 
    # solution when it is released on Tuesday night 
    # after the late deadline for Lab7.2
    #
    # If you reach this part before Tuesday night,
    # you can paste your Lab7.2 solution here for now

#loop_5ever:
   # j loop_5ever

    # And don't forget to delete the infinite loop :)
    li     $t0, 1              
    li     $t1, 2
    mul    $t1, $t1, $a0            # target * 2
    sll    $t1, $t0, $t1            # 1 << (target * 2)
    or     $t0, $t0, $t1            # t0 = base_mask
    li     $t1, 0                   # t1 = mask

gdfs_loop:
    beq    $a2, $0, gdfs_loop_end	
    and    $t2, $a2, 1              # other_domain & 1
    beq    $t2, $0, gdfs_if_end
	   
    sra    $t2, $t0, $a0            # base_mask >> target
    or     $t1, $t1, $t2            # mask |= (base_mask >> target)

gdfs_if_end:
    sll    $t0, $t0, 1              # base_mask <<= 1
    sra    $a2, $a2, 1              # other_domain >>= 1
    j      gdfs_loop

gdfs_loop_end:
    and    $v0, $a1, $t1            # domain & mask
    jr	   $ra



.globl get_domain_for_cell
get_domain_for_cell:
    # save registers    
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    li $t0, 0 # valid_domain
    lw $t1, 4($a1) # puzzle->grid (t1 free)
    sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
    add $t3, $t1, $t2 # &puzzle->grid[position]
    lw  $t4, 4($t3) # &puzzle->grid[position].cage
    lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation

    lw $t2, 4($t4) # puzzle->grid[position].cage->target

    move $s0, $t2   # remain_target = $s0  *!*!
    lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
    lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
    move $s3, $t4 # puzzle->grid[position].cage
    li $s4, 0   # i = 0
    move $s5, $t1 # $s5 = puzzle->grid
    move $s6, $a0 # $s6 = position
    # move $s7, $s2 # $s7 = puzzle->grid[position].domain

    bne $t5, 0, gdfc_check_else_if

    li $t1, 1
    sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
    sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
    j gdfc_end # somewhere!!!!!!!!

gdfc_check_else_if:
    bne $t5, '+', gdfc_check_else

gdfc_else_if_loop:
    lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
    bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
    sll $t1, $s4, 2 # i*4
    lw $t6, 12($s3) # puzzle->grid[position].cage->positions
    add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
    lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
    add $s4, $s4, 1 # i++

    sll $t2, $t1, 3 # pos * 8
    add $s7, $s5, $t2 # &puzzle->grid[pos]
    lw  $s7, 0($s7) # puzzle->grid[pos].domain

    beq $t1, $s6 gdfc_else_if_else # branch if pos == position

    

    move $a0, $s7 # $a0 = puzzle->grid[pos].domain
    jal is_single_value_domain
    bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
    move $a0, $s7
    jal convert_highest_bit_to_int
    sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
    addi $s1, $s1, -1 # remain_cell -= 1
    j gdfc_else_if_loop
gdfc_else_if_else:
    or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
    j gdfc_else_if_loop

gdfc_for_end:
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal get_domain_for_addition # $v0 = valid_domain = get_domain_for_addition()
    j gdfc_end

gdfc_check_else:
    lw $t3, 12($s3) # puzzle->grid[position].cage->positions
    lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
    lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
    xor $t0, $t0, $t1
    xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
    lw $a0, 4($s3) # puzzle->grid[position].cage->target

    sll $t2, $s6, 3 # position * 8
    add $a1, $s5, $t2 # &puzzle->grid[position]
    lw  $a1, 0($a1) # puzzle->grid[position].domain
    # move $a1, $s7 

    sll $t1, $t0, 3 # other_pos*8 (actual offset)
    add $t3, $s5, $t1 # &puzzle->grid[other_pos]
    lw $a2, 0($t3)  # puzzle->grid[other_pos].domian

    jal get_domain_for_subtraction # $v0 = valid_domain = get_domain_for_subtraction()
    # j gdfc_end
gdfc_end:
# restore registers
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36    
    jr $ra


.globl clone
clone:

    lw  $t0, 0($a0)
    sw  $t0, 0($a1)

    mul $t0, $t0, $t0
    mul $t0, $t0, 2 # two words in one grid

    lw  $t1, 4($a0) # &puzzle(ori).grid
    lw  $t2, 4($a1) # &puzzle(clone).grid

    li  $t3, 0 # i = 0;
clone_for_loop:
    bge  $t3, $t0, clone_for_loop_end
    sll $t4, $t3, 2 # i * 4
    add $t5, $t1, $t4 # puzzle(ori).grid ith word
    lw   $t6, 0($t5)

    add $t5, $t2, $t4 # puzzle(clone).grid ith word
    sw   $t6, 0($t5)
    
    addi $t3, $t3, 1 # i++
    
    j    clone_for_loop
clone_for_loop_end:

    jr  $ra

